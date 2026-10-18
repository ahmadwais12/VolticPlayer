import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Thumbnail generation and caching service.
/// Stores thumbnails in the app's persistent support directory.
class ThumbnailService {
  static String? _cacheDir;

  /// Get the thumbnails cache directory.
  static Future<String> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    // Thumbnail paths are persisted in the media database, so keep the files
    // in stable app storage instead of a cache directory the OS may purge.
    final appDir = await getApplicationSupportDirectory();
    final thumbDir = Directory('${appDir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    _cacheDir = thumbDir.path;
    return _cacheDir!;
  }

  /// Generate a cache key for a media file based on path.
  static String _cacheKey(String filePath) {
    return sha256.convert(utf8.encode(_normalizePath(filePath))).toString();
  }

  static String _normalizePath(String raw) {
    var value = raw.trim();
    if (value.startsWith('file://')) {
      value = Uri.parse(value).toFilePath();
    }
    return value;
  }

  /// Get cached thumbnail path, or null if not cached.
  static Future<String?> getCachedThumbnail(String filePath) async {
    final dir = await cacheDir;
    final key = _cacheKey(filePath);
    final file = File('$dir/$key.jpg');
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    return null;
  }

  /// Extracts a poster frame from a local video file and caches it.
  ///
  /// Tries several frame offsets so short / unusual clips still get a picture.
  static Future<String?> generateForVideo(String filePath) async {
    final source = _normalizePath(filePath);
    if (source.isEmpty || source.startsWith('http')) return null;
    try {
      final cached = await getCachedThumbnail(source);
      if (cached != null) return cached;

      // Prefer early frames; some files fail at 1000ms but work at 0ms.
      const offsetsMs = <int>[0, 500, 1000, 3000, 5000];
      for (final timeMs in offsetsMs) {
        try {
          final bytes = await VideoThumbnail.thumbnailData(
            video: source,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 640,
            timeMs: timeMs,
            quality: 80,
          );
          if (bytes == null || bytes.isEmpty) continue;
          final path = await cacheThumbnail(
            filePath: source,
            imageBytes: bytes,
          );
          if (path != null) return path;
        } catch (_) {
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cache a thumbnail image for a media file.
  static Future<String?> cacheThumbnail({
    required String filePath,
    required List<int> imageBytes,
  }) async {
    try {
      final dir = await cacheDir;
      final key = _cacheKey(filePath);
      final file = File('$dir/$key.jpg');
      await file.writeAsBytes(imageBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Clear all cached thumbnails.
  static Future<void> clearCache() async {
    final dir = Directory(await cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _cacheDir = null;
    }
  }

  /// Get cache size in bytes.
  static Future<int> getCacheSize() async {
    final dir = Directory(await cacheDir);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }
}
