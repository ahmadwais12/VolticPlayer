import 'package:drift/drift.dart';

import 'app_database.dart';

part 'bookmarks_dao.g.dart';

@DriftAccessor(tables: [Bookmarks])
class BookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarksDaoMixin {
  BookmarksDao(super.db);

  Future<List<BookmarkRow>> byMediaId(int mediaId) =>
      (select(bookmarks)
            ..where((t) => t.mediaId.equals(mediaId))
            ..orderBy([(t) => OrderingTerm.asc(t.positionMs)]))
          .get();

  Future<List<BookmarkRow>> all() =>
      (select(bookmarks)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<int> insertBookmark({
    required int mediaId,
    required int positionMs,
    String? title,
    String? note,
  }) =>
      into(bookmarks).insert(BookmarksCompanion.insert(
        mediaId: mediaId,
        positionMs: Value(positionMs),
        title: Value(title),
        note: Value(note),
        createdAt: Value(DateTime.now()),
      ));

  Future<void> updateBookmark(int id, {String? title, String? note}) =>
      (update(bookmarks)..where((t) => t.id.equals(id))).write(
        BookmarksCompanion(
          title: title != null ? Value(title) : const Value.absent(),
          note: note != null ? Value(note) : const Value.absent(),
        ),
      );

  Future<void> deleteBookmark(int id) =>
      (delete(bookmarks)..where((t) => t.id.equals(id))).go();

  Future<void> deleteByMediaId(int mediaId) =>
      (delete(bookmarks)..where((t) => t.mediaId.equals(mediaId))).go();
}
