import '../entities/media_item.dart';
import '../entities/library_entities.dart';

/// Repository interface: discovery & querying of media on device.
abstract class MediaRepository {
  /// Scan storage and persist new/updated items. Returns count inserted.
  ///
  /// [onProgress] reports (scanned, total) as discovery proceeds. [onPersisted]
  /// fires each time a batch of items has been written to the database — with
  /// flags for which media types that batch contained — so the UI can reveal
  /// media progressively (roughly every 5%) instead of all at once when the
  /// scan finishes.
  Future<int> scan({
    bool force = false,
    void Function(int scanned, int total)? onProgress,
    void Function(bool hasVideo, bool hasAudio)? onPersisted,
  });

  Future<List<MediaItem>> getVideos({int? limit, int? offset});
  Future<List<MediaItem>> getAudio({int? limit, int? offset});
  Future<int> countVideos();
  Future<int> countAudio();
  Future<MediaItem?> getById(int id);
  Future<List<MediaItem>> getByIds(List<int> ids);

  /// Case-insensitive search across file names.
  Future<List<MediaItem>> search(String query, {bool videoOnly = false});

  Future<void> updateMedia(MediaItem item);

  /// Insert a manually-provided item (demo content or picked file).
  Future<int> addManual(MediaItem item);

  /// Permanently deletes a media item. `deleteFile` controls whether the
  /// underlying file on disk is also removed (best-effort); database rows
  /// (favorites/history/playlists/bookmarks) are always cleaned up.
  Future<void> deleteMedia(int id, {bool deleteFile = true});

  /// Renames a media item. `renameFile` best-effort renames the file on
  /// disk (preserving extension); database fields are always updated.
  Future<void> renameMedia(int id, String newName, {bool renameFile = true});
}

/// Repository interface: favorites, history, bookmarks.
abstract class LibraryRepository {
  Future<List<MediaItem>> getFavorites();
  Future<void> toggleFavorite(int mediaId, bool favorite);

  Future<List<HistoryEntry>> getHistory();
  Future<void> recordPlay({
    required int mediaId,
    required int positionMs,
    required int durationMs,
    bool completed = false,
  });

  Future<void> clearHistory();
}

/// Repository interface: playlist CRUD + membership.
abstract class PlaylistRepository {
  Future<List<Playlist>> getAll();
  Future<Playlist?> getById(int id);
  Future<int> create(String name, {String type = 'mixed'});
  Future<void> rename(int id, String name);
  Future<void> delete(int id);

  Future<List<MediaItem>> getItems(int playlistId);
  Future<void> addItem(int playlistId, int mediaId, {int? position});
  Future<void> removeItem(int playlistId, int mediaId);
  Future<void> reorder(int playlistId, List<int> mediaIds);
  Future<int> countItems(int playlistId);
}

/// Repository interface: app settings & preferences.
abstract class SettingsRepository {
  Future<String> getThemeMode(); // 'system' | 'light' | 'dark' | 'oled'
  Future<void> setThemeMode(String mode);

  Future<bool> isFirstLaunch();
  Future<void> setFirstLaunchDone();

  Future<T?> getSetting<T>(String key, {T? defaultValue});
  Future<void> setSetting<T>(String key, T value);
}
