import 'package:drift/drift.dart';

import 'app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Extended tables for video metadata, audio metadata, and subtitle preferences
// ─────────────────────────────────────────────────────────────────────────────

@DataClassName('VideoItemRow')
class VideoItems extends Table {
  @override
  String get tableName => 'video_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  RealColumn get fps => real().withDefault(const Constant(0))();
  TextColumn get videoCodec => text().withDefault(const Constant(''))();
  IntColumn get bitrate => integer().withDefault(const Constant(0))();
  TextColumn get hdrType => text().withDefault(const Constant(''))();
  IntColumn get rotation => integer().withDefault(const Constant(0))();
  RealColumn get aspectRatio => real().withDefault(const Constant(0))();
}

@DataClassName('AudioItemRow')
class AudioItems extends Table {
  @override
  String get tableName => 'audio_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer().references(MediaItems, #id)();
  TextColumn get artist => text().withDefault(const Constant(''))();
  TextColumn get album => text().withDefault(const Constant(''))();
  TextColumn get albumArtist => text().withDefault(const Constant(''))();
  TextColumn get genre => text().withDefault(const Constant(''))();
  IntColumn get discNumber => integer().withDefault(const Constant(0))();
  IntColumn get year => integer().nullable()();
  TextColumn get composer => text().nullable()();
  IntColumn get bitrate => integer().withDefault(const Constant(0))();
  IntColumn get sampleRate => integer().withDefault(const Constant(0))();
  IntColumn get channels => integer().withDefault(const Constant(2))();
  TextColumn get coverPath => text().nullable()();
}

@DataClassName('SubtitlePreferenceRow')
class SubtitlePreferences extends Table {
  @override
  String get tableName => 'subtitle_preferences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get fontFamily => text().withDefault(const Constant(''))();
  IntColumn get fontSize => integer().withDefault(const Constant(18))();
  TextColumn get fontColor => text().withDefault(const Constant('#FFFFFF'))();
  TextColumn get backgroundColor =>
      text().withDefault(const Constant('#80000000'))();
  TextColumn get outlineColor =>
      text().withDefault(const Constant('#000000'))();
  RealColumn get outlineWidth => real().withDefault(const Constant(1.0))();
  BoolColumn get shadow => boolean().withDefault(const Constant(true))();
  TextColumn get position => text().withDefault(const Constant('bottom'))();
  RealColumn get delay => real().withDefault(const Constant(0))();
  TextColumn get encoding => text().withDefault(const Constant('UTF-8'))();
}

@DataClassName('NetworkServerRow')
class NetworkServers extends Table {
  @override
  String get tableName => 'network_servers';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get protocol => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().withDefault(const Constant(0))();
  TextColumn get username => text().nullable()();
  TextColumn get encryptedPassword => text().nullable()();
  TextColumn get rootPath => text().withDefault(const Constant('/'))();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

@DataClassName('DownloadRow')
class Downloads extends Table {
  @override
  String get tableName => 'downloads';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get fileName => text()();
  TextColumn get destination => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get error => text().nullable()();
}
