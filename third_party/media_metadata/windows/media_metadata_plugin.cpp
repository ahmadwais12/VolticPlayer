// media_metadata_plugin.cpp
// Windows implementation using Shell Property Store for text tags (title,
// artist, album, ...) and technical audio/video properties, plus a direct,
// system-independent parser for embedded artwork.
//
// Embedded artwork (album cover / thumbnail) is read by directly parsing the
// real tag structures ourselves:
//   - ID3v2 "APIC" frame for .mp3 / ID3-tagged .aac
//   - MP4 "covr" atom (moov/udta/meta/ilst/covr/data) for .mp4/.m4a/.mov/.3gp
// PKEY_ThumbnailStream is tried as a secondary fallback for formats not
// covered by the direct parsers above.
//
// If NEITHER of those yields a real picture, and the caller opted in via the
// "createThumbnail" argument, and the file is a video, we generate a
// thumbnail by capturing an actual video frame through
// IShellItemImageFactory::GetImage() (the same mechanism Explorer uses to
// show video thumbnails). This is only used for this explicit, opt-in,
// video-frame-capture purpose — never as a silent fallback for audio files,
// where it would return a generic file-type/media-player icon instead of
// real content. Generated thumbnails are always flagged with
// imageMetadata.isGenerated = true so callers can tell them apart from a
// genuine embedded cover.

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601 // Windows 7 ou supérieur
#endif

#include "include/media_metadata/media_metadata_plugin.h"

// clang-format off
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <propsys.h>
#include <propkey.h>
#include <propvarutil.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wincodec.h>
// clang-format on

#pragma comment(lib, "propsys.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "windowscodecs.lib")

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <codecvt>
#include <fstream>
#include <locale>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

namespace media_metadata {

namespace {

// Helper: wide string to UTF-8
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(),
                                 nullptr, 0, nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(),
                      result.data(), size, nullptr, nullptr);
  return result;
}

// Helper: UTF-8 to wide string
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), (int)utf8.size(),
                                 nullptr, 0);
  std::wstring result(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), (int)utf8.size(),
                      result.data(), size);
  return result;
}

