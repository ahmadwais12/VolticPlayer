import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import 'downloader_limits.dart';
import 'downloader_logger.dart';
import 'downloader_rate_limiter.dart';
import 'downloader_settings.dart';
import 'file_type_validator.dart';
import 'review_service.dart';
import 'video_downloader_service.dart';

// ── Download status enum ───────────────────────────────────────────────────

enum DownloadStatus {
  /// Waiting for a free queue slot ("queued").
  pending,
  downloading,

  /// Transfer finished; file is being validated and finalized.
  processing,
  paused,
  completed,
  failed,
  cancelled,
}

// ── Download item model ────────────────────────────────────────────────────

class DownloadItem {
  /// Stable job identifier (UUID) used for logging and history records.
  final String id;
  final String uri;
  final String fileName;
  final String? title;
  final DownloadStatus status;
  final double progress;
  final int bytesReceived;
  final int totalBytes;
  final String? filePath;
  final String? error;
  final bool supportsRange;
  final int? pausedBytesReceived;
  final double speed; // bytes per second
  final DateTime createdAt; // defaults to _kEpoch sentinel
  final DateTime? completedAt;
  final String? sourceUrl;
  final String? sourceDomain;
  final String? format;
  final String? mediaType;
  final String? thumbnailUrl;
  final int? durationMs;
  final bool hasCaptions;
  final bool isPrivate;

  DownloadItem({
    String? id,
    required this.uri,
    required this.fileName,
    this.title,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.filePath,
    this.error,
    this.supportsRange = true,
    this.pausedBytesReceived,
    this.speed = 0,
    DateTime? createdAt,
    this.completedAt,
    this.sourceUrl,
    this.sourceDomain,
    this.format,
    this.mediaType,
    this.thumbnailUrl,
    this.durationMs,
    this.hasCaptions = false,
    this.isPrivate = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.fromMicrosecondsSinceEpoch(0);

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesReceived,
    int? totalBytes,
    String? filePath,
    String? fileName,
    String? title,
    String? error,
    bool clearError = false,
    bool? supportsRange,
    int? pausedBytesReceived,
    double? speed,
    DateTime? completedAt,
    String? sourceUrl,
    String? sourceDomain,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    int? durationMs,
    bool? hasCaptions,
    bool? isPrivate,
  }) => DownloadItem(
    id: id,
    uri: uri,
    fileName: fileName ?? this.fileName,
    title: title ?? this.title,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    totalBytes: totalBytes ?? this.totalBytes,
    filePath: filePath ?? this.filePath,
    error: clearError ? null : (error ?? this.error),
    supportsRange: supportsRange ?? this.supportsRange,
    pausedBytesReceived: pausedBytesReceived ?? this.pausedBytesReceived,
    speed: speed ?? this.speed,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sourceDomain: sourceDomain ?? this.sourceDomain,
    format: format ?? this.format,
    mediaType: mediaType ?? this.mediaType,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    durationMs: durationMs ?? this.durationMs,
    hasCaptions: hasCaptions ?? this.hasCaptions,
    isPrivate: isPrivate ?? this.isPrivate,
  );

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isActive =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.pending ||
      status == DownloadStatus.processing;
  bool get isPaused => status == DownloadStatus.paused;

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uri': uri,
    'fileName': fileName,
    'title': title,
    'status': status.name,
    'progress': progress,
    'bytesReceived': bytesReceived,
    'totalBytes': totalBytes,
    'filePath': filePath,
    'supportsRange': supportsRange,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'sourceUrl': sourceUrl,
    'sourceDomain': sourceDomain,
    'format': format,
    'mediaType': mediaType,
    'thumbnailUrl': thumbnailUrl,
    'durationMs': durationMs,
    'hasCaptions': hasCaptions,
    'isPrivate': isPrivate,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    id: json['id'] as String?,
    uri: json['uri'] as String,
    fileName: json['fileName'] as String,
    title: json['title'] as String?,
    status: DownloadStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => DownloadStatus.pending,
    ),
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    bytesReceived: json['bytesReceived'] as int? ?? 0,
    totalBytes: json['totalBytes'] as int? ?? 0,
    filePath: json['filePath'] as String?,
    supportsRange: json['supportsRange'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    completedAt: json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : null,
    sourceUrl: json['sourceUrl'] as String?,
    sourceDomain: json['sourceDomain'] as String?,
    format: json['format'] as String?,
    mediaType: json['mediaType'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationMs: json['durationMs'] as int?,
    hasCaptions: json['hasCaptions'] as bool? ?? false,
    isPrivate: json['isPrivate'] as bool? ?? false,
  );
}

// ── Download manager state ─────────────────────────────────────────────────

class DownloadManagerState {
  final List<DownloadItem> items;
  final int activeCount;
  final int maxConcurrent;

  const DownloadManagerState({
    this.items = const [],
    this.activeCount = 0,
    this.maxConcurrent = DownloaderLimits.maxConcurrent,
  });

  DownloadManagerState copyWith({
    List<DownloadItem>? items,
    int? maxConcurrent,
  }) {
    final list = items ?? this.items;
    return DownloadManagerState(
      items: list,
      activeCount: list.where((i) => i.isActive).length,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    );
  }

  List<DownloadItem> get completedItems =>
      items.where((i) => i.isCompleted).toList();

  List<DownloadItem> get activeItems => items.where((i) => i.isActive).toList();

  List<DownloadItem> get pausedItems => items.where((i) => i.isPaused).toList();

  List<DownloadItem> get failedItems =>
      items.where((i) => i.status == DownloadStatus.failed).toList();

  int get totalBytesDownloaded => items
      .where((i) => i.isCompleted)
      .fold(0, (sum, i) => sum + i.bytesReceived);

  bool isDownloaded(String uri) =>
      items.any((i) => i.uri == uri && i.isCompleted);

  DownloadItem? findByUri(String uri) {
    final matches = items.where((i) => i.uri == uri);
    return matches.isEmpty ? null : matches.first;
  }
}

// ── Download manager notifier ──────────────────────────────────────────────

class DownloadManager extends Notifier<DownloadManagerState> {
  late final Dio _dio;
  late final VideoDownloaderService _urlValidator;
  late DownloaderSettings _settings;
  final Map<String, CancelToken> _cancelTokens = {};
  final List<String> _queue = [];
  final Set<String> _active = {};
  // Reserves queue slots while destination checks and redirect resolution run.
  // Without this, simultaneous requests all see a free slot before any of
  // them has reached _active and exceed the configured concurrency limit.
  final Set<String> _starting = {};

  /// Sliding-window limiter for download requests (prompt §14).
  late final SlidingWindowRateLimiter _downloadLimiter;

  /// Job start timestamps, used for logging download duration.
  final Map<String, DateTime> _startTimes = {};

