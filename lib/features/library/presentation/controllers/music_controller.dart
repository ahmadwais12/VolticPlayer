import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_metadata/media_metadata.dart' as media_metadata;

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_revision.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../core/services/thumbnail_service.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

/// MVVM ViewModel for the Music library tab.
class MusicController extends AsyncNotifier<List<MediaItem>> {
  late final MediaRepository _media;
  bool _fillingCovers = false;

  @override
  Future<List<MediaItem>> build() async {
    _media = ref.watch(mediaRepositoryProvider);
    ref.listen<int>(audioLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(reload());
    });
    final items = await _media.getAudio();
    _populateCovers(items);
    return items;
  }

  Future<void> reload() async {
    try {
      final next = await _media.getAudio();
      if (!ref.mounted) return;
      state = AsyncData(next);
      ref.invalidate(musicLibraryCountProvider);
      _populateCovers(next);
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

  Future<void> _populateCovers(List<MediaItem> items) async {
    if (_fillingCovers) return;
    _fillingCovers = true;
    final updatedItems = <int, MediaItem>{};
    try {
      for (final item in items) {
        if (!ref.mounted || item.thumbnailPath?.isNotEmpty == true) continue;
        final path = item.path.isNotEmpty ? item.path : item.uri;
        if (path.isEmpty ||
            path.startsWith('http') ||
            !media_metadata.MediaMetadata.isSupported(path)) {
          continue;
        }
        try {
          final metadata = await media_metadata.MediaMetadata.read(path);
          final imageBytes = metadata?.imageMetadata?.data;
          if (imageBytes == null || imageBytes.isEmpty || item.id == null) {
            continue;
          }
          final coverPath = await ThumbnailService.cacheThumbnail(
            filePath: path,
            imageBytes: imageBytes,
          );
          if (coverPath == null || !ref.mounted) continue;
          final updated = item.copyWith(thumbnailPath: coverPath);
          await _media.updateMedia(updated);
          if (!ref.mounted) return;
          updatedItems[item.id!] = updated;
        } on MissingPluginException {
          return;
        } catch (_) {}
      }
      if (ref.mounted && updatedItems.isNotEmpty) {
        state = state.whenData(
          (current) => [
            for (final media in current) updatedItems[media.id] ?? media,
          ],
        );
      }
    } finally {
      _fillingCovers = false;
    }
  }
}

final musicControllerProvider =
    AsyncNotifierProvider<MusicController, List<MediaItem>>(
      MusicController.new,
    );

final musicLibraryCountProvider = FutureProvider<int>((ref) {
  ref.watch(audioLibraryRevisionProvider);
  return ref.watch(mediaRepositoryProvider).countAudio();
});
