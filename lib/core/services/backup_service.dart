import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';

/// Backup and restore service for user data.
///
/// Exports/imports: playlists, playlist items, favorites, history,
/// bookmarks, and settings as a JSON file.
class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// Export all user data to a JSON file.
  /// Returns the file path of the backup.
  Future<String> exportBackup() async {
    try {
      final data = await _gatherData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${backupDir.path}/sarwari_backup_$timestamp.json');
      await file.writeAsString(jsonStr);

      debugPrint('[BackupService] Exported to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[BackupService] Export failed: $e');
      rethrow;
    }
  }

  /// Import user data from a backup JSON file.
  Future<void> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filePath');
      }

      final jsonStr = await file.readAsString();
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      await _restoreData(data);
      debugPrint('[BackupService] Import completed successfully');
    } catch (e) {
      debugPrint('[BackupService] Import failed: $e');
      rethrow;
    }
  }

  /// Get list of available backup files.
  Future<List<BackupInfo>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) return [];

    final files = await backupDir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final backups = <BackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      final name = file.path.split(Platform.pathSeparator).last;
      backups.add(BackupInfo(
        path: file.path,
        fileName: name,
        createdAt: stat.modified,
        sizeBytes: stat.size,
      ));
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Delete a backup file.
  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _gatherData() async {
    final playlists = await _db.playlistDao.all();
    final history = await _db.historyDao.all();
    final favorites = await (_db.select(_db.mediaItems)
          ..where((t) => t.isFavorite.equals(true)))
        .get();
    final bookmarks = await _db.bookmarksDao.all();
    final settings = await (_db.select(_db.appSettings)).get();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'VolticPlayer',
      'playlists': playlists
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'type': p.type,
                'description': p.description,
                'coverPath': p.coverPath,
                'createdAt': p.createdAt.toIso8601String(),
                'updatedAt': p.updatedAt.toIso8601String(),
              })
          .toList(),
      'playlistItems': await _gatherPlaylistItems(),
      'favorites': favorites.map((f) => {'mediaId': f.id}).toList(),
      'history': history
          .map((h) => {
                'mediaId': h.mediaId,
                'lastPositionMs': h.lastPositionMs,
                'durationMs': h.durationMs,
                'playedAt': h.playedAt.toIso8601String(),
                'completed': h.completed,
                'playCount': h.playCount,
              })
          .toList(),
      'bookmarks': bookmarks
          .map((b) => {
                'mediaId': b.mediaId,
                'positionMs': b.positionMs,
                'title': b.title,
                'note': b.note,
                'createdAt': b.createdAt.toIso8601String(),
              })
          .toList(),
      'settings': settings
          .map((s) => {'key': s.key, 'value': s.value})
          .toList(),
    };
  }

  Future<List<Map<String, dynamic>>> _gatherPlaylistItems() async {
    final allPlaylists = await _db.playlistDao.all();
    final items = <Map<String, dynamic>>[];
    for (final playlist in allPlaylists) {
      final ids = await _db.playlistDao.itemIds(playlist.id);
      for (int i = 0; i < ids.length; i++) {
        items.add({
          'playlistId': playlist.id,
          'mediaId': ids[i],
          'position': i,
        });
      }
    }
    return items;
  }

  Future<void> _restoreData(Map<String, dynamic> data) async {
    // Restore settings
    if (data['settings'] != null) {
      for (final s in data['settings'] as List) {
        await _db.settingsDao.set(s['key'] as String, s['value'] as String);
      }
    }

    // Restore playlists
    final playlistIdMap = <int, int>{};
    if (data['playlists'] != null) {
      for (final p in data['playlists'] as List) {
        final oldId = p['id'] as int;
        final newId = await _db.playlistDao.create(
          p['name'] as String,
          p['type'] as String? ?? 'mixed',
        );
        playlistIdMap[oldId] = newId;
      }
    }

    // Restore playlist items
    if (data['playlistItems'] != null) {
      for (final pi in data['playlistItems'] as List) {
        final newPlaylistId = playlistIdMap[pi['playlistId'] as int];
        if (newPlaylistId != null) {
          await _db.playlistDao.addItem(
            newPlaylistId,
            pi['mediaId'] as int,
            position: pi['position'] as int?,
          );
        }
      }
    }

    // Restore favorites
    if (data['favorites'] != null) {
      for (final f in data['favorites'] as List) {
        await _db.mediaDao.setFavorite(f['mediaId'] as int, true);
      }
    }

    // Restore history
    if (data['history'] != null) {
      for (final h in data['history'] as List) {
        await _db.historyDao.recordPlay(
          mediaId: h['mediaId'] as int,
          positionMs: h['lastPositionMs'] as int,
          durationMs: h['durationMs'] as int,
          completed: h['completed'] as bool? ?? false,
        );
      }
    }

    // Restore bookmarks
    if (data['bookmarks'] != null) {
      for (final b in data['bookmarks'] as List) {
        await _db.bookmarksDao.insertBookmark(
          mediaId: b['mediaId'] as int,
          positionMs: b['positionMs'] as int,
          title: b['title'] as String?,
          note: b['note'] as String?,
        );
      }
    }
  }
}

/// Information about a backup file.
class BackupInfo {
  final String path;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupInfo({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
