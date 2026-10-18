// media_metadata_plugin.cc — Linux implementation
// Uses TagLib when available (install: apt install libtag1-dev)
// and gdk-pixbuf (bundled with GTK, already a Flutter Linux dependency) for
// image dimensions/type. Falls back to reading basic file info otherwise.
//
// The optional "createThumbnail" option generates a video-frame thumbnail
// (when no real embedded artwork exists) by shelling out to `ffmpeg`, if it
// is installed on the system (`sudo apt install ffmpeg`). This captures a
// genuine frame from the video, never a generic icon.

#include "include/media_metadata/media_metadata_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <glib/gstdio.h>
#include <sys/stat.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#ifdef HAS_TAGLIB
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/id3v2tag.h>
#include <taglib/mpegfile.h>
#include <taglib/flacfile.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mp4properties.h>
#endif

#define MEDIA_METADATA_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), media_metadata_plugin_get_type(), \
                               MediaMetadataPlugin))

struct _MediaMetadataPlugin {
  GObject parent_instance;
};

struct _MediaMetadataPluginClass {
  GObjectClass parent_class;
};

G_DEFINE_TYPE(MediaMetadataPlugin, media_metadata_plugin, g_object_get_type())

static int64_t get_file_size(const char* path) {
  struct stat st;
  if (stat(path, &st) == 0) return (int64_t)st.st_size;
  return 0;
}

static std::string get_extension(const char* path) {
  std::string p(path);
  size_t dot = p.find_last_of('.');
  if (dot == std::string::npos) return "";
  std::string ext = p.substr(dot + 1);
  std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
  return ext;
}

static bool is_image_extension(const std::string& ext) {
  static const char* kImageExts[] = {"jpg", "jpeg", "png", "heic", "webp",
                                      "tiff", "gif", "bmp"};
  for (const char* e : kImageExts) {
    if (ext == e) return true;
  }
  return false;
}

static bool is_video_extension(const std::string& ext) {
  static const char* kVideoExts[] = {"mp4", "mkv", "3gp", "3gpp", "mov"};
  for (const char* e : kVideoExts) {
    if (ext == e) return true;
  }
  return false;
}

// Lit l'intégralité d'un fichier en mémoire.
static std::vector<uint8_t> read_whole_file(const char* path) {
  std::vector<uint8_t> data;
  FILE* f = fopen(path, "rb");
  if (!f) return data;
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (size > 0) {
    data.resize((size_t)size);
    size_t read = fread(data.data(), 1, (size_t)size, f);
    if (read != (size_t)size) data.clear();
  }
  fclose(f);
  return data;
}

static FlValue* bytes_to_fl_list(const uint8_t* data, size_t length) {
  FlValue* list = fl_value_new_list();
  for (size_t i = 0; i < length; ++i) {
    fl_value_append(list, fl_value_new_int(data[i]));
  }
  return list;
}

// Construit une map ImageMetadata (data, type, fileSizeBytes, width, height,
// description, isGenerated) à partir de données d'image brutes en mémoire,
// en s'appuyant sur GdkPixbufLoader.
static FlValue* build_image_metadata_from_bytes(const uint8_t* data,
                                                 size_t length,
                                                 bool is_generated) {
  FlValue* meta = fl_value_new_map();
  fl_value_set_string(meta, "data", bytes_to_fl_list(data, length));
  fl_value_set_string(meta, "type", fl_value_new_null());
  fl_value_set_string(meta, "fileSizeBytes",
                       fl_value_new_int((int64_t)length));
  fl_value_set_string(meta, "width", fl_value_new_null());
  fl_value_set_string(meta, "height", fl_value_new_null());
  fl_value_set_string(meta, "description", fl_value_new_null());
  fl_value_set_string(meta, "isGenerated", fl_value_new_bool(is_generated));

  GdkPixbufLoader* loader = gdk_pixbuf_loader_new();
  GError* error = nullptr;
  if (gdk_pixbuf_loader_write(loader, data, length, &error)) {
    gdk_pixbuf_loader_close(loader, nullptr);

    GdkPixbufFormat* format = gdk_pixbuf_loader_get_format(loader);
    if (format) {
      gchar* name = gdk_pixbuf_format_get_name(format);
      if (name) {
        fl_value_set_string(meta, "type", fl_value_new_string(name));
        g_free(name);
      }
    }

    GdkPixbuf* pixbuf = gdk_pixbuf_loader_get_pixbuf(loader);
    if (pixbuf) {
      fl_value_set_string(meta, "width",
                           fl_value_new_int(gdk_pixbuf_get_width(pixbuf)));
      fl_value_set_string(meta, "height",
                           fl_value_new_int(gdk_pixbuf_get_height(pixbuf)));
    }
  } else {
    if (error) g_error_free(error);
  }
  g_object_unref(loader);
  return meta;
}

