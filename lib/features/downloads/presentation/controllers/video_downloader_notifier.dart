import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/services/downloader_limits.dart';
import '../../../../core/services/downloader_logger.dart';
import '../../../../core/services/downloader_rate_limiter.dart';
import '../../../../core/services/downloader_settings.dart';
import '../../../../core/services/video_downloader_service.dart';

// ── Downloader flow state ───────────────────────────────────────────────────

enum DownloaderPhase {
  idle, // waiting for URL input
  resolving, // fetching metadata from URL
  resolved, // metadata ready, user picks format
  downloading, // download in progress
  completed, // download finished
  error, // something went wrong
}

class VideoDownloaderState {
  final DownloaderPhase phase;
  final String url;
  final MediaMetadata? metadata;
  final MediaFormat? selectedFormat;
  final double progress;
  final int bytesReceived;
  final int totalBytes;
  final double speed;
  final String? error;
  final String? savedPath;
  final List<String> recentUrls;

  const VideoDownloaderState({
    this.phase = DownloaderPhase.idle,
    this.url = '',
    this.metadata,
    this.selectedFormat,
    this.progress = 0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.speed = 0,
    this.error,
    this.savedPath,
    this.recentUrls = const [],
  });

  VideoDownloaderState copyWith({
    DownloaderPhase? phase,
    String? url,
    MediaMetadata? metadata,
    MediaFormat? selectedFormat,
    double? progress,
    int? bytesReceived,
    int? totalBytes,
    double? speed,
    String? error,
    String? savedPath,
    List<String>? recentUrls,
    bool clearError = false,
    bool clearMetadata = false,
    bool clearSelectedFormat = false,
    bool clearSavedPath = false,
  }) => VideoDownloaderState(
    phase: phase ?? this.phase,
    url: url ?? this.url,
    metadata: clearMetadata ? null : (metadata ?? this.metadata),
    selectedFormat: clearSelectedFormat
        ? null
        : (selectedFormat ?? this.selectedFormat),
    progress: progress ?? this.progress,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    totalBytes: totalBytes ?? this.totalBytes,
    speed: speed ?? this.speed,
    error: clearError ? null : (error ?? this.error),
    savedPath: clearSavedPath ? null : (savedPath ?? this.savedPath),
    recentUrls: recentUrls ?? this.recentUrls,
  );
}

// ── Notifier ────────────────────────────────────────────────────────────────

class VideoDownloaderNotifier extends Notifier<VideoDownloaderState> {
  late final VideoDownloaderService _service;

  /// Analyze requests are limited to DOWNLOADER_ANALYZE_RATE_LIMIT per
  /// minute (prompt §14).
  late final SlidingWindowRateLimiter _analyzeLimiter;

  CancelToken? _cancelToken;
  String? _activeDownloadUrl;

  @override
  VideoDownloaderState build() {
    _service = VideoDownloaderService();
    _analyzeLimiter = SlidingWindowRateLimiter(
      limit: DownloaderLimits.analyzeRateLimit,
    );
    ref.onDispose(() {
      _cancelToken?.cancel();
      _service.dispose();
    });
    return const VideoDownloaderState();
  }

  /// Paste URL from clipboard and auto-resolve.
  Future<void> setUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final settings = ref.read(downloaderSettingsValueProvider);
    if (!settings.enabled) {
      state = state.copyWith(
        error: 'The downloader is disabled in settings.',
        phase: DownloaderPhase.error,
      );
      return;
    }
    if (!_analyzeLimiter.allow()) {
      state = state.copyWith(
        error: 'Too many analyze requests. Please wait a moment and try again.',
        phase: DownloaderPhase.error,
      );
      return;
    }

