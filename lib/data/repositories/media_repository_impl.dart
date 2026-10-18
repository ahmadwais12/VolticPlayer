import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/permissions/permission_service.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';
import '../datasources/device_media_scanner.dart';

/// Concrete implementation of [MediaRepository] backed by Drift + a scanner.
/// Uses [DeviceMediaScanner] to query Android MediaStore / iOS Photo Library
/// for all video and audio files on the device.
class MediaRepositoryImpl implements MediaRepository {
  final AppDatabase db;
  final DeviceMediaScanner _deviceScanner;
  final PermissionService permissions;
  Future<int>? _scanInProgress;

  MediaRepositoryImpl({
    required this.db,
    DeviceMediaScanner? deviceScanner,
    required this.permissions,
  }) : _deviceScanner = deviceScanner ?? const DeviceMediaScanner();

  @override
  Future<int> scan({
    bool force = false,
    void Function(int scanned, int total)? onProgress,
    void Function(bool hasVideo, bool hasAudio)? onPersisted,
  }) {
    // Home and the library tabs can become active together. Share one scan so
    // MediaStore queries don't race each other.
    return _scanInProgress ??= _scanDevice(
      force: force,
      onProgress: onProgress,
      onPersisted: onPersisted,
    ).whenComplete(() {
      _scanInProgress = null;
    });
  }

  Future<int> _scanDevice({
    bool force = false,
    void Function(int scanned, int total)? onProgress,
    void Function(bool hasVideo, bool hasAudio)? onPersisted,
  }) async {
    try {
      // Silent by default: never pop a permission dialog on app open.
      // Manual "Scan storage" actions pass force:true and may request.
      final granted = force
          ? await permissions.requestMediaPermissions()
          : await permissions.hasMediaAccess();
      if (!granted) {
        debugPrint(
          '[MediaRepository] Skipping device scan '
          '(${force ? "permission denied" : "no permission yet — silent"})',
        );
        return 0;
      }

      // Reveal media as it is discovered: buffer resolved items and flush them
      // to the database each time real progress crosses a 5% step, so the
      // library fills in while the bar climbs instead of appearing at 100%.
      const percentStep = 5;
      final pending = <MediaItem>[];
      var flushedStep = 0;
      var persistChain = Future<void>.value();

      void flush() {
        if (pending.isEmpty) return;
        final batch = List<MediaItem>.of(pending);
        pending.clear();
        final hasVideo = batch.any((m) => m.isVideo);
        final hasAudio = batch.any((m) => m.isAudio);
        // Serialize writes so overlapping steps can't interleave on the DB.
        persistChain = persistChain
            .then((_) => _persistScanResults(batch))
            .then((_) => onPersisted?.call(hasVideo, hasAudio))
            .catchError((Object e) {
              debugPrint('[MediaRepository] Incremental persist failed: $e');
            });
      }

      final found = await _deviceScanner.scanAll(
        onBatch: pending.addAll,
        onProgress: (scanned, total) {
          onProgress?.call(scanned, total);
          if (total <= 0) return;
          final step = (scanned * 100) ~/ (total * percentStep);
          if (step > flushedStep) {
            flushedStep = step;
            flush();
          }
        },
      );

      // Persist anything past the last 5% boundary, then wait for writes.
      flush();
      await persistChain;

      debugPrint(
        '[MediaRepository] Found ${found.length} media items on device',
      );
      return found.length;
    } catch (e) {
      final message = e.toString();
      if (message.contains('database is locked') ||
          message.contains('database is busy')) {
        // Avoid dumping the SQL statement and private file paths from its
        // bound parameters into the device log.
        debugPrint(
          '[MediaRepository] Scan paused because the database is busy',
        );
      } else {
        debugPrint('[MediaRepository] Scan failed: $e');
      }
      return 0;
    }
  }