// Helper: get string property from IPropertyStore
std::optional<std::string> GetStringProp(IPropertyStore* store,
                                         const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    if (pv.vt == VT_LPWSTR && pv.pwszVal) {
      auto result = WideToUtf8(pv.pwszVal);
      PropVariantClear(&pv);
      if (!result.empty()) return result;
    }
    else if ((pv.vt == (VT_VECTOR | VT_LPWSTR)) && pv.calpwstr.cElems > 0) {
      auto result = WideToUtf8(pv.calpwstr.pElems[0]);
      PropVariantClear(&pv);
      if (!result.empty()) return result;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

// Helper: get uint32 property
std::optional<int32_t> GetUInt32Prop(IPropertyStore* store,
                                     const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    UINT32 val = 0;
    if (SUCCEEDED(PropVariantToUInt32(pv, &val))) {
      PropVariantClear(&pv);
      return (int32_t)val;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

// Helper: get uint64 property
std::optional<int64_t> GetUInt64Prop(IPropertyStore* store,
                                     const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    UINT64 val = 0;
    if (SUCCEEDED(PropVariantToUInt64(pv, &val))) {
      PropVariantClear(&pv);
      return (int64_t)val;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

bool SetStringProp(IPropertyStore* store, const PROPERTYKEY& key,
                   const std::optional<std::string>& value) {
  if (!value.has_value()) return true;
  PROPVARIANT pv;
  PropVariantInit(&pv);
  const std::wstring wide = Utf8ToWide(*value);
  HRESULT hr = InitPropVariantFromString(wide.c_str(), &pv);
  if (SUCCEEDED(hr)) {
    store->SetValue(key, pv);
  }
  PropVariantClear(&pv);
  return true;
}

// Windows requiert un VT_VECTOR | VT_LPWSTR pour les Genres (Music et Video)
bool SetGenreProp(IPropertyStore* store, const PROPERTYKEY& key,
                  const std::optional<std::string>& value) {
  if (!value.has_value()) return true;
  PROPVARIANT pv;
  PropVariantInit(&pv);
  const std::wstring wide = Utf8ToWide(*value);
  PCWSTR stringArray[] = { wide.c_str() };
  HRESULT hr = InitPropVariantFromStringVector(stringArray, 1, &pv);
  if (SUCCEEDED(hr)) {
    store->SetValue(key, pv);
  }
  PropVariantClear(&pv);
  return SUCCEEDED(hr);
}

bool SetUInt32Prop(IPropertyStore* store, const PROPERTYKEY& key,
                   const std::optional<int32_t>& value) {
  if (!value.has_value()) return true;
  PROPVARIANT pv;
  PropVariantInit(&pv);
  HRESULT hr = InitPropVariantFromUInt32((UINT32)*value, &pv);
  if (SUCCEEDED(hr)) {
    store->SetValue(key, pv);
  }
  PropVariantClear(&pv);
  return true;
}

// Assure une encapsulation propre du IStream dans le VT_UNKNOWN du PROPVARIANT
bool SetImageProp(IPropertyStore* store, const PROPERTYKEY& key,
                  const std::optional<std::vector<uint8_t>>& bytes) {
  if (!bytes.has_value() || bytes->empty()) return true;

  IStream* pStream = nullptr;
  HRESULT hr = CreateStreamOnHGlobal(nullptr, TRUE, &pStream);
  if (FAILED(hr)) return false;

  ULONG bytesWritten = 0;
  hr = pStream->Write(bytes->data(), static_cast<ULONG>(bytes->size()), &bytesWritten);
  if (FAILED(hr)) {
    pStream->Release();
    return false;
  }

  LARGE_INTEGER liZero = {0};
  pStream->Seek(liZero, STREAM_SEEK_SET, nullptr);

  PROPVARIANT pv;
  PropVariantInit(&pv);
  
  pv.vt = VT_UNKNOWN;
  hr = pStream->QueryInterface(IID_PPV_ARGS(&pv.punkVal));
  
  if (SUCCEEDED(hr)) {
    hr = store->SetValue(key, pv);
  }

  PropVariantClear(&pv);
  pStream->Release();
  return SUCCEEDED(hr);
}

// Convertit un GUID de format de conteneur WIC (GUID_ContainerFormatXxx) en
// une chaîne de type d'image lisible, cohérente avec les autres plateformes.
std::string ContainerFormatToString(const GUID& guid) {
  if (IsEqualGUID(guid, GUID_ContainerFormatPng)) return "png";
  if (IsEqualGUID(guid, GUID_ContainerFormatJpeg)) return "jpeg";
  if (IsEqualGUID(guid, GUID_ContainerFormatBmp)) return "bmp";
  if (IsEqualGUID(guid, GUID_ContainerFormatGif)) return "gif";
  if (IsEqualGUID(guid, GUID_ContainerFormatTiff)) return "tiff";
  if (IsEqualGUID(guid, GUID_ContainerFormatIco)) return "ico";
  if (IsEqualGUID(guid, GUID_ContainerFormatWmp)) return "wmp";
  return "unknown";
}

flutter::EncodableValue BytesToEncodableList(const uint8_t* data, size_t length) {
  std::vector<flutter::EncodableValue> bytes;
  bytes.reserve(length);
  for (size_t i = 0; i < length; ++i) {
    bytes.push_back(flutter::EncodableValue(static_cast<int32_t>(data[i])));
  }
  return flutter::EncodableValue(bytes);
}

// Lit l'intégralité d'un fichier en mémoire (pour ImageMetadata.data des
// fichiers image autonomes).
std::vector<uint8_t> ReadWholeFile(const std::wstring& path) {
  std::vector<uint8_t> data;
  std::ifstream file(path, std::ios::binary | std::ios::ate);
  if (!file) return data;
  std::streamsize size = file.tellg();
  if (size <= 0) return data;
  data.resize((size_t)size);
  file.seekg(0, std::ios::beg);
  if (!file.read(reinterpret_cast<char*>(data.data()), size)) {
    data.clear();
  }
  return data;
}

std::wstring GetExtensionLower(const std::wstring& path) {
  std::wstring ext;
  size_t dot_idx = path.find_last_of(L".");
  if (dot_idx != std::wstring::npos) {
    ext = path.substr(dot_idx + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
  }
  return ext;
}

bool IsVideoExtension(const std::wstring& ext) {
  static const std::vector<std::wstring> kVideoExts = {
      L"mp4", L"mkv", L"3gp", L"3gpp", L"mov"};
  return std::find(kVideoExts.begin(), kVideoExts.end(), ext) != kVideoExts.end();
}

// ---------------------------------------------------------------------
// Extraction directe et fiable de la vraie pochette embarquée, sans passer
// par un quelconque gestionnaire de miniatures du système.
// ---------------------------------------------------------------------

struct ExtractedPicture {
  std::vector<uint8_t> data;
  std::string mimeType;  // ex: "image/jpeg", "image/png"
};

// Accès en lecture seule et par accès aléatoire à un fichier, sans jamais le
// charger intégralement en mémoire (important pour les gros fichiers vidéo).
class BinaryFileReader {
 public:
  explicit BinaryFileReader(const std::wstring& path)
      : file_(path, std::ios::binary) {}

  bool IsOpen() { return file_.is_open(); }

  bool ReadAt(uint64_t offset, void* buffer, size_t size) {
    file_.seekg((std::streamoff)offset, std::ios::beg);
    if (!file_) return false;
    file_.read(reinterpret_cast<char*>(buffer), (std::streamsize)size);
    return (bool)file_;
  }

  uint64_t Size() {
    file_.seekg(0, std::ios::end);
    auto s = file_.tellg();
    file_.clear();
    return s < 0 ? 0 : (uint64_t)s;
  }

 private:
  std::ifstream file_;
};

uint32_t Synchsafe(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3) {
  return ((uint32_t)(b0 & 0x7F) << 21) | ((uint32_t)(b1 & 0x7F) << 14) |
         ((uint32_t)(b2 & 0x7F) << 7) | (uint32_t)(b3 & 0x7F);
}

// Parse l'en-tête ID3v2 et cherche la frame "APIC" (pochette embarquée),
// utilisée par les fichiers .mp3 et, occasionnellement, .aac.
std::optional<ExtractedPicture> ExtractId3v2Apic(const std::wstring& path) {
  BinaryFileReader reader(path);
  if (!reader.IsOpen()) return std::nullopt;

  uint8_t header[10];
  if (!reader.ReadAt(0, header, 10)) return std::nullopt;
  if (header[0] != 'I' || header[1] != 'D' || header[2] != '3') {
    return std::nullopt;
  }

  uint8_t majorVersion = header[3];
  uint32_t tagSize = Synchsafe(header[6], header[7], header[8], header[9]);
  if (tagSize == 0 || tagSize > 200 * 1024 * 1024) return std::nullopt;

  std::vector<uint8_t> tagData(tagSize);
  if (!reader.ReadAt(10, tagData.data(), tagSize)) return std::nullopt;

  size_t offset = 0;
  while (offset + 10 <= tagData.size()) {
    std::string frameId(reinterpret_cast<char*>(&tagData[offset]), 4);
    if (frameId == std::string(4, '\0')) break;

    uint32_t frameSize;
    if (majorVersion >= 4) {
      frameSize = Synchsafe(tagData[offset + 4], tagData[offset + 5],
                            tagData[offset + 6], tagData[offset + 7]);
    } else {
      frameSize = ((uint32_t)tagData[offset + 4] << 24) |
                  ((uint32_t)tagData[offset + 5] << 16) |
                  ((uint32_t)tagData[offset + 6] << 8) |
                  (uint32_t)tagData[offset + 7];
    }

    size_t frameStart = offset + 10;
    if (frameSize == 0 || frameStart + frameSize > tagData.size()) break;

    if (frameId == "APIC") {
      size_t p = frameStart;
      size_t frameEnd = frameStart + frameSize;
      if (p >= frameEnd) break;

      uint8_t textEncoding = tagData[p];
      p += 1;

      std::string mime;
      while (p < frameEnd && tagData[p] != 0) {
        mime += (char)tagData[p];
        p++;
      }
      p += 1;  // null terminator du MIME
      if (p >= frameEnd) break;

      p += 1;  // octet "picture type"
      if (p >= frameEnd) break;

      // Description : chaîne terminée par un ou deux octets nuls selon
      // l'encodage déclaré.
      if (textEncoding == 1 || textEncoding == 2) {
        while (p + 1 < frameEnd &&
               !(tagData[p] == 0 && tagData[p + 1] == 0)) {
          p += 2;
        }
        p += 2;
      } else {
        while (p < frameEnd && tagData[p] != 0) p++;
        p += 1;
      }
      if (p >= frameEnd) break;

      ExtractedPicture pic;
      pic.mimeType = mime.empty() ? "image/jpeg" : mime;
      pic.data.assign(tagData.begin() + p, tagData.begin() + frameEnd);
      return pic;
    }

    offset = frameStart + frameSize;
  }
  return std::nullopt;
}

// Parcourt récursivement les atomes MP4 (moov/udta/meta/ilst/covr/data) à la
// recherche d'une pochette embarquée, utilisée par .mp4/.m4a/.mov/.3gp(p).
// Ne lit que les en-têtes de boîtes et le contenu réel de "covr", jamais le
// reste du fichier (mdat, pistes vidéo/audio...).
std::optional<ExtractedPicture> FindMp4CoverRecursive(BinaryFileReader& reader,
                                                       uint64_t start,
                                                       uint64_t end,
                                                       int depth) {
  if (depth > 8) return std::nullopt;

  uint64_t pos = start;
  while (pos + 8 <= end) {
    uint8_t header[8];
    if (!reader.ReadAt(pos, header, 8)) break;

    uint32_t boxSize = ((uint32_t)header[0] << 24) | ((uint32_t)header[1] << 16) |
                        ((uint32_t)header[2] << 8) | (uint32_t)header[3];
    std::string boxType(reinterpret_cast<char*>(&header[4]), 4);

    uint64_t headerSize = 8;
    uint64_t actualSize = boxSize;
    if (boxSize == 1) {
      uint8_t ext[8];
      if (!reader.ReadAt(pos + 8, ext, 8)) break;
      actualSize = 0;
      for (int i = 0; i < 8; i++) actualSize = (actualSize << 8) | ext[i];
      headerSize = 16;
    } else if (boxSize == 0) {
      actualSize = end - pos;
    }
    if (actualSize < headerSize || pos + actualSize > end) break;

    uint64_t childStart = pos + headerSize;
    uint64_t childEnd = pos + actualSize;

    if (boxType == "moov" || boxType == "udta" || boxType == "ilst") {
      auto found = FindMp4CoverRecursive(reader, childStart, childEnd, depth + 1);
      if (found.has_value()) return found;
    } else if (boxType == "meta") {
      // La boîte 'meta' porte 4 octets de version/flags avant ses enfants.
      auto found = FindMp4CoverRecursive(reader, childStart + 4, childEnd, depth + 1);
      if (found.has_value()) return found;
    } else if (boxType == "covr") {
      uint64_t dpos = childStart;
      while (dpos + 8 <= childEnd) {
        uint8_t dHeader[8];
        if (!reader.ReadAt(dpos, dHeader, 8)) break;
        uint32_t dSize = ((uint32_t)dHeader[0] << 24) | ((uint32_t)dHeader[1] << 16) |
                          ((uint32_t)dHeader[2] << 8) | (uint32_t)dHeader[3];
        std::string dType(reinterpret_cast<char*>(&dHeader[4]), 4);

        if (dType == "data" && dSize > 16 && dpos + dSize <= childEnd) {
          uint8_t typeBuf[4];
          reader.ReadAt(dpos + 8, typeBuf, 4);
          uint32_t typeIndicator = ((uint32_t)typeBuf[0] << 24) |
                                    ((uint32_t)typeBuf[1] << 16) |
                                    ((uint32_t)typeBuf[2] << 8) |
                                    (uint32_t)typeBuf[3];

          uint64_t payloadStart = dpos + 16;
          uint64_t payloadSize = (dpos + dSize) - payloadStart;
          if (payloadSize > 0 && payloadSize < 100ULL * 1024 * 1024) {
            ExtractedPicture pic;
            pic.data.resize((size_t)payloadSize);
            if (reader.ReadAt(payloadStart, pic.data.data(), (size_t)payloadSize)) {
              // Convention iTunes : 13 = JPEG, 14 = PNG.
              pic.mimeType = (typeIndicator == 14) ? "image/png" : "image/jpeg";
              return pic;
            }
          }
        }
        if (dSize == 0) break;
        dpos += dSize;
      }
    }

    pos += actualSize;
  }
  return std::nullopt;
}

std::optional<ExtractedPicture> ExtractMp4Cover(const std::wstring& path) {
  BinaryFileReader reader(path);
  if (!reader.IsOpen()) return std::nullopt;
  uint64_t size = reader.Size();
  return FindMp4CoverRecursive(reader, 0, size, 0);
}

// Construit une map ImageMetadata (data, type, fileSizeBytes, width, height,
// description, isGenerated) à partir d'octets d'image déjà extraits en
// mémoire (pochette réelle, ou miniature générée depuis une image WIC/HBITMAP).
flutter::EncodableMap BuildImageMetadataFromBytes(const std::vector<uint8_t>& bytes,
                                                   bool isGenerated) {
  flutter::EncodableMap meta;
  meta[flutter::EncodableValue("data")] =
      bytes.empty() ? flutter::EncodableValue()
                    : BytesToEncodableList(bytes.data(), bytes.size());
  meta[flutter::EncodableValue("type")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("fileSizeBytes")] = flutter::EncodableValue((int64_t)bytes.size());
  meta[flutter::EncodableValue("width")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("height")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("description")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("isGenerated")] = flutter::EncodableValue(isGenerated);
  if (bytes.empty()) return meta;

  IStream* pStream = SHCreateMemStream(bytes.data(), (UINT)bytes.size());
  if (!pStream) return meta;

  IWICImagingFactory* pFactory = nullptr;
  if (SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                  CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pFactory)))) {
    IWICBitmapDecoder* pDecoder = nullptr;
    if (SUCCEEDED(pFactory->CreateDecoderFromStream(
            pStream, nullptr, WICDecodeMetadataCacheOnDemand, &pDecoder))) {
      GUID containerFormat;
      if (SUCCEEDED(pDecoder->GetContainerFormat(&containerFormat))) {
        meta[flutter::EncodableValue("type")] =
            flutter::EncodableValue(ContainerFormatToString(containerFormat));
      }
      IWICBitmapFrameDecode* pFrame = nullptr;
      if (SUCCEEDED(pDecoder->GetFrame(0, &pFrame))) {
        UINT w = 0, h = 0;
        if (SUCCEEDED(pFrame->GetSize(&w, &h))) {
          meta[flutter::EncodableValue("width")] = flutter::EncodableValue((int32_t)w);
          meta[flutter::EncodableValue("height")] = flutter::EncodableValue((int32_t)h);
        }
        pFrame->Release();
      }
      pDecoder->Release();
    }
    pFactory->Release();
  }
  pStream->Release();
  return meta;
}

// Repli : construit ImageMetadata depuis un IStream du Property System
// (PKEY_ThumbnailStream). Toujours une vraie image embarquée si présente.
flutter::EncodableMap BuildImageMetadataFromStream(IStream* pStream,
                                                    const uint8_t* rawBytes,
                                                    int64_t sizeBytes) {
  flutter::EncodableMap meta;
  meta[flutter::EncodableValue("data")] =
      rawBytes ? BytesToEncodableList(rawBytes, (size_t)sizeBytes) : flutter::EncodableValue();
  meta[flutter::EncodableValue("type")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("fileSizeBytes")] = flutter::EncodableValue(sizeBytes);
  meta[flutter::EncodableValue("width")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("height")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("description")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("isGenerated")] = flutter::EncodableValue(false);

  IWICImagingFactory* pFactory = nullptr;
  if (SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                  CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pFactory)))) {
    IWICBitmapDecoder* pDecoder = nullptr;
    if (SUCCEEDED(pFactory->CreateDecoderFromStream(
            pStream, nullptr, WICDecodeMetadataCacheOnDemand, &pDecoder))) {
      GUID containerFormat;
      if (SUCCEEDED(pDecoder->GetContainerFormat(&containerFormat))) {
        meta[flutter::EncodableValue("type")] =
            flutter::EncodableValue(ContainerFormatToString(containerFormat));
      }
      IWICBitmapFrameDecode* pFrame = nullptr;
      if (SUCCEEDED(pDecoder->GetFrame(0, &pFrame))) {
        UINT w = 0, h = 0;
        if (SUCCEEDED(pFrame->GetSize(&w, &h))) {
          meta[flutter::EncodableValue("width")] = flutter::EncodableValue((int32_t)w);
          meta[flutter::EncodableValue("height")] = flutter::EncodableValue((int32_t)h);
        }
        pFrame->Release();
      }
      pDecoder->Release();
    }
    pFactory->Release();
  }
  return meta;
}

// Variante fichier : utilisée pour les fichiers image "purs" (jpg, png, ...).
flutter::EncodableMap BuildImageMetadataFromFile(const std::wstring& file_path,
                                                  int64_t file_size) {
  flutter::EncodableMap meta;
  meta[flutter::EncodableValue("type")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("fileSizeBytes")] = flutter::EncodableValue(file_size);
  meta[flutter::EncodableValue("width")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("height")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("description")] = flutter::EncodableValue();
  meta[flutter::EncodableValue("isGenerated")] = flutter::EncodableValue(false);

  IWICImagingFactory* pFactory = nullptr;
  if (SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                  CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pFactory)))) {
    IWICBitmapDecoder* pDecoder = nullptr;
    if (SUCCEEDED(pFactory->CreateDecoderFromFilename(
            file_path.c_str(), nullptr, GENERIC_READ,
            WICDecodeMetadataCacheOnDemand, &pDecoder))) {
      GUID containerFormat;
      if (SUCCEEDED(pDecoder->GetContainerFormat(&containerFormat))) {
        meta[flutter::EncodableValue("type")] =
            flutter::EncodableValue(ContainerFormatToString(containerFormat));
      }
      IWICBitmapFrameDecode* pFrame = nullptr;
      if (SUCCEEDED(pDecoder->GetFrame(0, &pFrame))) {
        UINT w = 0, h = 0;
        if (SUCCEEDED(pFrame->GetSize(&w, &h))) {
          meta[flutter::EncodableValue("width")] = flutter::EncodableValue((int32_t)w);
          meta[flutter::EncodableValue("height")] = flutter::EncodableValue((int32_t)h);
        }
        pFrame->Release();
      }
      pDecoder->Release();
    }
    pFactory->Release();
  }

  std::vector<uint8_t> raw = ReadWholeFile(file_path);
  meta[flutter::EncodableValue("data")] =
      raw.empty() ? flutter::EncodableValue()
                  : BytesToEncodableList(raw.data(), raw.size());

  return meta;
}

