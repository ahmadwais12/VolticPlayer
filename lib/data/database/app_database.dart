import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'bookmarks_dao.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tables
// ─────────────────────────────────────────────────────────────────────────────

@DataClassName('MediaItemRow')
class MediaItems extends Table {
  @override
  String get tableName => 'media_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uri => text()();
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get fileName => text()();
  TextColumn get displayName => text()();
  TextColumn get extension => text().withDefault(const Constant(''))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();
  BoolColumn get isAudio => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();

  List<Set<Column>> get indexes => [
    {fileName},
    {extension},
    {isVideo},
    {isAudio},
  ];
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  @override
  String get tableName => 'playlists';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('mixed'))();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('PlaylistItemRow')
class PlaylistItems extends Table {
  @override
  String get tableName => 'playlist_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('HistoryRow')
class History extends Table {
  @override
  String get tableName => 'history';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get playedAt => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get playCount => integer().withDefault(const Constant(1))();

  List<Set<Column>> get indexes => [
    {playedAt},
    {mediaId},
  ];
}

class Favorites extends Table {
  @override
  String get tableName => 'favorites';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('FolderRow')
class Folders extends Table {
  @override
  String get tableName => 'folders';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable()();
  BoolColumn get isExcluded => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  @override
  String get tableName => 'bookmarks';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AppSettings extends Table {
  @override
  String get tableName => 'settings';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// DAOs
// ─────────────────────────────────────────────────────────────────────────────

@DriftAccessor(
  tables: [MediaItems, Favorites, History, PlaylistItems, Bookmarks],
)
class MediaDao extends DatabaseAccessor<AppDatabase> with _$MediaDaoMixin {
  MediaDao(super.db);

  Future<List<MediaItemRow>> allVideos({int? limit, int? offset}) =>
      (select(mediaItems)
            ..where((t) => t.isVideo.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.lastScannedAt)])
            ..limit(limit ?? 500, offset: offset))
          .get();

  Future<List<MediaItemRow>> allAudio({int? limit, int? offset}) =>
      (select(mediaItems)
            ..where((t) => t.isAudio.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.lastScannedAt)])
            ..limit(limit ?? 500, offset: offset))
          .get();

  Future<int> videoCount() {
    final count = mediaItems.uri.count(distinct: true);
    return (selectOnly(mediaItems)
          ..addColumns([count])
          ..where(mediaItems.isVideo.equals(true)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
  }

  Future<int> audioCount() {
    final count = mediaItems.uri.count(distinct: true);
    return (selectOnly(mediaItems)
          ..addColumns([count])
          ..where(mediaItems.isAudio.equals(true)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
  }

  Future<MediaItemRow?> byId(int id) =>
      (select(mediaItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<MediaItemRow>> byIds(List<int> ids) =>
      (select(mediaItems)..where((t) => t.id.isIn(ids))).get();

  Future<List<MediaItemRow>> byUris(List<String> uris) =>
      (select(mediaItems)..where((t) => t.uri.isIn(uris))).get();

  Future<List<MediaItemRow>> search(String q) =>
      (select(mediaItems)..where((t) => t.fileName.like('%$q%'))).get();

  Future<int> insertOrUpdate(Insertable<MediaItemRow> row) =>
      mediaItems.insertOnConflictUpdate(row);

  Future<void> setFavorite(int mediaId, bool favorite) =>
      (update(mediaItems)..where((t) => t.id.equals(mediaId))).write(
        MediaItemsCompanion(isFavorite: Value(favorite)),
      );

  Future<List<MediaItemRow>> favoriteMedia() =>
      (select(mediaItems)..where((t) => t.isFavorite.equals(true))).get();

  /// Removes a media item and every related row (favorites, history,
  /// playlist membership, bookmarks). Does NOT touch the file on disk.
  Future<void> removeMediaCascade(int mediaId) async {
    await (delete(favorites)..where((t) => t.mediaId.equals(mediaId))).go();
    await (delete(history)..where((t) => t.mediaId.equals(mediaId))).go();
    await (delete(playlistItems)..where((t) => t.mediaId.equals(mediaId))).go();
    await (delete(bookmarks)..where((t) => t.mediaId.equals(mediaId))).go();
    await (delete(mediaItems)..where((t) => t.id.equals(mediaId))).go();
  }
}

@DriftAccessor(tables: [History])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  Future<List<HistoryRow>> all() =>
      (select(history)..orderBy([(t) => OrderingTerm.desc(t.playedAt)])).get();

  Future<void> recordPlay({
    required int mediaId,
    required int positionMs,
    required int durationMs,
    required bool completed,
  }) async {
    final existing = await (select(
      history,
    )..where((t) => t.mediaId.equals(mediaId))).getSingleOrNull();
    if (existing == null) {
      await into(history).insert(
        HistoryCompanion.insert(
          mediaId: mediaId,
          lastPositionMs: Value(positionMs),
          durationMs: Value(durationMs),
          playedAt: DateTime.now(),
          completed: Value(completed),
        ),
      );
    } else {
      await (update(history)..where((t) => t.id.equals(existing.id))).write(
        HistoryCompanion(
          lastPositionMs: Value(positionMs),
          durationMs: Value(durationMs),
          playedAt: Value(DateTime.now()),
          completed: Value(completed),
          playCount: Value(existing.playCount + 1),
        ),
      );
    }
  }
}

@DriftAccessor(tables: [Playlists, PlaylistItems])
class PlaylistDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  Future<List<PlaylistRow>> all() => select(playlists).get();
  Future<PlaylistRow?> byId(int id) =>
      (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(String name, String type) => into(playlists).insert(
    PlaylistsCompanion.insert(
      name: name,
      type: Value(type),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> rename(int id, String name) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(
        PlaylistsCompanion(name: Value(name)),
      );

  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((t) => t.id.equals(id))).go();

  Future<int> itemCount(int playlistId) =>
      (select(playlistItems)..where((t) => t.playlistId.equals(playlistId)))
          .map((row) => row.mediaId)
          .get()
          .then((ids) => ids.length);

  Future<void> addItem(int playlistId, int mediaId, {int? position}) =>
      into(playlistItems).insert(
        PlaylistItemsCompanion.insert(
          playlistId: playlistId,
          mediaId: mediaId,
          position: Value(position ?? 0),
        ),
      );

  Future<void> removeItem(int playlistId, int mediaId) =>
      (delete(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId))
            ..where((t) => t.mediaId.equals(mediaId)))
          .go();

  Future<List<int>> itemIds(int playlistId) =>
      (select(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .map((row) => row.mediaId)
          .get();
}

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) => (select(
    appSettings,
  )..where((t) => t.key.equals(key))).map((r) => r.value).getSingleOrNull();

  Future<void> set(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: Value(value)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Database
// ─────────────────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    MediaItems,
    Playlists,
    PlaylistItems,
    History,
    Favorites,
    Folders,
    Bookmarks,
    AppSettings,
  ],
  daos: [MediaDao, HistoryDao, PlaylistDao, SettingsDao, BookmarksDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'sarwari_player',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 1;
}
