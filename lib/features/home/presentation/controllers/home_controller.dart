import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_metadata/media_metadata.dart' as media_metadata;

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_revision.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../core/services/thumbnail_service.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

class HomeState {
  final List<MediaItem> continueWatching;
  final Map<int, double> progress;
  final List<MediaItem> recentVideos;
  final List<MediaItem> music;
  final List<Playlist> playlists;
  final int videoCount;
  final int musicCount;

  const HomeState({
    this.continueWatching = const [],
    this.progress = const {},
    this.recentVideos = const [],
    this.music = const [],
    this.playlists = const [],
    this.videoCount = 0,
    this.musicCount = 0,
  });

  HomeState copyWith({
    List<MediaItem>? continueWatching,
    Map<int, double>? progress,
    List<MediaItem>? recentVideos,
    List<MediaItem>? music,
    List<Playlist>? playlists,
    int? videoCount,
    int? musicCount,
  }) => HomeState(
    continueWatching: continueWatching ?? this.continueWatching,
    progress: progress ?? this.progress,
    recentVideos: recentVideos ?? this.recentVideos,
    music: music ?? this.music,
    playlists: playlists ?? this.playlists,
    videoCount: videoCount ?? this.videoCount,
    musicCount: musicCount ?? this.musicCount,
  );
}

/// MVVM ViewModel for the Home dashboard.
class HomeController extends AsyncNotifier<HomeState> {
  late final MediaRepository _media;
  late final LibraryRepository _library;
  late final PlaylistRepository _playlists;
  Future<void> _artworkQueue = Future<void>.value();

  @override
  Future<HomeState> build() async {
    _media = ref.watch(mediaRepositoryProvider);
    _library = ref.watch(libraryRepositoryProvider);
    _playlists = ref.watch(playlistRepositoryProvider);

    // Read persisted data immediately; the app-level scanner runs separately.
    ref.listen<int>(videoLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(_refreshVideos());
    });
    ref.listen<int>(audioLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(_refreshMusic());
    });
    ref.listen<int>(playlistLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(_refreshPlaylists());
    });

    final initial = await _load();
    // Soft background refresh — updates only sections that changed.
    return initial;
  }

  Future<void> _refreshVideos() async {
    final videos = await _media.getVideos();
    final count = await _media.countVideos();
    if (!ref.mounted) return;
    state = state.whenData(
      (current) => current.copyWith(recentVideos: videos, videoCount: count),
    );
    _queueArtwork(videos.take(24).toList());
  }

  Future<void> _refreshMusic() async {
    final music = await _media.getAudio();
    final count = await _media.countAudio();
    if (!ref.mounted) return;
    state = state.whenData(
      (current) => current.copyWith(music: music, musicCount: count),
    );
    _queueArtwork(music.take(24).toList());
  }

  Future<void> _refreshPlaylists() async {
    final playlists = await _playlists.getAll();
    if (!ref.mounted) return;
    state = state.whenData((current) => current.copyWith(playlists: playlists));
  }

  Future<HomeState> _load() async {
    final history = await _library.getHistory();
    final recent = history.take(10).toList();
    final ids = recent.map((h) => h.mediaId).toList();
    final items = ids.isEmpty ? <MediaItem>[] : await _media.getByIds(ids);
    final progress = <int, double>{
      for (var i = 0; i < recent.length; i++)
        recent[i].mediaId: recent[i].progress,
    };
    // Full library sections on Home (no artificial small limit).
    final videos = await _media.getVideos();
    final music = await _media.getAudio();
    final videoCount = await _media.countVideos();
    final musicCount = await _media.countAudio();
    final playlists = await _playlists.getAll();
    final home = HomeState(
      continueWatching: items,
      progress: progress,
      recentVideos: videos,
      music: music,
      playlists: playlists,
      videoCount: videoCount,
      musicCount: musicCount,
    );
    _queueArtwork([...items, ...videos.take(24), ...music.take(24)]);
    return home;
  }

  void _queueArtwork(List<MediaItem> items) {
    _artworkQueue = _artworkQueue
        .then((_) => _populateArtwork(items))
        .catchError((Object _) {});
  }

  Future<void> _populateArtwork(List<MediaItem> items) async {
    final handled = <String>{};
    for (final item in items) {
      if (!ref.mounted || item.thumbnailPath?.isNotEmpty == true) continue;
      final filePath = item.path.isNotEmpty ? item.path : item.uri;
      if (filePath.isEmpty || filePath.startsWith('http')) continue;
      if (!handled.add(filePath)) continue;

      String? thumbnailPath;
      if (item.isAudio) {
        if (!media_metadata.MediaMetadata.isSupported(filePath)) continue;
        try {
          final metadata = await media_metadata.MediaMetadata.read(filePath);
          final imageBytes = metadata?.imageMetadata?.data;
          if (imageBytes != null && imageBytes.isNotEmpty) {
            thumbnailPath = await ThumbnailService.cacheThumbnail(
              filePath: filePath,
              imageBytes: imageBytes,
            );
          }
        } on MissingPluginException {
          return;
        } catch (_) {
          // Artwork is optional; keep loading the remaining library items.
        }
      } else if (item.isVideo) {
        thumbnailPath = await ThumbnailService.generateForVideo(filePath);
      }

      if (thumbnailPath == null || item.id == null || !ref.mounted) continue;
      final updated = item.copyWith(thumbnailPath: thumbnailPath);
      await _media.updateMedia(updated);
      if (!ref.mounted) return;
      state = state.whenData(
        (current) => current.copyWith(
          continueWatching: _replaceArtwork(current.continueWatching, updated),
          recentVideos: _replaceArtwork(current.recentVideos, updated),
          music: _replaceArtwork(current.music, updated),
        ),
      );
    }
  }

  List<MediaItem> _replaceArtwork(List<MediaItem> items, MediaItem updated) => [
    for (final item in items)
      if (item.id == updated.id) updated else item,
  ];

  /// Soft reload — keeps current UI visible while fresh data loads.
  Future<void> reload() async {
    final next = await _load();
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  /// Manual re-scan (may request permission). Soft-updates sections only.
  Future<void> rescanDevice() async {
    try {
      final beforeVideos = await _media.countVideos();
      final beforeAudio = await _media.countAudio();
      await scanMediaWithProgress(ref, _media, force: true);
      if (beforeVideos != await _media.countVideos()) {
        ref.read(videoLibraryRevisionProvider.notifier).bump();
      }
      if (beforeAudio != await _media.countAudio()) {
        ref.read(audioLibraryRevisionProvider.notifier).bump();
      }
    } catch (_) {
      // The scan progress provider owns the user-visible error state.
    }
  }
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