    // Basic URL validity check (must be a valid URL with a host).
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      state = state.copyWith(
        error: 'Invalid URL — please enter a valid web address.',
        phase: DownloaderPhase.error,
      );
      return;
    }

    // Enforce HTTPS for security.
    if (uri.scheme.toLowerCase() != 'https') {
      state = state.copyWith(
        error: 'Only HTTPS URLs are supported for secure downloads.',
        phase: DownloaderPhase.error,
      );
      return;
    }

    state = state.copyWith(
      url: trimmed,
      phase: DownloaderPhase.resolving,
      clearError: true,
      clearMetadata: true,
      clearSelectedFormat: true,
      clearSavedPath: true,
    );

    final startedAt = DateTime.now();
    DownloaderLogger.log(
      DownloaderEvent.analysisStarted,
      provider: 'public_media',
      domain: DownloaderLogger.domainOf(trimmed),
      status: 'started',
    );

    try {
      final metadata = await _service.resolveFromUrl(trimmed);

      if (metadata.duration != null &&
          metadata.duration!.inSeconds > DownloaderLimits.maxDurationSeconds) {
        state = state.copyWith(
          metadata: metadata,
          phase: DownloaderPhase.error,
          error: 'This media exceeds the configured duration limit.',
        );
        DownloaderLogger.log(
          DownloaderEvent.analysisFailed,
          provider: 'public_media',
          domain: DownloaderLogger.domainOf(trimmed),
          duration: DateTime.now().difference(startedAt),
          errorCategory: DownloaderErrorCategory.tooLong,
        );
        return;
      }

      // Add to recent URLs
      final recent = [
        trimmed,
        ...state.recentUrls.where((u) => u != trimmed),
      ].take(10).toList();

      if (metadata.formats.isEmpty) {
        state = state.copyWith(
          metadata: metadata,
          phase: DownloaderPhase.error,
          error:
              'No downloadable formats — this source did not provide a compatible downloadable format.',
          recentUrls: recent,
        );
        DownloaderLogger.log(
          DownloaderEvent.analysisFailed,
          provider: 'public_media',
          domain: DownloaderLogger.domainOf(trimmed),
          duration: DateTime.now().difference(startedAt),
          errorCategory: DownloaderErrorCategory.unsupportedUrl,
        );
      } else {
        final preferredFormat = _preferredFormat(
          metadata.formats,
          ref.read(downloaderSettingsValueProvider).musicQuality,
        );
        state = state.copyWith(
          metadata: metadata,
          selectedFormat: preferredFormat,
          phase: DownloaderPhase.resolved,
          recentUrls: recent,
        );
        DownloaderLogger.log(
          DownloaderEvent.analysisCompleted,
          provider: 'public_media',
          domain: DownloaderLogger.domainOf(trimmed),
          duration: DateTime.now().difference(startedAt),
          status: 'formats=${metadata.formats.length}',
        );
      }
    } catch (e) {
      final unsupported = e is FormatException;
      state = state.copyWith(
        phase: DownloaderPhase.error,
        error: unsupported
            ? 'Unsupported URL — this source is not currently supported.'
            : 'Unable to analyze — the media could not be analyzed. Please verify the URL and try again.',
      );
      DownloaderLogger.log(
        unsupported
            ? DownloaderEvent.analysisFailed
            : DownloaderEvent.providerError,
        provider: 'public_media',
        domain: DownloaderLogger.domainOf(trimmed),
        duration: DateTime.now().difference(startedAt),
        errorCategory: unsupported
            ? DownloaderErrorCategory.unsupportedUrl
            : DownloaderErrorCategory.network,
      );
    }
  }

  MediaFormat _preferredFormat(List<MediaFormat> formats, String quality) {
    final audioFormats = formats.where((format) => format.isAudioOnly).toList();
    if (audioFormats.isEmpty) return formats.first;
    int bitrate(MediaFormat format) {
      final value = '${format.quality ?? ''} ${format.label}';
      final match = RegExp(
        r'(\d+)\s*k',
        caseSensitive: false,
      ).firstMatch(value);
      return int.tryParse(match?.group(1) ?? '') ?? 0;
    }

    audioFormats.sort((a, b) => bitrate(a).compareTo(bitrate(b)));
    switch (quality.toLowerCase()) {
      case 'low':
        return audioFormats.first;
      case 'high':
        return audioFormats.last;
      default:
        return audioFormats[audioFormats.length ~/ 2];
    }
  }

  /// Select a different format.
  void selectFormat(MediaFormat format) {
    state = state.copyWith(selectedFormat: format);
  }

  /// Start downloading the selected format.
  Future<void> startDownload() async {
    if (state.metadata == null || state.selectedFormat == null) {
      debugPrint(
        '[DL-diag] startDownload aborted: metadata=${state.metadata != null} '
        'selectedFormat=${state.selectedFormat != null}',
      );
      return;
    }

    final downloadUrl = state.selectedFormat!.url ?? state.url;
    final metadata = state.metadata!;
    final format = state.selectedFormat!;
    final settings = ref.read(downloaderSettingsValueProvider);
    debugPrint(
      '[DL-diag] startDownload label="${format.label}" '
      'isAudioOnly=${format.isAudioOnly} fileSize=${format.fileSize} '
      'url=${_shortUrl(downloadUrl)}',
    );

    if (!settings.enabled) {
      debugPrint('[DL-diag] startDownload blocked: downloader disabled');
      state = state.copyWith(
        phase: DownloaderPhase.error,
        error: 'The downloader is disabled in settings.',
      );
      return;
    }
    if (format.isAudioOnly && !settings.audioEnabled) {
      debugPrint('[DL-diag] startDownload blocked: audio disabled');
      state = state.copyWith(
        phase: DownloaderPhase.error,
        error: 'Audio downloads are disabled in settings.',
      );
      return;
    }
    if (!format.isAudioOnly && !settings.videoEnabled) {
      debugPrint('[DL-diag] startDownload blocked: video disabled');
      state = state.copyWith(
        phase: DownloaderPhase.error,
        error: 'Video downloads are disabled in settings.',
      );
      return;
    }
    if (format.fileSize != null &&
        format.fileSize! > settings.maxFileSizeBytes) {
      debugPrint(
        '[DL-diag] startDownload blocked: too large ${format.fileSize} '
        '> ${settings.maxFileSizeBytes}',
      );
      state = state.copyWith(
        phase: DownloaderPhase.error,
        error:
            'File too large — this file exceeds the maximum allowed download size.',
      );
      return;
    }

    // Generate file name
    final ext = _getExtension(downloadUrl, state.selectedFormat!);
    final safeName = _sanitizeFileName(metadata.title);
    final fileName = '$safeName.$ext';
    _activeDownloadUrl = downloadUrl;
    debugPrint(
      '[DL-diag] startDownload dispatching to DownloadManager fileName="$fileName"',
    );

    state = state.copyWith(
      phase: DownloaderPhase.downloading,
      progress: 0,
      clearError: true,
    );

    // Use the existing DownloadManager
    final dlNotifier = ref.read(downloadManagerProvider.notifier);
    final downloadTask = dlNotifier.download(
      uri: downloadUrl,
      fileName: fileName,
      title: metadata.title,
      sourceUrl: metadata.sourceUrl ?? state.url,
      format: state.selectedFormat!.label,
      mediaType: state.selectedFormat!.isAudioOnly ? 'audio' : 'video',
      thumbnailUrl: metadata.thumbnailUrl,
      durationMs: metadata.duration?.inMilliseconds,
      hasCaptions: state.selectedFormat!.label.toLowerCase().contains('cc') ||
          state.selectedFormat!.label.toLowerCase().contains('subtitle'),
      expectedBytes: state.selectedFormat!.fileSize,
      skipUrlValidation: true,
    );

    // Listen for completion via polling (since DownloadManager manages state)
    _cancelToken = CancelToken();

    // Start tracking progress
    _trackDownloadProgress(downloadUrl);
    unawaited(downloadTask);
  }

  /// Track download progress by polling the DownloadManager.
  void _trackDownloadProgress(String downloadUrl) async {
    var polls = 0;
    DownloadStatus? lastStatus;
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      if (_cancelToken == null || _cancelToken!.isCancelled) return;
      polls++;

      final dlState = ref.read(downloadManagerProvider);
      final item = dlState.findByUri(downloadUrl);

      if (item == null) {
        // The manager has no row for this URI. Log the first few polls so a
        // URI mismatch (item tracked under a different key) is visible instead
        // of silently spinning forever.
        if (polls <= 5) {
          debugPrint(
            '[DL-diag] track poll#$polls: NO item for uri=${_shortUrl(downloadUrl)} '
            '(manager has ${dlState.items.length} items: '
            '${dlState.items.map((i) => _shortUrl(i.uri)).join(', ')})',
          );
        }
        continue;
      }

      if (item.status != lastStatus) {
        debugPrint(
          '[DL-diag] track poll#$polls: status ${lastStatus?.name} -> '
          '${item.status.name} progress=${(item.progress * 100).round()}% '
          'bytes=${item.bytesReceived}/${item.totalBytes} error=${item.error}',
        );
        lastStatus = item.status;
      }

      if (item.isCompleted) {
        debugPrint('[DL-diag] track: COMPLETED path=${item.filePath}');
        state = state.copyWith(
          phase: DownloaderPhase.completed,
          progress: 1.0,
          savedPath: item.filePath,
          bytesReceived: item.totalBytes,
          totalBytes: item.totalBytes,
          speed: 0,
        );
        return;
      }

      if (item.status == DownloadStatus.failed) {
        debugPrint('[DL-diag] track: FAILED error=${item.error}');
        state = state.copyWith(
          phase: DownloaderPhase.error,
          error: item.error ?? 'Download failed',
        );
        return;
      }

      if (item.status == DownloadStatus.cancelled) {
        debugPrint('[DL-diag] track: CANCELLED');
        state = state.copyWith(
          phase: DownloaderPhase.idle,
          progress: 0,
          speed: 0,
        );
        return;
      }

      if (item.status == DownloadStatus.paused) {
        // Stay in downloading phase but show paused state externally.
        state = state.copyWith(
          progress: item.progress,
          bytesReceived: item.bytesReceived,
          totalBytes: item.totalBytes,
          speed: item.speed,
        );
        continue; // Keep polling until resumed or cancelled.
      }

      // Update progress
      state = state.copyWith(
        progress: item.progress,
        bytesReceived: item.bytesReceived,
        totalBytes: item.totalBytes,
        speed: item.speed,
      );
    }
  }

  /// Cancel the current download.
  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _activeDownloadUrl = null;
    if ((state.phase == DownloaderPhase.downloading ||
            state.phase == DownloaderPhase.resolved) &&
        state.url.isNotEmpty) {
      ref
          .read(downloadManagerProvider.notifier)
          .cancel(_activeDownloadUrl ?? state.selectedFormat?.url ?? state.url);
    }
    state = state.copyWith(phase: DownloaderPhase.idle, progress: 0, speed: 0);
  }

  /// Pause the current download.
  void pauseDownload() {
    if (state.phase == DownloaderPhase.downloading && state.url.isNotEmpty) {
      ref
          .read(downloadManagerProvider.notifier)
          .pause(_activeDownloadUrl ?? state.selectedFormat?.url ?? state.url);
    }
  }

  /// Resume a paused download.
  void resumeDownload() {
    if (state.url.isNotEmpty) {
      final url = _activeDownloadUrl ?? state.selectedFormat?.url ?? state.url;
      ref.read(downloadManagerProvider.notifier).resume(url);
      // Restart tracking.
      _cancelToken = CancelToken();
      _trackDownloadProgress(url);
    }
  }

  /// Reset to idle state.
  void reset() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = VideoDownloaderState(recentUrls: state.recentUrls);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Truncates a URL for diagnostic logs (scheme+host+first path segment),
  /// so googlevideo query tokens are never dumped to the console.
  String _shortUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) {
      return url.length > 60 ? '${url.substring(0, 60)}…' : url;
    }
    final firstSeg =
        parsed.pathSegments.isEmpty ? '' : '/${parsed.pathSegments.first}';
    return '${parsed.scheme}://${parsed.host}$firstSeg…';
  }

  String _getExtension(String url, MediaFormat format) {
    // Try to get extension from URL
    try {
      final uri = Uri.parse(url);
      final pathExt = p.extension(uri.path).replaceFirst('.', '').toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(pathExt)) return pathExt;
    } catch (_) {}

    // Guess from format label
    final label = format.label.toLowerCase();
    if (label.contains('mp3')) return 'mp3';
    if (label.contains('flac')) return 'flac';
    if (label.contains('aac')) return 'aac';
    if (label.contains('ogg')) return 'ogg';
    if (label.contains('wav')) return 'wav';
    if (format.isAudioOnly) return 'mp3';
    return 'mp4';
  }

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    return sanitized.isEmpty
        ? 'media'
        : sanitized.substring(0, sanitized.length.clamp(0, 100));
  }
}

final videoDownloaderProvider =
    NotifierProvider<VideoDownloaderNotifier, VideoDownloaderState>(
      VideoDownloaderNotifier.new,
    );