// Variante fichier : type/dimensions déterminés rapidement via gdk-pixbuf
// (lecture d'en-tête uniquement), octets bruts lus séparément depuis le disque.
static FlValue* build_image_metadata_from_file(const char* path,
                                                int64_t file_size) {
  FlValue* meta = fl_value_new_map();
  int width = 0, height = 0;
  GdkPixbufFormat* format = gdk_pixbuf_get_file_info(path, &width, &height);

  if (format) {
    gchar* name = gdk_pixbuf_format_get_name(format);
    fl_value_set_string(meta, "type",
                         name ? fl_value_new_string(name) : fl_value_new_null());
    if (name) g_free(name);
  } else {
    fl_value_set_string(meta, "type", fl_value_new_null());
  }

  fl_value_set_string(meta, "fileSizeBytes", fl_value_new_int(file_size));
  fl_value_set_string(meta, "width",
                       width > 0 ? fl_value_new_int(width) : fl_value_new_null());
  fl_value_set_string(meta, "height",
                       height > 0 ? fl_value_new_int(height) : fl_value_new_null());
  fl_value_set_string(meta, "description", fl_value_new_null());
  fl_value_set_string(meta, "isGenerated", fl_value_new_bool(FALSE));

  std::vector<uint8_t> fileBytes = read_whole_file(path);
  if (!fileBytes.empty()) {
    fl_value_set_string(meta, "data",
                         bytes_to_fl_list(fileBytes.data(), fileBytes.size()));
  } else {
    fl_value_set_string(meta, "data", fl_value_new_null());
  }
  return meta;
}

// Vérifie qu'un binaire est présent sur le PATH (utilisé pour ffmpeg).
static bool binary_exists(const char* name) {
  gchar* path = g_find_program_in_path(name);
  bool found = path != nullptr;
  if (path) g_free(path);
  return found;
}

// Génère une miniature en capturant une vraie image du flux vidéo via
// `ffmpeg`, lorsqu'aucune pochette n'est embarquée. Approche "best effort" :
// si ffmpeg n'est pas installé, retourne simplement nullptr (jamais une
// icône générique de substitution).
static FlValue* build_generated_video_thumbnail(const char* file_path) {
  if (!binary_exists("ffmpeg")) return nullptr;

  gchar* tmp_dir = g_dir_make_tmp("media_metadata_thumb_XXXXXX", nullptr);
  if (!tmp_dir) return nullptr;

  std::string output_path = std::string(tmp_dir) + "/thumb.jpg";
  g_free(tmp_dir);

  // -ss 1 : capture à 1 seconde (ffmpeg ajuste automatiquement si la vidéo
  // est plus courte). -frames:v 1 : une seule image.
  gchar* quoted_input = g_shell_quote(file_path);
  gchar* quoted_output = g_shell_quote(output_path.c_str());
  std::string command = std::string("ffmpeg -y -ss 1 -i ") + quoted_input +
                         " -frames:v 1 -q:v 3 " + quoted_output +
                         " > /dev/null 2>&1";
  g_free(quoted_input);
  g_free(quoted_output);

  int exit_code = std::system(command.c_str());
  (void)exit_code;

  std::vector<uint8_t> thumbBytes = read_whole_file(output_path.c_str());
  std::remove(output_path.c_str());
  g_rmdir(std::string(output_path.substr(0, output_path.find_last_of('/'))).c_str());

  if (thumbBytes.empty()) return nullptr;

  return build_image_metadata_from_bytes(thumbBytes.data(), thumbBytes.size(), true);
}

static void set_all_null_keys(FlValue* result) {
  static const char* kKeys[] = {
      "title", "duration", "artist", "album", "albumArtist", "trackNumber",
      "trackTotal", "discNumber", "discTotal", "year", "genre", "comment",
      "imageMetadata", "sampleRate", "audioBitrate",
      "audioChannels", "bitsPerSample", "audioCodec", "videoCodec",
      "videoBitrate", "frameRate", "videoWidth", "videoHeight",
  };
  for (const char* key : kKeys) {
    fl_value_set_string(result, key, fl_value_new_null());
  }
}

