import 'dart:typed_data';

/// Describes an image, whether it's a standalone image file (jpg, png, ...),
/// artwork embedded inside an audio/video file (album cover, thumbnail...),
/// or a thumbnail generated on-the-fly from a video frame (see
/// [MediaMetadata.read]'s `createThumbnail` option).
class ImageMetadata {
  /// Raw encoded bytes of the image (the embedded artwork bytes, a
  /// generated video-frame thumbnail, or the whole file content when
  /// [Metadata] was read from a standalone image file). May be `null` if no
  /// image data could be extracted or generated.
  final Uint8List? data;

  /// Image container/type, e.g. `"jpeg"`, `"png"`, `"heic"`, `"webp"`,
  /// `"bmp"`, `"gif"`, `"tiff"`.
  final String? type;

  /// Size of the encoded image data, in bytes.
  ///
  /// For a standalone image file this is the file size. For embedded
  /// artwork or a generated thumbnail, this is the size of that picture data
  /// itself (which can be smaller than the whole media file).
  final int? fileSizeBytes;

  /// Pixel width of the image.
  final int? width;

  /// Pixel height of the image.
  final int? height;

  /// Free-form description associated with the image (e.g. EXIF
  /// `UserComment`, IPTC caption, or a similar metadata field depending on
  /// the platform/format).
  final String? description;

  /// `true` when [data] was *generated* by capturing a video frame (via the
  /// `createThumbnail` option) rather than extracted from a real embedded
  /// tag (ID3 `APIC`, MP4 `covr`, EXIF thumbnail...). Always `false` for
  /// standalone image files and for real embedded artwork.
  final bool isGenerated;

  const ImageMetadata({
    this.data,
    this.type,
    this.fileSizeBytes,
    this.width,
    this.height,
    this.description,
    this.isGenerated = false,
  });

