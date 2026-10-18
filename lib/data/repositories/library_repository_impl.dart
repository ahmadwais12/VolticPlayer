import '../../domain/entities/library_entities.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// Concrete [LibraryRepository] backed by Drift DAOs.
class LibraryRepositoryImpl implements LibraryRepository {
  final AppDatabase db;

  LibraryRepositoryImpl({required this.db});

  @override
  Future<List<MediaItem>> getFavorites() async =>
      (await db.mediaDao.favoriteMedia()).map((e) => e.toEntity()).toList();

  @override
  Future<void> toggleFavorite(int mediaId, bool favorite) =>
      db.mediaDao.setFavorite(mediaId, favorite);

  @override
  Future<List<HistoryEntry>> getHistory() async =>
      (await db.historyDao.all()).map((e) => e.toEntity()).toList();

  @override
  Future<void> recordPlay({
    required int mediaId,
    required int positionMs,
    required int durationMs,
    bool completed = false,
  }) =>
      db.historyDao.recordPlay(
        mediaId: mediaId,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: completed,
      );

  @override
  Future<void> clearHistory() => db.historyDao.deleteAll();
}

extension HistoryDaoX on HistoryDao {
  Future<void> deleteAll() => delete(history).go();
}