// Génère une miniature en capturant une vraie image du flux vidéo via
// IShellItemImageFactory (le même mécanisme que l'Explorateur Windows pour
// afficher les vignettes vidéo). N'est appelée que lorsque createThumbnail
// vaut true ET qu'aucune pochette réelle n'a été trouvée — jamais comme
// repli silencieux, et jamais pour l'audio (où cette API renverrait une
// icône générique faute de contenu visuel).
std::optional<flutter::EncodableMap> GenerateVideoThumbnail(const std::wstring& file_path) {
  IShellItem* pItem = nullptr;
  if (FAILED(SHCreateItemFromParsingName(file_path.c_str(), nullptr, IID_PPV_ARGS(&pItem)))) {
    return std::nullopt;
  }

  std::optional<flutter::EncodableMap> result = std::nullopt;

  IShellItemImageFactory* pFactory = nullptr;
  if (SUCCEEDED(pItem->QueryInterface(IID_PPV_ARGS(&pFactory)))) {
    HBITMAP hbm = nullptr;
    SIZE sz = {512, 512};
    // SIIGBF_BIGGERSIZEOK | SIIGBF_THUMBNAILONLY : on veut une vraie image du
    // contenu (frame vidéo), pas une icône générique de secours.
    SIIGBF flags = static_cast<SIIGBF>(SIIGBF_BIGGERSIZEOK | SIIGBF_THUMBNAILONLY);

    if (SUCCEEDED(pFactory->GetImage(sz, flags, &hbm)) && hbm) {
      IWICImagingFactory* pWicFactory = nullptr;
      if (SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pWicFactory)))) {
        IWICBitmap* pWicBitmap = nullptr;
        if (SUCCEEDED(pWicFactory->CreateBitmapFromHBITMAP(hbm, nullptr, WICBitmapUseAlpha, &pWicBitmap))) {
          UINT wicWidth = 0, wicHeight = 0;
          pWicBitmap->GetSize(&wicWidth, &wicHeight);

          IStream* pStream = nullptr;
          if (SUCCEEDED(CreateStreamOnHGlobal(nullptr, TRUE, &pStream))) {
            IWICBitmapEncoder* pEncoder = nullptr;
            if (SUCCEEDED(pWicFactory->CreateEncoder(GUID_ContainerFormatJpeg, nullptr, &pEncoder))) {
              if (SUCCEEDED(pEncoder->Initialize(pStream, WICBitmapEncoderNoCache))) {
                IWICBitmapFrameEncode* pFrame = nullptr;
                IPropertyBag2* pBag = nullptr;
                if (SUCCEEDED(pEncoder->CreateNewFrame(&pFrame, &pBag))) {
                  if (SUCCEEDED(pFrame->Initialize(pBag))) {
                    pFrame->WriteSource(pWicBitmap, nullptr);
                    pFrame->Commit();
                    pEncoder->Commit();

                    HGLOBAL hg = nullptr;
                    GetHGlobalFromStream(pStream, &hg);
                    if (hg) {
                      SIZE_T size_bytes = GlobalSize(hg);
                      void* ptr = GlobalLock(hg);
                      if (ptr && size_bytes > 0) {
                        std::vector<uint8_t> bytes((uint8_t*)ptr, (uint8_t*)ptr + size_bytes);
                        flutter::EncodableMap meta;
                        meta[flutter::EncodableValue("data")] = BytesToEncodableList(bytes.data(), bytes.size());
                        meta[flutter::EncodableValue("type")] = flutter::EncodableValue(std::string("jpeg"));
                        meta[flutter::EncodableValue("fileSizeBytes")] = flutter::EncodableValue((int64_t)size_bytes);
                        meta[flutter::EncodableValue("width")] = flutter::EncodableValue((int32_t)wicWidth);
                        meta[flutter::EncodableValue("height")] = flutter::EncodableValue((int32_t)wicHeight);
                        meta[flutter::EncodableValue("description")] = flutter::EncodableValue();
                        meta[flutter::EncodableValue("isGenerated")] = flutter::EncodableValue(true);
                        result = meta;
                      }
                      GlobalUnlock(hg);
                    }
                  }
                  if (pBag) pBag->Release();
                  pFrame->Release();
                }
              }
              pEncoder->Release();
            }
            pStream->Release();
          }
          pWicBitmap->Release();
        }
        pWicFactory->Release();
      }
      DeleteObject(hbm);
    }
    pFactory->Release();
  }
  pItem->Release();

  return result;
}

