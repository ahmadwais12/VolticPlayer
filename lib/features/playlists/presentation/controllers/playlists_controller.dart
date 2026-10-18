import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_revision.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../domain/repositories/repositories.dart';

/// A playlist together with how many items it currently contains, used to
/// render richer playlist tiles without an extra UI-to-repo round trip per row.
class PlaylistSummary {
  final Playlist playlist;
  final int itemCount;

  const PlaylistSummary({required this.playlist, required this.itemCount});

  /// Total duration in milliseconds across all items (when known).
  int get totalDurationMs => 0;
}

/// MVVM ViewModel for the Playlists list.
class PlaylistsController extends AsyncNotifier<List<PlaylistSummary>> {
  late final PlaylistRepository _repo;

  @override
  Future<List<PlaylistSummary>> build() async {
    _repo = ref.watch(playlistRepositoryProvider);
    ref.listen<int>(playlistLibraryRevisionProvider, (prev, next) {
      if (prev == next) return;
      unawaited(reload());
    });
    return _load();
  }

  Future<List<PlaylistSummary>> _load() async {
    final playlists = await _repo.getAll();
    final summaries = <PlaylistSummary>[];
    for (final p in playlists) {
      summaries.add(
        PlaylistSummary(
          playlist: p,
          itemCount: p.id == null ? 0 : await _repo.countItems(p.id!),
        ),
      );
    }
    return summaries;
  }

  /// Soft reload — no full-screen loading flash.
  Future<void> reload() async {
    final next = await _load();
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  Future<void> create(String name) async {
    await _repo.create(name);
    ref.read(playlistLibraryRevisionProvider.notifier).bump();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    ref.read(playlistLibraryRevisionProvider.notifier).bump();
  }

  Future<void> rename(int id, String name) async {
    await _repo.rename(id, name);
    ref.read(playlistLibraryRevisionProvider.notifier).bump();
  }
}

final playlistsControllerProvider =
    AsyncNotifierProvider<PlaylistsController, List<PlaylistSummary>>(
      PlaylistsController.new,
    );
