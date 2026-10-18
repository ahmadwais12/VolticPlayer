import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_revision.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../core/services/thumbnail_service.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

/// MVVM ViewModel for the Videos library tab.
class VideosController extends AsyncNotifier<List<MediaItem>> {
  late final MediaRepository _media;

  /// Guards against overlapping thumbnail passes (build + manual reload).
  bool _fillingThumbnails = false;

  @override
  Future<List<MediaItem>> build() async {
    _media = ref.watch(mediaRepositoryProvider);
    ref.listen<int>(videoLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(reload());
    });
    final items = await _media.getVideos();
    unawaited(_populateThumbnails(items));
    return items;
  }

  Future<void> reload() async {
    try {
      final next = await _media.getVideos();
      if (!ref.mounted) return;
      state = AsyncData(next);
      ref.invalidate(videoLibraryCountProvider);
      unawaited(_populateThumbnails(next));
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> scan() async {
    if (ref.read(libraryScanProgressProvider).isScanning) return;
    final beforeVideos = await _media.countVideos();
    final beforeAudio = await _media.countAudio();
    await scanMediaWithProgress(
      ref,
      _media,
      force: true,
      estimatedTotal: beforeVideos + beforeAudio,
    );
    if (!ref.mounted) return;
    if (beforeVideos != await _media.countVideos()) {
      ref.read(videoLibraryRevisionProvider.notifier).bump();
    }
    if (beforeAudio != await _media.countAudio()) {
      ref.read(audioLibraryRevisionProvider.notifier).bump();
    }
    await reload();
  }

  Future<void> _populateThumbnails(List<MediaItem> items) async {
    final pending = <MediaItem>[];
    for (final item in items) {
      final source = item.path.isNotEmpty ? item.path : item.uri;
      if (source.isEmpty || source.startsWith('http')) continue;
      if (!await _thumbnailExists(item.thumbnailPath)) pending.add(item);
    }
    if (pending.isEmpty || _fillingThumbnails) return;

    _fillingThumbnails = true;
    try {
      // Fill a few at a time and push UI updates so pictures appear live.
      const batchSize = 4;
      for (var offset = 0; offset < pending.length; offset += batchSize) {
        if (!ref.mounted) return;
        final batch = pending.skip(offset).take(batchSize).toList();
        final results = await Future.wait(
          batch.map((item) async {
            final source = item.path.isNotEmpty ? item.path : item.uri;
            final thumb = await ThumbnailService.generateForVideo(source);
            if (thumb == null || item.id == null) return null;
            final updated = item.copyWith(thumbnailPath: thumb);
            await _media.updateMedia(updated);
            return updated;
          }),
        );

        if (!ref.mounted) return;
        final byId = <int, MediaItem>{
          for (final item in results.whereType<MediaItem>())
            if (item.id != null) item.id!: item,
        };
        if (byId.isEmpty) continue;

        state = state.whenData(
          (list) => [
            for (final media in list) byId[media.id] ?? media,
          ],
        );
      }
    } finally {
      _fillingThumbnails = false;
    }
  }

  Future<bool> _thumbnailExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http')) return true;
    try {
      final filePath = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;
      final file = File(filePath);
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }
}

final videosControllerProvider =
    AsyncNotifierProvider<VideosController, List<MediaItem>>(
      VideosController.new,
    );

final videoLibraryCountProvider = FutureProvider<int>((ref) {
  ref.watch(videoLibraryRevisionProvider);
  return ref.watch(mediaRepositoryProvider).countVideos();
});