static FlValue* read_image_file_metadata(const char* file_path) {
  FlValue* result = fl_value_new_map();
  set_all_null_keys(result);

  int64_t size = get_file_size(file_path);
  fl_value_set_string(result, "fileSize", fl_value_new_int(size));
  fl_value_set_string(result, "imageMetadata",
                       build_image_metadata_from_file(file_path, size));
  return result;
}

static FlValue* read_media_metadata(const char* file_path, bool create_thumbnail) {
  FlValue* result = fl_value_new_map();
  set_all_null_keys(result);

  int64_t size = get_file_size(file_path);
  fl_value_set_string(result, "fileSize", fl_value_new_int(size));

  bool has_real_artwork = false;

#ifdef HAS_TAGLIB
  TagLib::FileRef f(file_path);
  if (!f.isNull() && f.tag()) {
    TagLib::Tag* tag = f.tag();

    if (!tag->title().isEmpty())
      fl_value_set_string(result, "title",
                          fl_value_new_string(tag->title().toCString(true)));
    if (!tag->artist().isEmpty())
      fl_value_set_string(result, "artist",
                          fl_value_new_string(tag->artist().toCString(true)));
    if (!tag->album().isEmpty())
      fl_value_set_string(result, "album",
                          fl_value_new_string(tag->album().toCString(true)));
    if (!tag->genre().isEmpty())
      fl_value_set_string(result, "genre",
                          fl_value_new_string(tag->genre().toCString(true)));
    if (!tag->comment().isEmpty())
      fl_value_set_string(result, "comment",
                          fl_value_new_string(tag->comment().toCString(true)));
    if (tag->year() > 0)
      fl_value_set_string(result, "year", fl_value_new_int(tag->year()));
    if (tag->track() > 0)
      fl_value_set_string(result, "trackNumber",
                          fl_value_new_int(tag->track()));
  }

  if (!f.isNull() && f.audioProperties()) {
    TagLib::AudioProperties* props = f.audioProperties();

    int ms = props->lengthInMilliseconds();
    if (ms > 0) fl_value_set_string(result, "duration", fl_value_new_int(ms));

    if (props->bitrate() > 0) {
      fl_value_set_string(result, "audioBitrate",
                           fl_value_new_int((int64_t)props->bitrate() * 1000));
    }
    if (props->sampleRate() > 0) {
      fl_value_set_string(result, "sampleRate",
                           fl_value_new_int(props->sampleRate()));
    }
    if (props->channels() > 0) {
      fl_value_set_string(result, "audioChannels",
                           fl_value_new_int(props->channels()));
    }

    if (auto* flacProps = dynamic_cast<TagLib::FLAC::Properties*>(props)) {
      if (flacProps->bitsPerSample() > 0) {
        fl_value_set_string(result, "bitsPerSample",
                             fl_value_new_int(flacProps->bitsPerSample()));
      }
      fl_value_set_string(result, "audioCodec", fl_value_new_string("FLAC"));
    } else if (auto* mp4Props =
                   dynamic_cast<TagLib::MP4::Properties*>(props)) {
      if (mp4Props->bitsPerSample() > 0) {
        fl_value_set_string(result, "bitsPerSample",
                             fl_value_new_int(mp4Props->bitsPerSample()));
      }
      switch (mp4Props->codec()) {
        case TagLib::MP4::Properties::AAC:
          fl_value_set_string(result, "audioCodec", fl_value_new_string("AAC"));
          break;
        case TagLib::MP4::Properties::ALAC:
          fl_value_set_string(result, "audioCodec", fl_value_new_string("ALAC"));
          break;
        default:
          break;
      }
    } else if (dynamic_cast<TagLib::MPEG::File*>(f.file())) {
      fl_value_set_string(result, "audioCodec", fl_value_new_string("MP3"));
    }
  }

  // Pochette d'album (ID3v2 APIC pour les MP3)
  TagLib::MPEG::File* mpeg = dynamic_cast<TagLib::MPEG::File*>(f.file());
  if (mpeg && mpeg->ID3v2Tag()) {
    auto frames = mpeg->ID3v2Tag()->frameListMap()["APIC"];
    if (!frames.isEmpty()) {
      auto* frame =
          dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(frames.front());
      if (frame) {
        auto pic = frame->picture();
        std::vector<uint8_t> raw(pic.size());
        for (size_t i = 0; i < pic.size(); ++i) {
          raw[i] = (uint8_t)pic[i];
        }
        fl_value_set_string(
            result, "imageMetadata",
            build_image_metadata_from_bytes(raw.data(), raw.size(), false));
        has_real_artwork = true;
      }
    }
  }
#endif

  // Si aucune pochette réelle n'a été trouvée et que le fichier est une vidéo
  if (!has_real_artwork && create_thumbnail &&
      is_video_extension(get_extension(file_path))) {
    FlValue* generated = build_generated_video_thumbnail(file_path);
    if (generated) {
      fl_value_set_string(result, "imageMetadata", generated);
    }
  }

  return result;
}