  /// Creates an [ImageMetadata] from a raw map returned by the platform
  /// channel.
  factory ImageMetadata.fromMap(Map<dynamic, dynamic> map) {
    return ImageMetadata(
      data: map['data'] != null
          ? Uint8List.fromList(List<int>.from(map['data'] as List))
          : null,
      type: map['type'] as String?,
      fileSizeBytes: _parseInt(map['fileSizeBytes']),
      width: _parseInt(map['width']),
      height: _parseInt(map['height']),
      description: map['description'] as String?,
      isGenerated: map['isGenerated'] as bool? ?? false,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Converts this [ImageMetadata] instance to a map.
  Map<String, dynamic> toMap() => {
        'data': data,
        'type': type,
        'fileSizeBytes': fileSizeBytes,
        'width': width,
        'height': height,
        'description': description,
        'isGenerated': isGenerated,
      };

  @override
  String toString() => 'ImageMetadata('
      'type: $type, '
      'fileSizeBytes: $fileSizeBytes, '
      'dimensions: ${width ?? '?'}x${height ?? '?'}, '
      'description: $description, '
      'isGenerated: $isGenerated, '
      'hasData: ${data != null}'
      ')';
}

/// Holds all metadata extracted from a media file.
class Metadata {
  final String? title;
  final Duration? duration;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final int? year;
  final String? genre;

  /// Free-text comment tag (ID3 `COMM`, iTunes `©cmt`, Windows
  /// `System.Comment`, IPTC caption, ...).
  final String? comment;

  /// Structured description of the artwork/thumbnail (or of the file
  /// itself, when [Metadata] was read from a standalone image file): raw
  /// bytes, type, size in bytes, size in pixels, description, and whether
  /// it was generated from a video frame ([ImageMetadata.isGenerated]).
  final ImageMetadata? imageMetadata;

  /// Size of the media file itself, in bytes.
  final BigInt? fileSize;

  // --- Audio technical info ---------------------------------------------

  /// Audio sample rate, in Hz (e.g. `44100`, `48000`).
  final int? sampleRate;

  /// Audio bitrate, in bits per second.
  final int? audioBitrate;

  /// Number of audio channels (e.g. `1` mono, `2` stereo).
  final int? audioChannels;

  /// Bit depth of the audio stream (e.g. `16`, `24`), when available.
  final int? bitsPerSample;

  /// Audio codec identifier (e.g. `"AAC"`, `"MP3"`, `"audio/mpeg"`),
  /// platform-dependent format.
  final String? audioCodec;

  // --- Video technical info ---------------------------------------------

  /// Video codec identifier (e.g. `"AVC"`, `"HEVC"`, `"video/avc"`),
  /// platform-dependent format.
  final String? videoCodec;

  /// Video bitrate, in bits per second.
  final int? videoBitrate;

  /// Video frame rate, in frames per second.
  final double? frameRate;

  /// Video frame width, in pixels.
  final int? videoWidth;

  /// Video frame height, in pixels.
  final int? videoHeight;

  const Metadata({
    this.title,
    this.duration,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.year,
    this.genre,
    this.comment,
    this.imageMetadata,
    this.fileSize,
    this.sampleRate,
    this.audioBitrate,
    this.audioChannels,
    this.bitsPerSample,
    this.audioCodec,
    this.videoCodec,
    this.videoBitrate,
    this.frameRate,
    this.videoWidth,
    this.videoHeight,
  });

  /// Creates a [Metadata] instance from a raw map returned by the platform
  /// channel.
  factory Metadata.fromMap(Map<dynamic, dynamic> map) {
    return Metadata(
      title: map['title'] as String?,
      duration: map['duration'] != null
          ? Duration(milliseconds: (map['duration'] as num).toInt())
          : null,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      albumArtist: map['albumArtist'] as String?,
      trackNumber: _parseInt(map['trackNumber']),
      trackTotal: _parseInt(map['trackTotal']),
      discNumber: _parseInt(map['discNumber']),
      discTotal: _parseInt(map['discTotal']),
      year: _parseInt(map['year']),
      genre: map['genre'] as String?,
      comment: map['comment'] as String?,
      imageMetadata: map['imageMetadata'] != null
          ? ImageMetadata.fromMap(map['imageMetadata'] as Map)
          : null,
      fileSize: map['fileSize'] != null
          ? BigInt.from((map['fileSize'] as num).toInt())
          : null,
      sampleRate: _parseInt(map['sampleRate']),
      audioBitrate: _parseInt(map['audioBitrate']),
      audioChannels: _parseInt(map['audioChannels']),
      bitsPerSample: _parseInt(map['bitsPerSample']),
      audioCodec: map['audioCodec'] as String?,
      videoCodec: map['videoCodec'] as String?,
      videoBitrate: _parseInt(map['videoBitrate']),
      frameRate: _parseDouble(map['frameRate']),
      videoWidth: _parseInt(map['videoWidth']),
      videoHeight: _parseInt(map['videoHeight']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Converts this [Metadata] instance to a map.
  Map<String, dynamic> toMap() => {
        'title': title,
        'duration': duration?.inMilliseconds,
        'artist': artist,
        'album': album,
        'albumArtist': albumArtist,
        'trackNumber': trackNumber,
        'trackTotal': trackTotal,
        'discNumber': discNumber,
        'discTotal': discTotal,
        'year': year,
        'genre': genre,
        'comment': comment,
        'imageMetadata': imageMetadata?.toMap(),
        'fileSize': fileSize?.toInt(),
        'sampleRate': sampleRate,
        'audioBitrate': audioBitrate,
        'audioChannels': audioChannels,
        'bitsPerSample': bitsPerSample,
        'audioCodec': audioCodec,
        'videoCodec': videoCodec,
        'videoBitrate': videoBitrate,
        'frameRate': frameRate,
        'videoWidth': videoWidth,
        'videoHeight': videoHeight,
      };

  @override
  String toString() => 'Metadata('
      'title: $title, '
      'artist: $artist, '
      'album: $album, '
      'duration: $duration, '
      'year: $year, '
      'genre: $genre, '
      'comment: $comment, '
      'trackNumber: $trackNumber/$trackTotal, '
      'discNumber: $discNumber/$discTotal, '
      'albumArtist: $albumArtist, '
      'fileSize: $fileSize, '
      'sampleRate: $sampleRate, '
      'audioBitrate: $audioBitrate, '
      'audioChannels: $audioChannels, '
      'bitsPerSample: $bitsPerSample, '
      'audioCodec: $audioCodec, '
      'videoCodec: $videoCodec, '
      'videoBitrate: $videoBitrate, '
      'frameRate: $frameRate, '
      'videoWidth: $videoWidth, '
      'videoHeight: $videoHeight, '
      'imageMetadata: $imageMetadata'
      ')';
}
