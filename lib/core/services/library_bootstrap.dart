import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/demo_media.dart';
import '../di/providers.dart';
import 'library_revision.dart';

/// Removes old demo rows, seeds default playlists. Device discovery
/// is owned by the single app-level startup scan.
class LibraryBootstrap {
  LibraryBootstrap._();

  static Future<void>? _inFlight;

  static Future<void> ensure(Ref ref) {
    return _inFlight ??= _run(ref).whenComplete(() => _inFlight = null);
  }

  static Future<void> _run(Ref ref) async {
    final media = ref.read(mediaRepositoryProvider);
    final playlists = ref.read(playlistRepositoryProvider);
    var removedDemoMedia = false;
    var seededPlaylists = false;

    try {
      removedDemoMedia = await _removeDemoMedia(ref);
    } catch (e) {
      debugPrint('[LibraryBootstrap] Demo cleanup failed: $e');
    }

    try {
      final existing = await playlists.getAll();
      if (existing.isEmpty) {
        await playlists.create('Favorites', type: 'mixed');
        await playlists.create('Watch later', type: 'video');
        await playlists.create('Liked music', type: 'audio');
        seededPlaylists = true;
        debugPrint('[LibraryBootstrap] Seeded default playlists');
      }
    } catch (e) {
      debugPrint('[LibraryBootstrap] Playlist seed failed: $e');
    }

    if (removedDemoMedia) {
      ref.read(videoLibraryRevisionProvider.notifier).bump();
      ref.read(audioLibraryRevisionProvider.notifier).bump();
    }
    if (seededPlaylists) {
      ref.read(playlistLibraryRevisionProvider.notifier).bump();
    }
  }

  /// Remove media rows that came from the former demo seeder.
  static Future<bool> _removeDemoMedia(Ref ref) async {
    final media = ref.read(mediaRepositoryProvider);
    final videos = await media.getVideos();
    final audio = await media.getAudio();
    final legacy = [...videos, ...audio]
        .where(
          (m) =>
              DemoMedia.isBundledDemo(m) ||
              DemoMedia.isLegacyNetworkDemo(m.uri),
        )
        .toList();

    if (legacy.isEmpty) return false;

    var changed = false;
    for (final item in legacy) {
      final id = item.id;
      if (id == null) continue;
      await media.deleteMedia(id, deleteFile: false);
      changed = true;
      debugPrint('[LibraryBootstrap] Removed demo ${item.fileName}');
    }
    return changed;
  }
}
