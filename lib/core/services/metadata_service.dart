import 'dart:io';

/// Extracts metadata from media files.
/// Uses filename parsing and file system info as fallback.
/// Online metadata (optional) is not included for privacy-first approach.
class MetadataService {
  /// Extract basic metadata from a file path.
  static MediaMetadata extractFromFile(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final displayName = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;

    // Parse artist/title from filename patterns like "Artist - Title.mp3"
    String? artist;
    String title = displayName;
    if (displayName.contains(' - ')) {
      final parts = displayName.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    return MediaMetadata(
      fileName: name,
      displayName: displayName,
      title: title,
      artist: artist,
      extension: extension,
      isVideo: _videoExtensions.contains(extension),
      isAudio: _audioExtensions.contains(extension),
    );
  }

  /// Parse duration from metadata bytes (simplified).
  /// For real metadata, use media_kit or native plugins.
  static Duration? parseDuration(List<int> bytes, String extension) {
    // This is a placeholder. In production, use:
    // - media_kit Player to get duration after opening
    // - ffmpeg metadata
    // - native platform metadata APIs
    return null;
  }

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'mpeg', 'mpg',
    'ts', 'm2ts', '3gp', 'wmv', 'ogv', 'm4v', 'gif', 'amv', '3g2',
    'vob', 'asf', 'f4v', 'dv', 'divx', 'rm', 'rmvb', 'mxf', '3gp2',
  };

  static const _audioExtensions = {
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'opus', 'm4a', 'alac',
    'ac3', 'wma', 'ape', 'aiff', 'aif', 'mid', 'midi', 'ra', 'amr',
    'pcm', 'dsf', 'dff', 'wv', 'tta', 'tak', 'dtshd', 'dts',
  };
}

/// Parsed metadata for a media file.
class MediaMetadata {
  final String fileName;
  final String displayName;
  final String title;
  final String? artist;
  final String? album;
  final String extension;
  final bool isVideo;
  final bool isAudio;
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final double? fps;

  const MediaMetadata({
    required this.fileName,
    required this.displayName,
    required this.title,
    this.artist,
    this.album,
    required this.extension,
    required this.isVideo,
    required this.isAudio,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.fps,
  });
}
