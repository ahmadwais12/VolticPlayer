import 'package:drift/drift.dart';

import '../../domain/entities/library_entities.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// Concrete [PlaylistRepository] backed by Drift DAOs.
class PlaylistRepositoryImpl implements PlaylistRepository {
  final AppDatabase db;

  PlaylistRepositoryImpl({required this.db});

  @override
  Future<List<Playlist>> getAll() async =>
      (await db.playlistDao.all()).map((e) => e.toEntity()).toList();

  @override
  Future<Playlist?> getById(int id) async {
    final row = await db.playlistDao.byId(id);
    return row?.toEntity();
  }

  @override
  Future<int> create(String name, {String type = 'mixed'}) =>
      db.playlistDao.create(name, type);

  @override
  Future<void> rename(int id, String name) =>
      db.playlistDao.rename(id, name);

  @override
  Future<void> delete(int id) => db.playlistDao.deletePlaylist(id);

  @override
  Future<List<MediaItem>> getItems(int playlistId) async {
    final ids = await db.playlistDao.itemIds(playlistId);
    if (ids.isEmpty) return const [];
    final rows = await db.mediaDao.byIds(ids);
    final byId = {for (final r in rows) r.id: r};
    // Preserve playlist order.
    final ordered = <MediaItem>[];
    for (final id in ids) {
      final row = byId[id];
      if (row != null) ordered.add(row.toEntity());
    }
    return ordered;
  }

  @override
  Future<void> addItem(int playlistId, int mediaId, {int? position}) =>
      db.playlistDao.addItem(playlistId, mediaId, position: position);

  @override
  Future<void> removeItem(int playlistId, int mediaId) =>
      db.playlistDao.removeItem(playlistId, mediaId);

  @override
  Future<int> countItems(int playlistId) => db.playlistDao.itemCount(playlistId);

  @override
  Future<void> reorder(int playlistId, List<int> mediaIds) async {
    for (var i = 0; i < mediaIds.length; i++) {
      await (db.update(db.playlistItems)
            ..where((t) => t.playlistId.equals(playlistId))
            ..where((t) => t.mediaId.equals(mediaIds[i])))
          .write(PlaylistItemsCompanion(position: Value(i)));
    }
  }
}