  Future<void> _persistScanResults(List<MediaItem> found) async {
    final existingRows = await db.mediaDao.byUris(
      found.map((item) => item.uri).toSet().toList(),
    );
    final existingByUri = {for (final row in existingRows) row.uri: row};
    final companions = found.map((item) {
      final existing = existingByUri[item.uri];
      final keptThumb = existing?.thumbnailPath;
      final nextThumb =
          (keptThumb != null && keptThumb.isNotEmpty)
          ? keptThumb
          : item.thumbnailPath;
      return item
          .copyWith(
            id: existing?.id,
            isFavorite: existing?.isFavorite ?? item.isFavorite,
            thumbnailPath: nextThumb,
          )
          .toCompanion();
    }).toList();

    for (var attempt = 0; ; attempt++) {
      try {
        await db.batch((batch) {
          batch.insertAllOnConflictUpdate(db.mediaItems, companions);
        });
        return;
      } catch (error) {
        final message = error.toString();
        final isLocked =
            message.contains('database is locked') ||
            message.contains('database is busy');
        if (!isLocked || attempt >= 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

  @override
  Future<List<MediaItem>> getVideos({int? limit, int? offset}) async =>
      (await db.mediaDao.allVideos(
        limit: limit,
        offset: offset,
      )).map((e) => e.toEntity()).toList();

  @override
  Future<List<MediaItem>> getAudio({int? limit, int? offset}) async =>
      (await db.mediaDao.allAudio(
        limit: limit,
        offset: offset,
      )).map((e) => e.toEntity()).toList();

  @override
  Future<int> countVideos() => db.mediaDao.videoCount();

  @override
  Future<int> countAudio() => db.mediaDao.audioCount();

  @override
  Future<MediaItem?> getById(int id) async {
    final row = await db.mediaDao.byId(id);
    return row?.toEntity();
  }

  @override
  Future<List<MediaItem>> getByIds(List<int> ids) async =>
      (await db.mediaDao.byIds(ids)).map((e) => e.toEntity()).toList();

  @override
  Future<List<MediaItem>> search(String query, {bool videoOnly = false}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await db.mediaDao.search(q);
    return rows
        .where((e) => !videoOnly || e.isVideo)
        .map((e) => e.toEntity())
        .toList();
  }

  @override
  Future<void> updateMedia(MediaItem item) async {
    if (item.id == null) return;
    await db.mediaDao.insertOrUpdate(item.toCompanion());
  }

  @override
  Future<int> addManual(MediaItem item) async {
    final id = await db.mediaDao.insertOrUpdate(item.toCompanion());
    return id;
  }

  @override
  Future<void> deleteMedia(int id, {bool deleteFile = true}) async {
    final row = await db.mediaDao.byId(id);
    if (row == null) return;

    if (deleteFile) {
      await _deleteFileIfLocal(row);
    }

    await db.mediaDao.removeMediaCascade(id);
  }

  @override
  Future<void> renameMedia(
    int id,
    String newName, {
    bool renameFile = true,
  }) async {
    final row = await db.mediaDao.byId(id);
    if (row == null) return;
    final clean = newName.trim();
    if (clean.isEmpty) return;

    var uri = row.uri;
    var path = row.path;
    var fileName = row.fileName;
    var displayName = clean;

    // Only rename the physical file when it's a real local path.
    final local = _localFile(row);
    if (renameFile && local != null && local.existsSync()) {
      // Preserve the original extension.
      final ext = p.extension(row.fileName);
      final newFileName = clean + ext;
      final dir = p.dirname(local.path);
      final newPath = p.join(dir, newFileName);
      // Only perform the rename when the target differs (and doesn't clash).
      if (newPath != local.path && !File(newPath).existsSync()) {
        try {
          await local.rename(newPath);
          uri = newPath;
          path = newPath;
          fileName = newFileName;
        } catch (e) {
          debugPrint('[MediaRepository] File rename failed: $e');
        }
      } else if (newPath == local.path) {
        // Same name — nothing to change on disk.
      }
    }

    await (db.update(db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        uri: Value(uri),
        path: Value(path),
        fileName: Value(fileName),
        displayName: Value(displayName),
        lastScannedAt: Value(DateTime.now()),
      ),
    );
  }

  File? _localFile(MediaItemRow row) {
    final candidate = row.path.isNotEmpty ? row.path : row.uri;
    final isLocal =
        candidate.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(candidate);
    if (!isLocal) return null;
    return File(candidate);
  }

  Future<void> _deleteFileIfLocal(MediaItemRow row) async {
    final file = _localFile(row);
    if (file == null) return;
    try {
      // Delete companion files too (e.g. thumbnails / sidecars).
      final path = file.path;
      await file.delete();
      for (final extra in ['jpg', 'png', 'nfo', 'srt', 'vtt']) {
        final candidate = File('${p.withoutExtension(path)}.$extra');
        if (candidate.existsSync()) {
          try {
            await candidate.delete();
          } catch (_) {}
        }
      }
      debugPrint('[MediaRepository] Deleted file: $path');
    } catch (e) {
      debugPrint('[MediaRepository] File delete failed: $e');
    }
  }
}
