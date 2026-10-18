import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/media_item.dart';
import '../di/providers.dart';

/// Ensures played network / local items are upserted into the local DB and
/// written to history so Home "Continue Watching" and History stay filled.
class PlaybackHistoryService {
  PlaybackHistoryService(this._ref);
  final Ref _ref;

  Future<void> record({
    required String uri,
    required String title,
    required bool isVideo,
    int positionMs = 0,
    int durationMs = 0,
    String? thumbnailUrl,
    String? artist,
  }) async {
    final cleanUri = uri.trim();
    if (cleanUri.isEmpty) return;

    try {
      final mediaRepo = _ref.read(mediaRepositoryProvider);
      final library = _ref.read(libraryRepositoryProvider);

      final matches = await mediaRepo.search(
        title.length > 40 ? title.substring(0, 40) : title,
      );
      MediaItem? existing;
      for (final m in matches) {
        if (m.uri == cleanUri) {
          existing = m;
          break;
        }
      }

      // Fallback: broader search by last path segment / video id.
      if (existing == null) {
        final segments = Uri.tryParse(cleanUri)?.pathSegments ?? const [];
        final needle = segments.isEmpty ? cleanUri : segments.last;
        final more = await mediaRepo.search(needle);
        for (final m in more) {
          if (m.uri == cleanUri) {
            existing = m;
            break;
          }
        }
      }

      final int mediaId;
      if (existing?.id != null) {
        mediaId = existing!.id!;
      } else {
        final fileName = title.trim().isEmpty ? 'media' : title.trim();
        mediaId = await mediaRepo.addManual(
          MediaItem(
            uri: cleanUri,
            path: cleanUri.startsWith('http') ? '' : cleanUri,
            fileName: fileName,
            displayName: fileName,
            extension: _guessExtension(cleanUri, isVideo: isVideo),
            isVideo: isVideo,
            isAudio: !isVideo,
            durationMs: durationMs,
            thumbnailPath: thumbnailUrl,
            artist: artist,
            lastScannedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );
      }

      await library.recordPlay(
        mediaId: mediaId,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: durationMs > 0 && positionMs >= durationMs,
      );
    } catch (e) {
      debugPrint('[PlaybackHistoryService] record failed: $e');
    }
  }

  String _guessExtension(String uri, {required bool isVideo}) {
    final path = Uri.tryParse(uri)?.path ?? uri;
    final dot = path.lastIndexOf('.');
    if (dot > 0 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
    }
    return isVideo ? 'mp4' : 'mp3';
  }
}

final playbackHistoryServiceProvider = Provider<PlaybackHistoryService>((ref) {
  return PlaybackHistoryService(ref);
});