  /// Rolling speed samples per URI: list of (bytesReceived, timestamp).
  final Map<String, List<_SpeedSample>> _speedSamples = {};
  final Set<String> _sizeLimitExceeded = {};
  Timer? _speedTimer;
  Timer? _cleanupTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  DownloadManagerState build() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(hours: 2), // generous for large files
      ),
    );
    _urlValidator = VideoDownloaderService();
    _settings = ref.read(downloaderSettingsValueProvider).normalized;
    _downloadLimiter = SlidingWindowRateLimiter(
      limit: DownloaderLimits.downloadRateLimit,
    );
    // React to admin settings changes without rebuilding the manager
    // (rebuilding would drop the in-flight queue).
    ref.listen(downloaderSettingsValueProvider, (previous, next) {
      _settings = next.normalized;
      if (previous != null &&
          previous.maxConcurrent != _settings.maxConcurrent) {
        setMaxConcurrent(_settings.maxConcurrent);
      }
    });
    _startSpeedTracker();
    // Periodic cleanup of expired temporary files (prompt §15).
    _cleanupTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(_cleanupExpiredFiles());
    });
    // Restore persisted state, then sweep leftover temp files.
    Future.microtask(_restoreFromDisk).then((_) => _cleanupExpiredFiles());
    ref.onDispose(_dispose);
    return DownloadManagerState(
      maxConcurrent: _settings.maxConcurrent.clamp(1, 10),
    );
  }

  void _dispose() {
    _speedTimer?.cancel();
    _cleanupTimer?.cancel();
    for (final ct in _cancelTokens.values) {
      ct.cancel();
    }
    _cancelTokens.clear();
    _dio.close();
    _urlValidator.dispose();
  }

  // ── Configuration ─────────────────────────────────────────────────────

  void setMaxConcurrent(int max) {
    final maximum = DownloaderLimits.maxConcurrent.clamp(1, 10);
    final n = max.clamp(1, maximum);
    state = state.copyWith(maxConcurrent: n);
    _drainQueue();
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Download a media file. Downloads are queued so at most
  /// [DownloadManagerState.maxConcurrent] transfer simultaneously.
  Future<void> download({
    required String uri,
    required String fileName,
    String? title,
    String? sourceUrl,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    int? durationMs,
    bool hasCaptions = false,
    int? expectedBytes,
    bool allowDuplicate = false,
    bool skipUrlValidation = false,
  }) async {
    _diag(
      'download() called uri=${_shortUri(uri)} file="$fileName" '
      'mediaType=$mediaType expectedBytes=$expectedBytes '
      'skipUrlValidation=$skipUrlValidation allowDuplicate=$allowDuplicate',
    );
    _diag(
      'settings: enabled=${_settings.enabled} wifiOnly=${_settings.wifiOnly} '
      'audioEnabled=${_settings.audioEnabled} videoEnabled=${_settings.videoEnabled} '
      'fastDownload=${_settings.fastDownload} '
      'maxFileSizeBytes=${_settings.maxFileSizeBytes} '
      'maxConcurrent=${state.maxConcurrent}',
    );
    var existing = state.findByUri(uri);
    if (allowDuplicate && existing?.isCompleted == true) {
      final originalUri = Uri.tryParse(sourceUrl ?? uri);
      sourceUrl ??= originalUri?.replace(fragment: '').toString();
      uri = Uri.parse(uri)
          .replace(
            fragment: 'download-${DateTime.now().microsecondsSinceEpoch}',
          )
          .toString();
      existing = null;
    }
    final safeFileName = existing != null
        ? _sanitizeFileName(existing.fileName)
        : _uniqueFileName(_sanitizeFileName(fileName));
    sourceUrl ??= existing?.sourceUrl;
    format ??= existing?.format;
    mediaType ??= existing?.mediaType;
    thumbnailUrl ??= existing?.thumbnailUrl;
    durationMs ??= existing?.durationMs;
    hasCaptions = hasCaptions || (existing?.hasCaptions ?? false);
    // Don't duplicate.
    if (state.isDownloaded(uri)) {
      _diag('download() ignored: already downloaded uri=${_shortUri(uri)}');
      return;
    }
    if (_active.contains(uri) || _queue.contains(uri)) {
      _diag(
        'download() ignored: already active/queued uri=${_shortUri(uri)} '
        '(active=$_active queue=$_queue)',
      );
      return;
    }

    // Rate limit: DOWNLOADER_DOWNLOAD_RATE_LIMIT requests / minute (§14).
    if (!_downloadLimiter.allow()) {
      _failItem(
        uri,
        safeFileName,
        title,
        'Too many download requests. Please wait a moment and try again.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.rateLimited,
      );
      return;
    }

    // Admin controls (§25): master switch and per-type switches.
    if (!_settings.enabled) {
      _failItem(
        uri,
        safeFileName,
        title,
        'The downloader is disabled in settings.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.permission,
      );
      return;
    }
    if (_settings.wifiOnly) {
      final connections = await Connectivity().checkConnectivity();
      if (!connections.contains(ConnectivityResult.wifi)) {
        _failItem(
          uri,
          safeFileName,
          title,
          'This download is set to Wi-Fi only. Connect to Wi-Fi and retry.',
          sourceUrl: sourceUrl,
          format: format,
          mediaType: mediaType,
          thumbnailUrl: thumbnailUrl,
          category: DownloaderErrorCategory.permission,
        );
        return;
      }
    }
    if (mediaType == 'audio' && !_settings.audioEnabled) {
      _failItem(
        uri,
        safeFileName,
        title,
        'Audio downloads are disabled in settings.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.permission,
      );
      return;
    }
    if (mediaType == 'video' && !_settings.videoEnabled) {
      _failItem(
        uri,
        safeFileName,
        title,
        'Video downloads are disabled in settings.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.permission,
      );
      return;
    }

    // Known size up front: reject over the (possibly lowered) limit.
    if (expectedBytes != null && expectedBytes > _settings.maxFileSizeBytes) {
      _failItem(
        uri,
        safeFileName,
        title,
        'File too large — this file exceeds the maximum allowed download size.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.tooLarge,
      );
      return;
    }

    // Storage quota (§15): never allow unbounded disk consumption.
    final storageError =
        await _checkStorageCap(expectedBytes ?? 0) ??
        await _checkDiskSpaceError();
    if (storageError != null) {
      _failItem(
        uri,
        safeFileName,
        title,
        storageError,
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        category: DownloaderErrorCategory.storage,
      );
      return;
    }

    // Enforce HTTPS.
    if (!skipUrlValidation && !_isSecureUri(uri)) {
      _diag('download() rejected: insecure URL uri=${_shortUri(uri)}');
      _ensureItemRow(
        uri,
        safeFileName,
        title,
        DownloadStatus.failed,
        error: 'Insecure URL. Only HTTPS downloads are allowed.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );
      return;
    }

    if (!skipUrlValidation) {
      try {
        await _urlValidator.validatePublicDestination(uri);
      } catch (e) {
        _diag(
          'download() rejected: URL failed public-destination validation '
          'uri=${_shortUri(uri)} error=$e',
        );
        _ensureItemRow(
          uri,
          safeFileName,
          title,
          DownloadStatus.failed,
          error: 'Unsupported URL — this source is not currently supported.',
          sourceUrl: sourceUrl,
          format: format,
          mediaType: mediaType,
          thumbnailUrl: thumbnailUrl,
        );
        _persistToDisk();
        return;
      }
    }

    if (_active.length + _starting.length >= state.maxConcurrent) {
      _diag(
        'download() queued (concurrency full): active=${_active.length} '
        'starting=${_starting.length} max=${state.maxConcurrent} '
        'uri=${_shortUri(uri)}',
      );
      _queue.add(uri);
      _ensureItemRow(
        uri,
        safeFileName,
        title,
        DownloadStatus.pending,
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        durationMs: durationMs,
        hasCaptions: hasCaptions,
      );
      _persistToDisk();
      return;
    }
    _diag('download() passed all checks — launching uri=${_shortUri(uri)}');
    await _launchDownload(
      uri: uri,
      fileName: safeFileName,
      title: title,
      sourceUrl: sourceUrl,
      format: format,
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      hasCaptions: hasCaptions,
      skipUrlValidation: skipUrlValidation,
    );
  }

  Future<void> downloadAgain(DownloadItem item) => download(
    uri: Uri.parse(item.uri).replace(fragment: '').toString(),
    fileName: item.fileName,
    title: item.title,
    sourceUrl:
        item.sourceUrl ?? Uri.parse(item.uri).replace(fragment: '').toString(),
    format: item.format,
    mediaType: item.mediaType,
    thumbnailUrl: item.thumbnailUrl,
    durationMs: item.durationMs,
    hasCaptions: item.hasCaptions,
    expectedBytes: item.totalBytes > 0 ? item.totalBytes : null,
    allowDuplicate: true,
  );

  /// Resume a previously paused download.
  Future<void> resume(String uri) async {
    final item = state.findByUri(uri);
    if (item == null || !item.isPaused) return;

    // Re-check disk space before resuming.
    final storageError = await _checkDiskSpaceError();
    if (storageError != null) {
      _updateItem(
        uri,
        (i) => i.copyWith(status: DownloadStatus.failed, error: storageError),
      );
      _persistToDisk();
      return;
    }

    if (_active.length + _starting.length >= state.maxConcurrent) {
      if (!_queue.contains(uri)) _queue.add(uri);
      _updateItem(uri, (i) => i.copyWith(status: DownloadStatus.pending));
      _persistToDisk();
      _drainQueue();
      return;
    }
    await _launchDownload(
      uri: uri,
      fileName: item.fileName,
      title: item.title,
      sourceUrl: item.sourceUrl,
      format: item.format,
      mediaType: item.mediaType,
      thumbnailUrl: item.thumbnailUrl,
      durationMs: item.durationMs,
      hasCaptions: item.hasCaptions,
    );
  }

  /// Pause an active download, preserving bytes received so far.
  void pause(String uri) {
    final item = state.findByUri(uri);
    if (item == null) return;

    _cancelTokens[uri]?.cancel('pause');
    _cancelTokens.remove(uri);
    _active.remove(uri);
    _queue.remove(uri);
    _clearSpeedSamples(uri);

    _updateItem(
      uri,
      (i) => i.copyWith(
        status: DownloadStatus.paused,
        pausedBytesReceived: i.bytesReceived,
        speed: 0,
      ),
    );
    _persistToDisk();
    _drainQueue();
  }

  /// Cancel an active or queued download.
  void cancel(String uri) {
    _cancelTokens[uri]?.cancel();
    _cancelTokens.remove(uri);
    _queue.remove(uri);
    _active.remove(uri);
    _clearSpeedSamples(uri);

    _updateItem(
      uri,
      (i) => i.copyWith(status: DownloadStatus.cancelled, speed: 0),
    );
    _persistToDisk();
  }

  /// Cancel all active and queued downloads.
  void cancelAll() {
    for (final uri in List<String>.from(_active)) {
      cancel(uri);
    }
    for (final uri in List<String>.from(_queue)) {
      cancel(uri);
    }
  }

  /// Pause all active and queued downloads.
  void pauseAll() {
    final targets = <String>{..._active, ..._queue};
    for (final uri in targets) {
      pause(uri);
    }
  }

  /// Resume every paused transfer, respecting the configured queue limit.
  int resumeAll() {
    final paused = state.items.where((item) => item.isPaused).toList();
    for (final item in paused) {
      unawaited(resume(item.uri));
    }
    return paused.length;
  }

  /// Rename a completed download on disk and in the list.
  Future<bool> rename(String uri, String newBaseName) async {
    final item = state.findByUri(uri);
    if (item == null || item.filePath == null) return false;
    final cleaned = _sanitizeFileName(newBaseName.trim());
    if (cleaned.isEmpty) return false;
    final oldFile = File(item.filePath!);
    if (!await oldFile.exists()) return false;
    final ext = p.extension(item.filePath!);
    final dir = p.dirname(item.filePath!);
    final nextPath = p.join(dir, '$cleaned$ext');
    if (nextPath == item.filePath) return true;
    if (await File(nextPath).exists()) return false;
    final renamed = await oldFile.rename(nextPath);
    _updateItem(
      uri,
      (current) => current.copyWith(
        filePath: renamed.path,
        fileName: p.basename(renamed.path),
        title: cleaned,
      ),
    );
    _persistToDisk();
    return true;
  }

  /// Move a completed download into or out of the Private tab.
  void setPrivate(String uri, {required bool value}) {
    final item = state.findByUri(uri);
    if (item == null || !item.isCompleted) return;
    _updateItem(uri, (current) => current.copyWith(isPrivate: value));
    _persistToDisk();
  }

  /// Persist a probed media duration for list badges.
  void setDurationMs(String uri, int durationMs) {
    if (durationMs <= 0) return;
    final item = state.findByUri(uri);
    if (item == null || (item.durationMs ?? 0) > 0) return;
    _updateItem(uri, (current) => current.copyWith(durationMs: durationMs));
    _persistToDisk();
  }

  /// Remove a completed, failed, paused, or cancelled download and delete file.
  Future<void> remove(String uri) async {
    final item = state.findByUri(uri);
    _cancelTokens[uri]?.cancel();
    _cancelTokens.remove(uri);
    _queue.remove(uri);
    _active.remove(uri);
    _clearSpeedSamples(uri);

    if (item?.filePath != null) {
      final file = File(item!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    state = state.copyWith(
      items: state.items.where((i) => i.uri != uri).toList(),
    );
    _persistToDisk();
  }

  /// Clear all completed and cancelled downloads.
  Future<void> clearCompleted() async {
    final toRemove = state.items
        .where(
          (i) =>
              i.isCompleted ||
              i.status == DownloadStatus.cancelled ||
              i.status == DownloadStatus.failed,
        )
        .map((i) => i.uri)
        .toList();
    for (final uri in toRemove) {
      await remove(uri);
    }
  }

  String? getLocalPath(String uri) {
    final item = state.findByUri(uri);
    if (item?.isCompleted == true) return item!.filePath;
    return null;
  }

  bool isAvailableOffline(String uri) {
    final localPath = getLocalPath(uri);
    if (localPath == null) return false;
    return File(localPath).existsSync();
  }

  /// Scan the downloads directory and rebuild state from disk.
  Future<void> refreshFromDisk() async {
    final dir = await _getDownloadDirectory();
    if (!await dir.exists()) return;

    // Downloads live in the Images / Videos / Musics subfolders, so the scan
    // has to be recursive — minus the hidden temp folder holding .part files.
    final tempPath = (await _getTempDirectory()).path;
    final files = await dir
        .list(recursive: true, followLinks: false)
        .where((e) => e is File && !e.path.startsWith(tempPath))
        .toList();
    final existingUris = state.items.map((i) => i.uri).toSet();
    final items = List<DownloadItem>.from(state.items);

    for (final file in files) {
      if (file is File) {
        final name = file.path.split(Platform.pathSeparator).last;
        if (!existingUris.contains(file.path)) {
          items.add(
            DownloadItem(
              uri: file.path,
              fileName: name,
              title: name,
              status: DownloadStatus.completed,
              progress: 1.0,
              filePath: file.path,
              bytesReceived: await file.length(),
              totalBytes: await file.length(),
            ),
          );
        }
      }
    }

    // Remove items whose files no longer exist on disk.
    final validItems = items.where((item) {
      if (item.isCompleted && item.filePath != null) {
        return File(item.filePath!).existsSync();
      }
      return true;
    }).toList();

    state = state.copyWith(items: validItems);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  Future<void> _startDownload({
    required String uri,
    required String fileName,
    String? title,
    String? sourceUrl,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    int? durationMs,
    bool hasCaptions = false,
    bool skipUrlValidation = false,
  }) async {
    // No runtime permission needed: downloads are written to the app's own
    // documents directory (see [_getDownloadDirectory]), which is always
    // writable. Gating this on a storage permission used to fail every
    // download on Android 11+, where MANAGE_EXTERNAL_STORAGE is not granted.
    final dir = await _getDownloadDirectory();
    final tempDir = await _getTempDirectory();
    final safeName = _sanitizeFileName(fileName);
    // Files are sorted into the Images / Videos / Musics subfolder that
    // matches their media kind.
    final targetDir = Directory(
      p.join(dir.path, _subfolderFor(mediaType, safeName)),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final filePath = p.join(targetDir.path, safeName);
    // Transfers land in a hidden temp folder; only validated files are
    // renamed into the downloads folder (prompt §15 / §16).
    final tempPath = p.join(tempDir.path, '$safeName.part');
    late final String requestUri;
    try {
      requestUri = skipUrlValidation
          ? uri
          : await _urlValidator.resolveSafeRedirects(uri);
      _diag(
        '_startDownload uri=${_shortUri(uri)} -> requestUri=${_shortUri(requestUri)} '
        'tempPath=$tempPath filePath=$filePath',
      );
    } catch (e) {
      _diag(
        '_startDownload redirect resolution FAILED uri=${_shortUri(uri)} error=$e',
      );
      _ensureItemRow(
        uri,
        fileName,
        title,
        DownloadStatus.failed,
        error: 'The media server could not be reached safely.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );
      _persistToDisk();
      return;
    }
    final cancelToken = CancelToken();
    _cancelTokens[uri] = cancelToken;
    _starting.remove(uri);
    _active.add(uri);
    _startTimes[uri] = DateTime.now();

    // Probe the server once: whether it honours byte ranges, and the total
    // size. Range support lets us fetch in bounded chunks, which is what
    // keeps throttling hosts (e.g. YouTube's googlevideo) from stalling a
    // single long-lived stream.
    final item = state.findByUri(uri);
    final tempFile = File(tempPath);
    var resumeBytes = item?.pausedBytesReceived ?? 0;
    if (resumeBytes > 0 && !tempFile.existsSync()) {
      // The partial file was cleaned up — restart from zero instead of
      // appending at an offset into a missing file (corrupt output).
      resumeBytes = 0;
      _updateItem(
        uri,
        (i) => i.copyWith(
          pausedBytesReceived: null,
          bytesReceived: 0,
          totalBytes: 0,
          progress: 0,
        ),
      );
    }
    // Trust the bytes actually on disk over the recorded counter: a pause can
    // land mid-chunk, so the file is the source of truth for the resume point.
    if (resumeBytes > 0) {
      try {
        resumeBytes = await tempFile.length();
      } catch (_) {
        resumeBytes = 0;
      }
    }

    final probe = await _probeServer(
      requestUri,
      followRedirects: skipUrlValidation,
    );
    var supportsRange = probe.supportsRange;
    final totalBytes = probe.total;
    _diag(
      '_startDownload probe result uri=${_shortUri(uri)} '
      'supportsRange=$supportsRange totalBytes=$totalBytes resumeBytes=$resumeBytes',
    );
    if (resumeBytes > 0 && !supportsRange) {
      // Server doesn't support ranges — start fresh.
      resumeBytes = 0;
      await _discardPartialFile(tempPath);
      _updateItem(
        uri,
        (i) => i.copyWith(
          pausedBytesReceived: null,
          bytesReceived: 0,
          progress: 0,
        ),
      );
    }

    // Ensure item row exists.
    _ensureItemRow(
      uri,
      fileName,
      title,
      DownloadStatus.downloading,
      sourceUrl: sourceUrl,
      format: format,
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      hasCaptions: hasCaptions,
    );
    _updateItem(
      uri,
      (i) => i.copyWith(
        status: DownloadStatus.downloading,
        supportsRange: supportsRange,
        speed: 0,
        durationMs: durationMs,
        hasCaptions: hasCaptions,
        // Surface the authoritative size immediately so the progress bar is
        // determinate from the first byte instead of showing "Preparing…".
        totalBytes: totalBytes > 0 ? totalBytes : i.totalBytes,
        bytesReceived: resumeBytes,
        progress: totalBytes > 0
            ? (resumeBytes / totalBytes).clamp(0.0, 1.0)
            : i.progress,
      ),
    );
    _clearSpeedSamples(uri);
    DownloaderLogger.log(
      DownloaderEvent.downloadStarted,
      jobId: state.findByUri(uri)?.id,
      provider: 'public_media',
      domain: DownloaderLogger.domainOf(sourceUrl ?? uri),
      status: 'downloading',
    );

    try {
      final alreadyComplete = totalBytes > 0 && resumeBytes >= totalBytes;
      if (!alreadyComplete) {
        if (supportsRange && totalBytes > resumeBytes) {
          // Bounded Range chunks. This is what keeps throttling hosts
          // (YouTube's googlevideo) from stalling a single long-lived stream,
          // and it is also how the "Fast Download" multi-connection option
          // splits one file into parts.
          final connections = _settings.fastDownload ? _kFastConnections : 1;
          if (connections > 1 &&
              resumeBytes == 0 &&
              totalBytes >= _kChunkSize * 2) {
            _diag(
              '_startDownload branch=SEGMENTS (parallel) uri=${_shortUri(uri)} '
              'connections=$connections totalBytes=$totalBytes',
            );
            await _downloadSegments(
              uri: uri,
              requestUri: requestUri,
              tempPath: tempPath,
              cancelToken: cancelToken,
              totalBytes: totalBytes,
              connections: connections,
              followRedirects: skipUrlValidation,
            );
          } else {
            _diag(
              '_startDownload branch=CHUNKED (sequential) uri=${_shortUri(uri)} '
              'startByte=$resumeBytes totalBytes=$totalBytes '
              'chunks~${((totalBytes - resumeBytes) / _kChunkSize).ceil()}',
            );
            await _downloadChunked(
              uri: uri,
              requestUri: requestUri,
              tempPath: tempPath,
              cancelToken: cancelToken,
              startByte: resumeBytes,
              totalBytes: totalBytes,
              followRedirects: skipUrlValidation,
            );
          }
        } else {
          // No usable range support or unknown size: single-stream fallback.
          _diag(
            '_startDownload branch=SINGLE-STREAM fallback uri=${_shortUri(uri)} '
            'supportsRange=$supportsRange totalBytes=$totalBytes '
            'resumeBytes=$resumeBytes '
            '(WARNING: single-stream stalls on throttled hosts like googlevideo)',
          );
          await _downloadSingleStream(
            uri: uri,
            requestUri: requestUri,
            tempPath: tempPath,
            cancelToken: cancelToken,
            resumeBytes: resumeBytes,
            supportsRange: supportsRange,
            followRedirects: skipUrlValidation,
          );
        }
      } else {
        _diag('_startDownload already complete on disk uri=${_shortUri(uri)}');
      }
      await _finalizeDownload(uri, tempPath, filePath);
    } on DioException catch (e) {
      _diag(
        '_startDownload DioException uri=${_shortUri(uri)} type=${e.type} '
        'message=${e.message} response=${e.response?.statusCode} error=${e.error}',
      );
      if (e.type == DioExceptionType.cancel) {
        if (_sizeLimitExceeded.contains(uri)) {
          await _discardPartialFile(tempPath);
          _failExisting(
            uri,
            'File too large — this file exceeds the maximum allowed download size.',
            category: DownloaderErrorCategory.tooLarge,
          );
          return;
        }
        // Check if this was a pause vs user-cancel.
        final msg = e.message ?? '';
        if (msg == 'pause') {
          // Already handled in pause(); the temp file is kept for resume.
          return;
        }
        await _discardPartialFile(tempPath);
        _updateItem(
          uri,
          (i) => i.copyWith(status: DownloadStatus.cancelled, speed: 0),
        );
        _logTerminal(
          DownloaderEvent.downloadCancelled,
          uri,
          category: DownloaderErrorCategory.cancelled,
        );
      } else {
        await _discardPartialFile(tempPath);
        _failExisting(
          uri,
          'Download failed. Please try again.',
          category:
              e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout
              ? DownloaderErrorCategory.timeout
              : DownloaderErrorCategory.network,
        );
      }
    } catch (e, st) {
      _diag(
        '_startDownload UNEXPECTED error uri=${_shortUri(uri)} '
        '${e.runtimeType}: $e\n$st',
      );
      await _discardPartialFile(tempPath);
      _failExisting(
        uri,
        'Download failed. Please try again.',
        category: DownloaderErrorCategory.unknown,
      );
    } finally {
      _cancelTokens.remove(uri);
      _active.remove(uri);
      _startTimes.remove(uri);
      _clearSpeedSamples(uri);
      _sizeLimitExceeded.remove(uri);
      _persistToDisk();
      _drainQueue();
    }
  }

  /// Validates the finished temp file, then moves it into the downloads
  /// folder. Anything that does not look like real media is discarded
  /// (prompt §16).
  Future<void> _finalizeDownload(
    String uri,
    String tempPath,
    String filePath,
  ) async {
    _updateItem(
      uri,
      (i) => i.copyWith(status: DownloadStatus.processing, speed: 0),
    );
    final tempFile = File(tempPath);
    final validation = await FileTypeValidator.validate(tempFile);
    final tempExists = await tempFile.exists();
    final tempSize = tempExists ? await tempFile.length() : -1;
    _diag(
      '_finalizeDownload uri=${_shortUri(uri)} valid=${validation.isValid} '
      'detectedType=${validation.detectedType} error=${validation.error} '
      'tempExists=$tempExists tempSize=$tempSize',
    );
    if (!validation.isValid) {
      await _discardPartialFile(tempPath);
      _failExisting(
        uri,
        validation.error ?? 'The downloaded file was not valid media.',
        category: DownloaderErrorCategory.invalidFile,
      );
      return;
    }
    try {
      final target = File(filePath);
      if (await target.exists()) await target.delete();
      final renamed = await tempFile.rename(filePath);
      _diag('_finalizeDownload renamed -> ${renamed.path}');
      _completeDownload(uri, renamed.path);
    } catch (e) {
      _diag('_finalizeDownload rename FAILED uri=${_shortUri(uri)} error=$e');
      await _discardPartialFile(tempPath);
      _failExisting(
        uri,
        'Download failed. Please try again.',
        category: DownloaderErrorCategory.storage,
      );
    }
  }

  Future<void> _discardPartialFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup must not hide the original download result.
    }
  }

  bool _acceptProgress(String uri, int received, int total, CancelToken token) {
    final limit = _settings.maxFileSizeBytes;
    if ((total > 0 && total > limit) || received > limit) {
      _sizeLimitExceeded.add(uri);
      token.cancel('configured size limit exceeded');
      return false;
    }
    return true;
  }

  void _completeDownload(String uri, String filePath) {
    final file = File(filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    _updateItem(
      uri,
      (i) => i.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        bytesReceived: fileSize,
        totalBytes: fileSize,
        speed: 0,
        completedAt: DateTime.now(),
        clearError: true,
      ),
    );
    _logTerminal(
      DownloaderEvent.downloadCompleted,
      uri,
      sizeBytes: fileSize,
      status: 'completed',
    );
    // Legitimate review prompt after successful downloads (policy-safe throttle).
    unawaited(ReviewService.recordPositiveAction());
  }

  // ── Failure helpers ────────────────────────────────────────────────

  /// Creates (or refreshes) a failed history row for an error that was
  /// detected before the transfer started.
  void _failItem(
    String uri,
    String fileName,
    String? title,
    String message, {
    String? sourceUrl,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    DownloaderErrorCategory category = DownloaderErrorCategory.unknown,
  }) {
    _diag(
      '_failItem (pre-transfer) uri=${_shortUri(uri)} category=${category.name} '
      'message="$message"',
    );
    _ensureItemRow(
      uri,
      fileName,
      title,
      DownloadStatus.failed,
      error: message,
      sourceUrl: sourceUrl,
      format: format,
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
    );
    _updateItem(
      uri,
      (i) =>
          i.copyWith(status: DownloadStatus.failed, error: message, speed: 0),
    );
    _persistToDisk();
    _logTerminal(
      DownloaderEvent.downloadFailed,
      uri,
      status: 'failed',
      category: category,
    );
  }

  /// Marks an existing row as failed and logs it.
  void _failExisting(
    String uri,
    String message, {
    DownloaderErrorCategory category = DownloaderErrorCategory.unknown,
  }) {
    _diag(
      '_failExisting uri=${_shortUri(uri)} category=${category.name} '
      'message="$message"',
    );
    _updateItem(
      uri,
      (i) =>
          i.copyWith(status: DownloadStatus.failed, error: message, speed: 0),
    );
    _logTerminal(
      DownloaderEvent.downloadFailed,
      uri,
      status: 'failed',
      category: category,
    );
  }

  void _logProgress(String uri, int received, int total) {
    final item = state.findByUri(uri);
    if (item == null || total <= 0) return;
    DownloaderLogger.logProgress(item.id, (received * 100 ~/ total));
  }

  void _logTerminal(
    DownloaderEvent event,
    String uri, {
    String? status,
    int? sizeBytes,
    DownloaderErrorCategory? category,
  }) {
    final item = state.findByUri(uri);
    final started = _startTimes[uri];
    DownloaderLogger.log(
      event,
      jobId: item?.id,
      provider: 'public_media',
      domain: DownloaderLogger.domainOf(item?.sourceUrl ?? uri),
      status: status,
      duration: started == null ? null : DateTime.now().difference(started),
      sizeBytes:
          sizeBytes ?? (item?.isCompleted == true ? item!.bytesReceived : null),
      errorCategory: category,
    );
    if (event != DownloaderEvent.downloadProgress) {
      if (item != null) DownloaderLogger.forgetJob(item.id);
    }
  }

  void _ensureItemRow(
    String uri,
    String fileName,
    String? title,
    DownloadStatus status, {
    String? error,
    String? sourceUrl,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    int? durationMs,
    bool hasCaptions = false,
  }) {
    if (!state.items.any((i) => i.uri == uri)) {
      state = state.copyWith(
        items: [
          ...state.items,
          DownloadItem(
            uri: uri,
            fileName: fileName,
            title: title,
            status: status,
            error: error,
            createdAt: DateTime.now(),
            sourceUrl: sourceUrl,
            sourceDomain: Uri.tryParse(sourceUrl ?? uri)?.host,
            format: format,
            mediaType: mediaType,
            thumbnailUrl: thumbnailUrl,
            durationMs: durationMs,
            hasCaptions: hasCaptions,
          ),
        ],
      );
    }
  }

  void _drainQueue() {
    while (_queue.isNotEmpty &&
        _active.length + _starting.length < state.maxConcurrent) {
      final uri = _queue.removeAt(0);
      final item = state.findByUri(uri);
      unawaited(
        _launchDownload(
          uri: uri,
          fileName: item?.fileName ?? _nameFromUri(uri),
          title: item?.title,
          sourceUrl: item?.sourceUrl,
          format: item?.format,
          mediaType: item?.mediaType,
          thumbnailUrl: item?.thumbnailUrl,
          durationMs: item?.durationMs,
          hasCaptions: item?.hasCaptions ?? false,
        ),
      );
    }
  }

  Future<void> _launchDownload({
    required String uri,
    required String fileName,
    String? title,
    String? sourceUrl,
    String? format,
    String? mediaType,
    String? thumbnailUrl,
    int? durationMs,
    bool hasCaptions = false,
    bool skipUrlValidation = false,
  }) async {
    if (!_starting.add(uri)) return;
    try {
      await _startDownload(
        uri: uri,
        fileName: fileName,
        title: title,
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        durationMs: durationMs,
        hasCaptions: hasCaptions,
        skipUrlValidation: skipUrlValidation,
      );
    } catch (error) {
      debugPrint('[DownloadManager] Could not prepare download: $error');
      _ensureItemRow(
        uri,
        _sanitizeFileName(fileName),
        title,
        DownloadStatus.failed,
        error:
            'Could not prepare this download. Check the download folder and try again.',
        sourceUrl: sourceUrl,
        format: format,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );
      _updateItem(
        uri,
        (item) => item.copyWith(
          status: DownloadStatus.failed,
          error:
              'Could not prepare this download. Check the download folder and try again.',
          speed: 0,
        ),
      );
      _logTerminal(
        DownloaderEvent.downloadFailed,
        uri,
        status: 'failed',
        category: DownloaderErrorCategory.storage,
      );
      _persistToDisk();
    } finally {
      _starting.remove(uri);
      _drainQueue();
    }
  }

  String _nameFromUri(String uri) {
    final cleaned = uri.split('/').last;
    return cleaned.isNotEmpty
        ? cleaned
        : 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _updateItem(String uri, DownloadItem Function(DownloadItem) update) {
    state = state.copyWith(
      items: state.items.map((i) => i.uri == uri ? update(i) : i).toList(),
    );
  }

  /// Diagnostic tracing for the download pipeline. Every line is prefixed
  /// with `[DL-diag]` so it can be filtered in `flutter run` / `adb logcat`
  /// (e.g. `adb logcat | grep DL-diag`). These reveal the decision points and
  /// the otherwise-swallowed exceptions that decide whether a file downloads.
  void _diag(String message) => debugPrint('[DL-diag] $message');

  /// Truncates a URI for logging: keeps scheme+host and the first path
  /// segment so googlevideo URLs stay readable without dumping query tokens.
  String _shortUri(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null)
      return uri.length > 60 ? '${uri.substring(0, 60)}…' : uri;
    final firstSeg = parsed.pathSegments.isEmpty
        ? ''
        : '/${parsed.pathSegments.first}';
    return '${parsed.scheme}://${parsed.host}$firstSeg…';
  }

  Future<Directory> _getDownloadDirectory() async {
    final configuredPath = _settings.downloadPath;
    final Directory dir;
    if (configuredPath != null && configuredPath.isNotEmpty) {
      dir = Directory(configuredPath);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(appDir.path, AppConstants.appName));
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _ensureDownloadSubfolders(dir);
    return dir;
  }

  /// Makes sure the root downloads folder contains the Images / Videos /
  /// Musics subfolders that downloads are sorted into.
  Future<void> _ensureDownloadSubfolders(Directory root) async {
    for (final name in AppConstants.downloadSubfolders) {
      final sub = Directory(p.join(root.path, name));
      if (!await sub.exists()) {
        try {
          await sub.create(recursive: true);
        } catch (_) {
          // Folder cannot be created — downloads still land in the root.
        }
      }
    }
  }

  /// Subfolder a download belongs to, based on its media type (with a file
  /// extension fallback for rows saved before a media type was recorded).
  String _subfolderFor(String? mediaType, String fileName) {
    switch (mediaType) {
      case 'image':
        return AppConstants.imagesDownloadFolder;
      case 'audio':
        return AppConstants.musicsDownloadFolder;
      case 'video':
        return AppConstants.videosDownloadFolder;
    }
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
    }.contains(ext)) {
      return AppConstants.imagesDownloadFolder;
    }
    if (AppConstants.audioExtensions.contains(ext)) {
      return AppConstants.musicsDownloadFolder;
    }
    return AppConstants.videosDownloadFolder;
  }

  // ── HTTPS enforcement ─────────────────────────────────────────────────

  bool _isSecureUri(String uri) {
    final parsed = Uri.tryParse(uri);
    return parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        parsed.userInfo.isEmpty;
  }

  String _sanitizeFileName(String value) {
    final name = p
        .basename(value)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    return name.isEmpty
        ? 'download.bin'
        : name.substring(0, name.length.clamp(0, 120));
  }

  String _uniqueFileName(String value) {
    final name = _sanitizeFileName(value);
    final existing = state.items
        .map((item) => item.fileName.toLowerCase())
        .toSet();
    if (!existing.contains(name.toLowerCase())) return name;
    final extension = p.extension(name);
    final stem = p.basenameWithoutExtension(name);
    var suffix = 2;
    while (existing.contains('$stem ($suffix)$extension'.toLowerCase())) {
      suffix++;
    }
    return '$stem ($suffix)$extension';
  }

  // ── Disk space & storage quota checks ──────────────────────────────

  /// Returns a user-facing error message when the downloads folder cannot
  /// accept another [expectedBytes] bytes, or `null` when it is safe.
  Future<String?> _checkStorageCap(int expectedBytes) async {
    final cap = DownloaderLimits.maxStorageBytes;
    if (cap <= 0) return null;
    try {
      // The recursive scan already covers the nested temp folder, so adding
      // it again would double-count its bytes.
      final used = await _folderSize(await _getDownloadDirectory());
      if (used + expectedBytes > cap) {
        return 'Storage limit reached — remove old downloads to free space.';
      }
      return null;
    } catch (_) {
      return null; // If size cannot be computed, let the probe decide.
    }
  }

  Future<int> _folderSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // File may have been removed mid-scan.
        }
      }
    }
    return total;
  }

  Future<String?> _checkDiskSpaceError() async {
    try {
      final dir = await _getDownloadDirectory();
      // Write a 1-byte probe file to verify the directory is writable
      // and has space. If this fails, there's likely not enough space.
      final probe = File('${dir.path}/.space_probe');
      await probe.writeAsBytes([0]);
      await probe.delete();
      return null;
    } catch (_) {
      // Directory not writable or out of space.
      return 'Not enough disk space to complete this download.';
    }
  }

  // ── Temp file lifecycle (prompt §15) ───────────────────────────────

  Future<Directory> _getTempDirectory() async {
    final dir = await _getDownloadDirectory();
    final tempDir = Directory('${dir.path}/.tmp');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// Deletes temporary `.part` files older than the configured TTL and
  /// resets rows whose partial data expired. Runs on startup and every
  /// 15 minutes. Returns the number of files removed.
  Future<int> _cleanupExpiredFiles() async {
    var removed = 0;
    var freedBytes = 0;
    try {
      final tempDir = await _getTempDirectory();
      final ttl = _settings.tempTtl;
      final now = DateTime.now();
      final activeStems = <String>{};
      for (final item in state.items) {
        if (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.pending ||
            item.status == DownloadStatus.processing) {
          activeStems.add(_sanitizeFileName(item.fileName));
        }
      }
      await for (final entity in tempDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (now.difference(stat.modified) <= ttl) continue;
        final stem = p.basenameWithoutExtension(entity.path);
        if (activeStems.contains(stem)) continue; // transfer still running

        // A paused download whose partial data expired can no longer be
        // resumed safely — surface that instead of pretending.
        final pausedMatch = state.items.any(
          (i) =>
              i.isPaused &&
              p.basenameWithoutExtension(_sanitizeFileName(i.fileName)) == stem,
        );
        try {
          await entity.delete();
          removed++;
          freedBytes += stat.size;
        } catch (_) {
          continue;
        }
        if (pausedMatch) {
          final expired = state.items.firstWhere(
            (i) =>
                i.isPaused &&
                p.basenameWithoutExtension(_sanitizeFileName(i.fileName)) ==
                    stem,
          );
          _updateItem(
            expired.uri,
            (i) => i.copyWith(
              status: DownloadStatus.failed,
              error: 'The paused download expired. Retry to start over.',
              pausedBytesReceived: null,
              bytesReceived: 0,
              totalBytes: 0,
              progress: 0,
              speed: 0,
            ),
          );
          _persistToDisk();
        }
      }
    } catch (e) {
      debugPrint('[DownloadManager] Cleanup failed: $e');
    }
    if (removed > 0 || freedBytes > 0) {
      DownloaderLogger.log(
        DownloaderEvent.cleanupCompleted,
        status: 'removed=$removed',
        sizeBytes: freedBytes,
      );
    }
    return removed;
  }

  // ── Server probing & chunked transfer ─────────────────────────────────
  //
  // A single long-lived GET against throttling hosts (YouTube's googlevideo)
  // is served at roughly playback speed and effectively stalls — the progress
  // bar creeps a few KB and the file never finishes. Fetching in bounded
  // `Range` chunks is served at full speed, so every range-capable download
  // goes through [_downloadChunked] / [_downloadSegments]. Servers that do
  // not honour ranges fall back to [_downloadSingleStream].

  /// Bounded chunk size for range transfers (1 MiB).
  static const int _kChunkSize = 1024 * 1024;

  /// Parallel connections used when the "Fast Download" option is enabled.
  static const int _kFastConnections = 3;

  /// Confirms range support and reads the total size.
  ///
  /// A cheap HEAD is tried first, but many CDNs — YouTube's googlevideo in
  /// particular — answer HEAD (and plain, range-less GETs) with `403`/`405`
  /// while still serving `Range: bytes=0-0` GETs with `206`. So a HEAD failure
  /// must never abort the probe: we always fall through to the ranged-GET
  /// probe, which is the authoritative signal for those hosts. Getting this
  /// right is what routes googlevideo down the chunked path instead of the
  /// single-stream fallback that 403s.
  Future<({bool supportsRange, int total})> _probeServer(
    String uri, {
    required bool followRedirects,
  }) async {
    Options opts({Map<String, dynamic>? headers, ResponseType? type}) =>
        Options(
          followRedirects: followRedirects,
          maxRedirects: followRedirects ? 5 : 0,
          headers: headers,
          responseType: type,
          // Never throw on status: we inspect the code ourselves and fall
          // through to the ranged-GET probe when HEAD is rejected.
          validateStatus: (_) => true,
        );

    // 1) Cheap HEAD probe.
    try {
      final head = await _dio.head(uri, options: opts());
      final len =
          int.tryParse(
            head.headers.value(HttpHeaders.contentLengthHeader) ?? '',
          ) ??
          -1;
      final accept = (head.headers.value(HttpHeaders.acceptRangesHeader) ?? '')
          .toLowerCase();
      _diag(
        '_probeServer HEAD uri=${_shortUri(uri)} status=${head.statusCode} '
        'contentLength=$len acceptRanges="$accept"',
      );
      if (accept.contains('bytes') && len > 0) {
        return (supportsRange: true, total: len);
      }
    } catch (e) {
      _diag(
        '_probeServer HEAD failed uri=${_shortUri(uri)} ${e.runtimeType}: $e '
        '-> trying ranged GET',
      );
    }

    // 2) Ranged-GET probe: the reliable signal for hosts that reject HEAD.
    try {
      final probe = await _dio.get<List<int>>(
        uri,
        options: opts(
          headers: {HttpHeaders.rangeHeader: 'bytes=0-0'},
          type: ResponseType.bytes,
        ),
      );
      final contentRange = probe.headers.value(HttpHeaders.contentRangeHeader);
      final len =
          int.tryParse(
            probe.headers.value(HttpHeaders.contentLengthHeader) ?? '',
          ) ??
          -1;
      _diag(
        '_probeServer ranged-GET uri=${_shortUri(uri)} '
        'status=${probe.statusCode} contentRange="$contentRange" '
        'contentLength=$len',
      );
      if (probe.statusCode == 206) {
        final total = _contentRangeTotal(contentRange) ?? -1;
        return (supportsRange: true, total: total);
      }
      if (probe.statusCode == 200) {
        // Server ignored the Range header and returned the full body length;
        // it does not honour ranges, but we at least know the size.
        return (
          supportsRange: false,
          total: _contentRangeTotal(contentRange) ?? len,
        );
      }
      _diag(
        '_probeServer NO range support uri=${_shortUri(uri)} '
        'status=${probe.statusCode} -> single-stream fallback',
      );
      return (supportsRange: false, total: len);
    } catch (e) {
      _diag(
        '_probeServer ranged-GET EXCEPTION uri=${_shortUri(uri)} '
        '${e.runtimeType}: $e -> assuming no range support',
      );
      return (supportsRange: false, total: -1);
    }
  }

  int? _contentRangeTotal(String? header) {
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    if (slash < 0 || slash == header.length - 1) return null;
    return int.tryParse(header.substring(slash + 1).trim());
  }

  /// Fetches `[startByte, totalBytes)` in bounded chunks, appending to
  /// [tempPath]. Used for fresh single-connection downloads and for every
  /// resume (append order must be preserved).
  Future<void> _downloadChunked({
    required String uri,
    required String requestUri,
    required String tempPath,
    required CancelToken cancelToken,
    required int startByte,
    required int totalBytes,
    required bool followRedirects,
  }) async {
    // Fails fast when the (now known) total exceeds the configured ceiling;
    // the cancelled token makes the first chunk fetch throw.
    _acceptProgress(uri, startByte, totalBytes, cancelToken);
    final raf = await File(
      tempPath,
    ).open(mode: startByte > 0 ? FileMode.append : FileMode.write);
    var received = startByte;
    try {
      for (var start = startByte; start < totalBytes; start += _kChunkSize) {
        final end = math.min(start + _kChunkSize - 1, totalBytes - 1);
        final bytes = await _fetchChunk(
          requestUri,
          start,
          end,
          cancelToken,
          followRedirects,
          (delta) {
            received += delta;
            _reportProgress(uri, received, totalBytes, cancelToken);
          },
        );
        await raf.writeFrom(bytes);
      }
    } finally {
      await raf.close();
    }
    _diag(
      '_downloadChunked DONE uri=${_shortUri(uri)} received=$received/$totalBytes',
    );
  }

  /// Splits the file into [connections] contiguous segments downloaded in
  /// parallel (the "Fast Download / multiple connections" option). Each
  /// segment streams to its own part file; parts are concatenated in order at
  /// the end so no shared random-access write locking is needed.
  Future<void> _downloadSegments({
    required String uri,
    required String requestUri,
    required String tempPath,
    required CancelToken cancelToken,
    required int totalBytes,
    required int connections,
    required bool followRedirects,
  }) async {
    _acceptProgress(uri, 0, totalBytes, cancelToken);
    final segmentSize = (totalBytes / connections).ceil();
    final parts = <String>[];
    var received = 0;
    _diag(
      '_downloadSegments START uri=${_shortUri(uri)} connections=$connections '
      'segmentSize=$segmentSize totalBytes=$totalBytes',
    );
    try {
      final futures = <Future<void>>[];
      for (var i = 0; i < connections; i++) {
        final start = i * segmentSize;
        if (start >= totalBytes) break;
        final end = math.min(start + segmentSize - 1, totalBytes - 1);
        final partPath = '$tempPath.seg$i';
        parts.add(partPath);
        futures.add(
          _downloadSegment(
            requestUri: requestUri,
            partPath: partPath,
            start: start,
            end: end,
            cancelToken: cancelToken,
            followRedirects: followRedirects,
            onDelta: (delta) {
              received += delta;
              _reportProgress(uri, received, totalBytes, cancelToken);
            },
          ),
        );
      }
      await Future.wait(futures);

      final sink = File(tempPath).openWrite(mode: FileMode.write);
      try {
        for (final partPath in parts) {
          await sink.addStream(File(partPath).openRead());
        }
      } finally {
        await sink.close();
      }
      _diag(
        '_downloadSegments DONE uri=${_shortUri(uri)} received=$received/$totalBytes '
        'merged ${parts.length} parts',
      );
    } finally {
      for (final partPath in parts) {
        await _discardPartialFile(partPath);
      }
    }
  }

  Future<void> _downloadSegment({
    required String requestUri,
    required String partPath,
    required int start,
    required int end,
    required CancelToken cancelToken,
    required bool followRedirects,
    required void Function(int delta) onDelta,
  }) async {
    final raf = await File(partPath).open(mode: FileMode.write);
    try {
      for (var s = start; s <= end; s += _kChunkSize) {
        final e = math.min(s + _kChunkSize - 1, end);
        final bytes = await _fetchChunk(
          requestUri,
          s,
          e,
          cancelToken,
          followRedirects,
          onDelta,
        );
        await raf.writeFrom(bytes);
      }
    } finally {
      await raf.close();
    }
  }

  /// One bounded `Range: bytes=start-end` GET. Reports incremental byte
  /// counts through [onDelta] so the progress bar moves smoothly.
  Future<List<int>> _fetchChunk(
    String url,
    int start,
    int end,
    CancelToken token,
    bool followRedirects,
    void Function(int delta) onDelta,
  ) async {
    var last = 0;
    final response = await _dio.get<List<int>>(
      url,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {HttpHeaders.rangeHeader: 'bytes=$start-$end'},
        followRedirects: followRedirects,
        maxRedirects: followRedirects ? 5 : 0,
      ),
      onReceiveProgress: (r, _) {
        final delta = r - last;
        last = r;
        if (delta > 0) onDelta(delta);
      },
    );
    final status = response.statusCode ?? 0;
    final got = response.data?.length ?? 0;
    _diag(
      '_fetchChunk bytes=$start-$end status=$status received=$got '
      'host=${Uri.tryParse(url)?.host}',
    );
    if (status != 206 && status != 200) {
      _diag('_fetchChunk BAD STATUS $status for bytes=$start-$end -> throwing');
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unexpected status $status',
      );
    }
    return response.data ?? const <int>[];
  }

  void _reportProgress(String uri, int received, int total, CancelToken token) {
    if (!_acceptProgress(uri, received, total, token)) return;
    final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    _updateItem(
      uri,
      (i) => i.copyWith(
        progress: progress,
        bytesReceived: received,
        totalBytes: total > 0 ? total : i.totalBytes,
      ),
    );
    _logProgress(uri, received, total);
  }

  /// Single-stream transfer for servers without usable range support.
  Future<void> _downloadSingleStream({
    required String uri,
    required String requestUri,
    required String tempPath,
    required CancelToken cancelToken,
    required int resumeBytes,
    required bool supportsRange,
    required bool followRedirects,
  }) async {
    _diag(
      '_downloadSingleStream START uri=${_shortUri(uri)} resumeBytes=$resumeBytes '
      'supportsRange=$supportsRange followRedirects=$followRedirects',
    );
    final response = await _dio.download(
      requestUri,
      tempPath,
      cancelToken: cancelToken,
      options: Options(
        followRedirects: followRedirects,
        maxRedirects: followRedirects ? 5 : 0,
        headers: resumeBytes > 0 && supportsRange
            ? <String, String>{HttpHeaders.rangeHeader: 'bytes=$resumeBytes-'}
            : null,
      ),
      fileAccessMode: resumeBytes > 0
          ? FileAccessMode.append
          : FileAccessMode.write,
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        final currentTotal = resumeBytes > 0 ? resumeBytes + total : total;
        final currentReceived = resumeBytes > 0
            ? resumeBytes + received
            : received;
        if (!_acceptProgress(uri, currentReceived, currentTotal, cancelToken)) {
          return;
        }
        final progress = currentTotal > 0
            ? currentReceived / currentTotal
            : 0.0;
        _updateItem(
          uri,
          (i) => i.copyWith(
            progress: progress.clamp(0.0, 1.0),
            bytesReceived: currentReceived,
            totalBytes: currentTotal,
          ),
        );
        _logProgress(uri, currentReceived, currentTotal);
      },
    );
    final status = response.statusCode ?? 0;
    if (status != 200 && status != 206) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Unexpected status $status',
      );
    }
  }

  // ── Speed tracking ────────────────────────────────────────────────────

  void _startSpeedTracker() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final uri in _active) {
        _updateSpeedForUri(uri);
      }
    });
  }

  void _updateSpeedForUri(String uri) {
    final item = state.findByUri(uri);
    if (item == null || !item.isActive) return;

    final now = DateTime.now();
    final samples = _speedSamples.putIfAbsent(uri, () => []);
    samples.add(
      _SpeedSample(bytesReceived: item.bytesReceived, timestamp: now),
    );

    // Keep only samples from the last 3 seconds.
    final cutoff = now.subtract(const Duration(seconds: 3));
    samples.removeWhere((s) => s.timestamp.isBefore(cutoff));

    if (samples.length < 2) return;

    final oldest = samples.first;
    final newest = samples.last;
    final dt = newest.timestamp.difference(oldest.timestamp).inMilliseconds;
    if (dt <= 0) return;

    final speed = (newest.bytesReceived - oldest.bytesReceived) * 1000.0 / dt;
    _updateItem(uri, (i) => i.copyWith(speed: speed));
  }

  void _clearSpeedSamples(String uri) {
    _speedSamples.remove(uri);
  }

  // ── Persistence ───────────────────────────────────────────────────────

  Future<void> _persistToDisk() async {
    try {
      final dir = await _getApplicationDataDirectory();
      final file = File('${dir.path}/download_state.json');
      final data = state.items.map((i) => i.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[DownloadManager] Failed to persist state: $e');
    }
  }

  Future<void> _restoreFromDisk() async {
    try {
      final dir = await _getApplicationDataDirectory();
      final file = File('${dir.path}/download_state.json');
      if (!await file.exists()) return;

      final json = jsonDecode(await file.readAsString()) as List;
      final items = json
          .map((e) => DownloadItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Restore unfinished transfers and resume paused items when enabled.
      final restored = items.map((i) {
        if (i.status == DownloadStatus.downloading ||
            i.status == DownloadStatus.pending ||
            i.status == DownloadStatus.processing ||
            (i.isPaused && _settings.autoResume)) {
          return i.copyWith(status: DownloadStatus.pending, speed: 0);
        }
        return i.copyWith(speed: 0);
      }).toList();

      state = state.copyWith(items: restored);

      // Re-queue pending items.
      for (final item in restored) {
        if (item.status == DownloadStatus.pending) {
          _queue.add(item.uri);
        }
      }
      _drainQueue();
    } catch (e) {
      debugPrint('[DownloadManager] Failed to restore state: $e');
    }
  }

  Future<Directory> _getApplicationDataDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${appDir.path}/download_data');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }
}

// ── Speed sample helper ──────────────────────────────────────────────────

class _SpeedSample {
  final int bytesReceived;
  final DateTime timestamp;

  _SpeedSample({required this.bytesReceived, required this.timestamp});
}

// ── Provider ───────────────────────────────────────────────────────────────

final downloadManagerProvider =
    NotifierProvider<DownloadManager, DownloadManagerState>(
      DownloadManager.new,
    );