static FlValue* read_metadata(const char* file_path, bool create_thumbnail) {
  std::string ext = get_extension(file_path);
  if (is_image_extension(ext)) {
    return read_image_file_metadata(file_path);
  }
  return read_media_metadata(file_path, create_thumbnail);
}

static bool write_metadata(const char* file_path, FlValue* metadata_map) {
#ifdef HAS_TAGLIB
  TagLib::FileRef f(file_path);
  if (f.isNull() || !f.tag()) {
    return false;
  }
  TagLib::Tag* tag = f.tag();

  auto maybeString = [&](const char* key) -> const char* {
    FlValue* value = fl_value_lookup_string(metadata_map, key);
    if (!value || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
      return nullptr;
    }
    return fl_value_get_string(value);
  };

  auto maybeInt = [&](const char* key) -> int {
    FlValue* value = fl_value_lookup_string(metadata_map, key);
    if (!value) return 0;
    if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      return (int)fl_value_get_int(value);
    }
    return 0;
  };

  if (const char* title = maybeString("title")) {
    tag->setTitle(title);
  }
  if (const char* artist = maybeString("artist")) {
    tag->setArtist(artist);
  }
  if (const char* album = maybeString("album")) {
    tag->setAlbum(album);
  }
  if (const char* genre = maybeString("genre")) {
    tag->setGenre(genre);
  }
  if (const char* comment = maybeString("comment")) {
    tag->setComment(comment);
  }
  int year = maybeInt("year");
  if (year > 0) {
    tag->setYear(year);
  }
  int track = maybeInt("trackNumber");
  if (track > 0) {
    tag->setTrack(track);
  }

  // Note : l'écriture de la pochette (metadata["imageMetadata"]["data"])
  // n'est pas implémentée ici ; ce serait le point d'entrée si on souhaitait
  // ajouter l'écriture d'ID3v2 APIC via TagLib::ID3v2::AttachedPictureFrame.
  // Une miniature générée (isGenerated == true) ne devrait de toute façon
  // jamais être réinjectée comme si c'était une vraie pochette.

  return f.save();
#else
  return false;
#endif
}

static void media_metadata_plugin_handle_method_call(
    MediaMetadataPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "readMetadata") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_val = fl_value_lookup_string(args, "filePath");
    if (!path_val || fl_value_get_type(path_val) != FL_VALUE_TYPE_STRING) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENT", "filePath is required", nullptr));
    } else {
      const char* file_path = fl_value_get_string(path_val);

      bool create_thumbnail = false;
      FlValue* thumb_val = fl_value_lookup_string(args, "createThumbnail");
      if (thumb_val && fl_value_get_type(thumb_val) == FL_VALUE_TYPE_BOOL) {
        create_thumbnail = fl_value_get_bool(thumb_val);
      }

      FlValue* metadata = read_metadata(file_path, create_thumbnail);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(metadata));
    }
  } else if (strcmp(method, "writeMetadata") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_val = fl_value_lookup_string(args, "filePath");
    FlValue* metadata_val = fl_value_lookup_string(args, "metadata");
    if (!path_val || fl_value_get_type(path_val) != FL_VALUE_TYPE_STRING ||
        !metadata_val || fl_value_get_type(metadata_val) != FL_VALUE_TYPE_MAP) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENT", "filePath and metadata are required", nullptr));
    } else {
      const char* file_path = fl_value_get_string(path_val);
      bool success = write_metadata(file_path, metadata_val);
      response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(fl_value_new_bool(success)));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void media_metadata_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(media_metadata_plugin_parent_class)->dispose(object);
}

static void media_metadata_plugin_class_init(
    MediaMetadataPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = media_metadata_plugin_dispose;
}

static void media_metadata_plugin_init(MediaMetadataPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                            gpointer user_data) {
  MediaMetadataPlugin* plugin = MEDIA_METADATA_PLUGIN(user_data);
  media_metadata_plugin_handle_method_call(plugin, method_call);
}

void media_metadata_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  MediaMetadataPlugin* plugin = MEDIA_METADATA_PLUGIN(
      g_object_new(media_metadata_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "media_metadata",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
