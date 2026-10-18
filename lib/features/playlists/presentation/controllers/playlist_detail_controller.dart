import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_revision.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

/// MVVM ViewModel for a single Playlist's contents.
class PlaylistDetailController extends AsyncNotifier<List<MediaItem>> {
  PlaylistDetailController(this._playlistId);
  final int _playlistId;

  late final PlaylistRepository _repo;

  @override
  Future<List<MediaItem>> build() async {
    _repo = ref.watch(playlistRepositoryProvider);
    return _repo.getItems(_playlistId);
  }

  Future<void> reload() async =>
      state = await AsyncValue.guard(() => _repo.getItems(_playlistId));

  Future<void> removeItem(int mediaId) async {
    await _repo.removeItem(_playlistId, mediaId);
    ref.read(playlistLibraryRevisionProvider.notifier).bump();
    await reload();
  }

  Future<void> addItem(int mediaId) async {
    await _repo.addItem(_playlistId, mediaId);
    ref.read(playlistLibraryRevisionProvider.notifier).bump();
    await reload();
  }
}

final playlistDetailControllerProvider =
    AsyncNotifierProvider.family<
      PlaylistDetailController,
      List<MediaItem>,
      int
    >(PlaylistDetailController.new);