flutter::EncodableMap ReadImageFileMetadata(const std::wstring& file_path) {
  flutter::EncodableMap result;
  result[flutter::EncodableValue("title")] = flutter::EncodableValue();
  result[flutter::EncodableValue("duration")] = flutter::EncodableValue();
  result[flutter::EncodableValue("artist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("album")] = flutter::EncodableValue();
  result[flutter::EncodableValue("albumArtist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("year")] = flutter::EncodableValue();
  result[flutter::EncodableValue("genre")] = flutter::EncodableValue();
  result[flutter::EncodableValue("comment")] = flutter::EncodableValue();
  result[flutter::EncodableValue("sampleRate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioBitrate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioChannels")] = flutter::EncodableValue();
  result[flutter::EncodableValue("bitsPerSample")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioCodec")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoCodec")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoBitrate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("frameRate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoWidth")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoHeight")] = flutter::EncodableValue();

  WIN32_FILE_ATTRIBUTE_DATA fad;
  int64_t size = 0;
  if (GetFileAttributesExW(file_path.c_str(), GetFileExInfoStandard, &fad)) {
    size = ((int64_t)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
  }
  result[flutter::EncodableValue("fileSize")] = flutter::EncodableValue(size);
  result[flutter::EncodableValue("imageMetadata")] =
      flutter::EncodableValue(BuildImageMetadataFromFile(file_path, size));

  return result;
}

bool WriteMediaMetadata(const std::wstring& file_path,
  const flutter::EncodableMap& metadata) {
std::wstring ext = GetExtensionLower(file_path);

bool isAudio = (ext == L"mp3" || ext == L"m4a" || ext == L"flac" || ext == L"wav" || ext == L"wma" || ext == L"aac");

GETPROPERTYSTOREFLAGS flags = isAudio ? GPS_READWRITE : static_cast<GETPROPERTYSTOREFLAGS>(GPS_READWRITE | GPS_FASTPROPERTIESONLY);

IPropertyStore* pStore = nullptr;
HRESULT hr = SHGetPropertyStoreFromParsingName(file_path.c_str(), nullptr, flags, IID_PPV_ARGS(&pStore));
if (FAILED(hr) || !pStore) return false;

auto getString = [&](const flutter::EncodableValue& key) -> std::optional<std::string> {
auto it = metadata.find(key);
if (it == metadata.end()) return std::nullopt;
if (auto str = std::get_if<std::string>(&it->second)) return *str;
return std::nullopt;
};

auto getInt = [&](const flutter::EncodableValue& key) -> std::optional<int32_t> {
auto it = metadata.find(key);
if (it == metadata.end()) return std::nullopt;
if (auto val = std::get_if<int32_t>(&it->second)) return *val;
if (auto val64 = std::get_if<int64_t>(&it->second)) return static_cast<int32_t>(*val64);
return std::nullopt;
};

// Extraction robuste et compatible avec EncodableValue pour le Uint8List de
// Flutter, niché sous metadata["imageMetadata"]["data"]. On n'écrit jamais
// une miniature générée (isGenerated == true) comme si c'était une vraie
// pochette.
auto getImageBytes = [&]() -> std::optional<std::vector<uint8_t>> {
auto it = metadata.find(flutter::EncodableValue("imageMetadata"));
if (it == metadata.end()) return std::nullopt;
auto* imageMetaMap = std::get_if<flutter::EncodableMap>(&it->second);
if (!imageMetaMap) return std::nullopt;

auto genIt = imageMetaMap->find(flutter::EncodableValue("isGenerated"));
if (genIt != imageMetaMap->end()) {
if (auto genFlag = std::get_if<bool>(&genIt->second)) {
if (*genFlag) return std::nullopt;
}
}

auto dataIt = imageMetaMap->find(flutter::EncodableValue("data"));
if (dataIt == imageMetaMap->end()) return std::nullopt;

if (auto list = std::get_if<std::vector<flutter::EncodableValue>>(&dataIt->second)) {
std::vector<uint8_t> bytes;
bytes.reserve(list->size());
for (const auto& item : *list) {
if (auto val = std::get_if<int32_t>(&item)) {
bytes.push_back(static_cast<uint8_t>(*val));
} else if (auto val64 = std::get_if<int64_t>(&item)) {
bytes.push_back(static_cast<uint8_t>(*val64));
}
}
return bytes;
}
return std::nullopt;
};

// Propriétés globales (Audio + Vidéo)
SetStringProp(pStore, PKEY_Title, getString("title"));
SetStringProp(pStore, PKEY_Comment, getString("comment"));
SetUInt32Prop(pStore, PKEY_Media_Year, getInt("year"));

if (isAudio) {
SetStringProp(pStore, PKEY_Music_Artist, getString("artist"));
SetStringProp(pStore, PKEY_Music_AlbumTitle, getString("album"));
SetStringProp(pStore, PKEY_Music_AlbumArtist, getString("albumArtist"));
SetGenreProp(pStore, PKEY_Music_Genre, getString("genre"));
SetUInt32Prop(pStore, PKEY_Music_TrackNumber, getInt("trackNumber"));
SetUInt32Prop(pStore, PKEY_Music_PartOfSet, getInt("discNumber"));

// Écriture de la pochette d'album
auto imgData = getImageBytes();
if (imgData.has_value() && !imgData->empty()) {
SetImageProp(pStore, PKEY_ThumbnailStream, imgData);
}
} else {
SetGenreProp(pStore, PKEY_Keywords, getString("genre"));
}

// Note: les infos techniques (sampleRate, bitrate, codecs, framerate,
// résolution vidéo) sont dérivées du flux encodé lui-même et ne sont pas
// réinscriptibles via le Property System — elles ne sont donc lues, jamais
// écrites, tout comme sur les autres plateformes.

hr = pStore->Commit();
pStore->Release();

return SUCCEEDED(hr);
}

flutter::EncodableMap ReadMediaMetadata(const std::wstring& file_path, bool createThumbnail) {
  flutter::EncodableMap result;
  result[flutter::EncodableValue("title")] = flutter::EncodableValue();
  result[flutter::EncodableValue("duration")] = flutter::EncodableValue();
  result[flutter::EncodableValue("artist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("album")] = flutter::EncodableValue();
  result[flutter::EncodableValue("albumArtist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("year")] = flutter::EncodableValue();
  result[flutter::EncodableValue("genre")] = flutter::EncodableValue();
  result[flutter::EncodableValue("comment")] = flutter::EncodableValue();
  result[flutter::EncodableValue("imageMetadata")] = flutter::EncodableValue();
  result[flutter::EncodableValue("sampleRate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioBitrate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioChannels")] = flutter::EncodableValue();
  result[flutter::EncodableValue("bitsPerSample")] = flutter::EncodableValue();
  result[flutter::EncodableValue("audioCodec")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoCodec")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoBitrate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("frameRate")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoWidth")] = flutter::EncodableValue();
  result[flutter::EncodableValue("videoHeight")] = flutter::EncodableValue();

  WIN32_FILE_ATTRIBUTE_DATA fad;
  if (GetFileAttributesExW(file_path.c_str(), GetFileExInfoStandard, &fad)) {
    int64_t size = ((int64_t)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
    result[flutter::EncodableValue("fileSize")] = flutter::EncodableValue(size);
  } else {
    result[flutter::EncodableValue("fileSize")] = flutter::EncodableValue();
  }

  const std::wstring ext = GetExtensionLower(file_path);

  IPropertyStore* pStore = nullptr;
  HRESULT hr = SHGetPropertyStoreFromParsingName(file_path.c_str(), nullptr, GPS_DEFAULT, IID_PPV_ARGS(&pStore));

  if (SUCCEEDED(hr) && pStore) {
    if (auto v = GetStringProp(pStore, PKEY_Title))
      result[flutter::EncodableValue("title")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_Artist))
      result[flutter::EncodableValue("artist")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_AlbumTitle))
      result[flutter::EncodableValue("album")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_AlbumArtist))
      result[flutter::EncodableValue("albumArtist")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Music_TrackNumber))
      result[flutter::EncodableValue("trackNumber")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Music_PartOfSet))
      result[flutter::EncodableValue("discNumber")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Media_Year))
      result[flutter::EncodableValue("year")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_Genre))
      result[flutter::EncodableValue("genre")] = flutter::EncodableValue(*v);
    else if (auto vVideo = GetStringProp(pStore, PKEY_Keywords))
      result[flutter::EncodableValue("genre")] = flutter::EncodableValue(*vVideo);

    if (auto v = GetStringProp(pStore, PKEY_Comment))
      result[flutter::EncodableValue("comment")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt64Prop(pStore, PKEY_Media_Duration)) {
      int64_t ms = (int64_t)(*v / 10000LL);
      result[flutter::EncodableValue("duration")] = flutter::EncodableValue(ms);
    }

    // --- Infos techniques audio ---
    if (auto v = GetUInt32Prop(pStore, PKEY_Audio_SampleRate))
      result[flutter::EncodableValue("sampleRate")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Audio_EncodingBitrate))
      result[flutter::EncodableValue("audioBitrate")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Audio_ChannelCount))
      result[flutter::EncodableValue("audioChannels")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Audio_Format))
      result[flutter::EncodableValue("audioCodec")] = flutter::EncodableValue(*v);

    // --- Infos techniques vidéo ---
    if (auto v = GetUInt32Prop(pStore, PKEY_Video_FrameWidth))
      result[flutter::EncodableValue("videoWidth")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Video_FrameHeight))
      result[flutter::EncodableValue("videoHeight")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Video_EncodingBitrate))
      result[flutter::EncodableValue("videoBitrate")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Video_FrameRate)) {
      // PKEY_Video_FrameRate est exprimé en millièmes d'image par seconde.
      result[flutter::EncodableValue("frameRate")] =
          flutter::EncodableValue((double)(*v) / 1000.0);
    }

    if (auto v = GetStringProp(pStore, PKEY_Video_Compression))
      result[flutter::EncodableValue("videoCodec")] = flutter::EncodableValue(*v);
  }

  // --- Pochette embarquée ---
  bool foundRealArtwork = false;

  // 1) Extraction directe et fiable, indépendante du système.
  std::optional<ExtractedPicture> picture;
  if (ext == L"mp3" || ext == L"aac") {
    picture = ExtractId3v2Apic(file_path);
  } else if (ext == L"mp4" || ext == L"m4a" || ext == L"mov" || ext == L"3gp" || ext == L"3gpp") {
    picture = ExtractMp4Cover(file_path);
  }

  if (picture.has_value() && !picture->data.empty()) {
    result[flutter::EncodableValue("imageMetadata")] =
        flutter::EncodableValue(BuildImageMetadataFromBytes(picture->data, false));
    foundRealArtwork = true;
  } else if (pStore) {
    // 2) Repli sur PKEY_ThumbnailStream pour les formats non couverts.
    PROPVARIANT pv;
    PropVariantInit(&pv);
    if (SUCCEEDED(pStore->GetValue(PKEY_ThumbnailStream, &pv))) {
      if (pv.vt == VT_UNKNOWN && pv.punkVal) {
        IStream* pStream = nullptr;
        if (SUCCEEDED(pv.punkVal->QueryInterface(IID_PPV_ARGS(&pStream)))) {
          STATSTG statstg;
          if (SUCCEEDED(pStream->Stat(&statstg, STATFLAG_NONAME))) {
            ULONG size_bytes = static_cast<ULONG>(statstg.cbSize.QuadPart);
            if (size_bytes > 0) {
              LARGE_INTEGER liZero = {0};

              pStream->Seek(liZero, STREAM_SEEK_SET, nullptr);
              std::vector<uint8_t> buffer(size_bytes);
              ULONG bytesRead = 0;
              bool readOk = SUCCEEDED(pStream->Read(buffer.data(), size_bytes, &bytesRead)) && bytesRead > 0;

              pStream->Seek(liZero, STREAM_SEEK_SET, nullptr);
              result[flutter::EncodableValue("imageMetadata")] = flutter::EncodableValue(
                  BuildImageMetadataFromStream(pStream, readOk ? buffer.data() : nullptr,
                                                (int64_t)(readOk ? bytesRead : 0)));
              foundRealArtwork = readOk && bytesRead > 0;
            }
          }
          pStream->Release();
        }
      }
      PropVariantClear(&pv);
    }
  }

  // 3) Si toujours rien et que l'appelant a explicitement demandé une
  //    miniature ("createThumbnail"), et qu'il s'agit d'une vidéo, on
  //    capture une vraie image du flux vidéo. Jamais utilisé pour l'audio ni
  //    sans opt-in explicite.
  if (!foundRealArtwork && createThumbnail && IsVideoExtension(ext)) {
    auto generated = GenerateVideoThumbnail(file_path);
    if (generated.has_value()) {
      result[flutter::EncodableValue("imageMetadata")] = flutter::EncodableValue(*generated);
    }
  }

  if (pStore) pStore->Release();

  return result;
}

}  // namespace

void MediaMetadataPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "media_metadata", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MediaMetadataPlugin>();
  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

MediaMetadataPlugin::MediaMetadataPlugin() {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  MFStartup(MF_VERSION);
}

MediaMetadataPlugin::~MediaMetadataPlugin() {
  MFShutdown();
  CoUninitialize();
}

void MediaMetadataPlugin::HandleMethodCall(
  const flutter::MethodCall<flutter::EncodableValue>& method_call,
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string method = method_call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENT", "Expected map argument");
    return;
  }

  if (method == "readMetadata") {
    auto it = args->find(flutter::EncodableValue("filePath"));
    if (it == args->end()) {
      result->Error("INVALID_ARGUMENT", "filePath is required");
      return;
    }
    const auto& file_path_utf8 = std::get<std::string>(it->second);
    std::wstring wide_path = Utf8ToWide(file_path_utf8);

    bool createThumbnail = false;
    auto thumbIt = args->find(flutter::EncodableValue("createThumbnail"));
    if (thumbIt != args->end()) {
      if (auto flag = std::get_if<bool>(&thumbIt->second)) {
        createThumbnail = *flag;
      }
    }

    const std::wstring ext = GetExtensionLower(wide_path);
    static const std::vector<std::wstring> kImageExts = {
        L"jpg", L"jpeg", L"png", L"heic", L"webp", L"tiff", L"gif", L"bmp"};
    bool isImage = std::find(kImageExts.begin(), kImageExts.end(), ext) != kImageExts.end();

    auto metadata = isImage ? ReadImageFileMetadata(wide_path) : ReadMediaMetadata(wide_path, createThumbnail);
    result->Success(flutter::EncodableValue(metadata));

  } else if (method == "writeMetadata") {
    auto itPath = args->find(flutter::EncodableValue("filePath"));
    auto itMeta = args->find(flutter::EncodableValue("metadata"));
    if (itPath == args->end() || itMeta == args->end()) {
      result->Error("INVALID_ARGUMENT", "filePath and metadata are required");
      return;
    }
    const auto& file_path_utf8 = std::get<std::string>(itPath->second);
    const auto* metadata_map = std::get_if<flutter::EncodableMap>(&itMeta->second);
    if (!metadata_map) {
      result->Error("INVALID_ARGUMENT", "metadata must be a map");
      return;
    }
    std::wstring wide_path = Utf8ToWide(file_path_utf8);
    bool success = WriteMediaMetadata(wide_path, *metadata_map);
    result->Success(flutter::EncodableValue(success));
  } else {
    result->NotImplemented();
  }
}

}  // namespace media_metadata

void MediaMetadataPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  media_metadata::MediaMetadataPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
