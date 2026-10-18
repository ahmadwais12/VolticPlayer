import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_item.dart';

/// Walks a directory tree and collects media files supported by the app.
/// This is the low-level data source; business rules live in the repository.
class MediaScanner {
  const MediaScanner();

  Set<String> get _videoSet => Set.from(AppConstants.videoExtensions);
  Set<String> get _audioSet => Set.from(AppConstants.audioExtensions);

  Future<List<MediaItem>> scanDirectory(
    String rootPath, {
    List<String> excluded = const ['cache', 'Android'],
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    final result = <MediaItem>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      if (name.startsWith('.')) continue;
      if (excluded.any((e) => entity.path.contains('/$e/') ||
          entity.path.contains('\\$e\\'))) {
        continue;
      }
      final ext = _ext(name);
      if (!_videoSet.contains(ext) && !_audioSet.contains(ext)) continue;

      final stat = await entity.stat();
      final isVideo = _videoSet.contains(ext);
      final display = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      result.add(
        MediaItem(
          uri: entity.path,
          path: entity.path,
          fileName: name,
          displayName: display,
          extension: ext,
          size: stat.size,
          isVideo: isVideo,
          isAudio: !isVideo,
          modifiedAt: stat.modified,
          lastScannedAt: DateTime.now(),
        ),
      );
    }
    return result;
  }

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
