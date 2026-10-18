import 'package:flutter/foundation.dart';

/// Structured downloader logging (prompt §26).
///
/// Emits one-line `key=value` events that are easy to grep and machine
/// parse. Privacy rules enforced here:
///
/// * never log full URLs — only the registrable host (domain);
/// * never log credentials, cookies, tokens or personal data;
/// * `download_progress` is throttled to 10% steps to keep logs small.
enum DownloaderEvent {
  analysisStarted,
  analysisCompleted,
  analysisFailed,
  downloadStarted,
  downloadProgress,
  downloadCompleted,
  downloadFailed,
  downloadCancelled,
  cleanupCompleted,
  providerError,
}

/// Stable, non-sensitive error categories used for monitoring.
enum DownloaderErrorCategory {
  unsupportedUrl,
  network,
  timeout,
  tooLarge,
  tooLong,
  storage,
  rateLimited,
  invalidFile,
  permission,
  cancelled,
  unknown,
}

class DownloaderLogger {
  DownloaderLogger._();

  static const String _tag = '[Downloader]';

  /// Last logged progress bucket per job, so progress logs fire only when
  /// the download crosses a 10% boundary.
  static final Map<String, int> _progressBuckets = {};

  static void log(
    DownloaderEvent event, {
    String? jobId,
    String? userId,
    String? provider,
    String? domain,
    String? status,
    Duration? duration,
    int? sizeBytes,
    int? progressPercent,
    DownloaderErrorCategory? errorCategory,
  }) {
    final parts = <String>[
      _tag,
      'event=${_eventName(event)}',
      if (jobId != null) 'job=$jobId',
      if (userId != null) 'user=$userId',
      if (provider != null) 'provider=$provider',
      if (domain != null) 'domain=$domain',
      if (status != null) 'status=$status',
      if (duration != null) 'duration_ms=${duration.inMilliseconds}',
      if (sizeBytes != null) 'size_bytes=$sizeBytes',
      if (progressPercent != null) 'progress=$progressPercent',
      if (errorCategory != null) 'error_category=${errorCategory.name}',
    ];
    debugPrint(parts.join(' '));
  }

  /// Logs progress only when the download crossed a new 10% bucket.
  static void logProgress(String jobId, int percent) {
    final bucket = (percent.clamp(0, 100) ~/ 10) * 10;
    if (_progressBuckets[jobId] == bucket) return;
    _progressBuckets[jobId] = bucket;
    log(
      DownloaderEvent.downloadProgress,
      jobId: jobId,
      progressPercent: bucket,
      status: 'downloading',
    );
  }

  static void forgetJob(String jobId) => _progressBuckets.remove(jobId);

  /// Extracts the host from a URL without logging the path, query or
  /// credentials. Returns null when the URL cannot be parsed.
  static String? domainOf(String? url) {
    if (url == null || url.isEmpty) return null;
    final host = Uri.tryParse(url)?.host;
    return (host == null || host.isEmpty) ? null : host;
  }

  static String _eventName(DownloaderEvent event) => switch (event) {
    DownloaderEvent.analysisStarted => 'analysis_started',
    DownloaderEvent.analysisCompleted => 'analysis_completed',
    DownloaderEvent.analysisFailed => 'analysis_failed',
    DownloaderEvent.downloadStarted => 'download_started',
    DownloaderEvent.downloadProgress => 'download_progress',
    DownloaderEvent.downloadCompleted => 'download_completed',
    DownloaderEvent.downloadFailed => 'download_failed',
    DownloaderEvent.downloadCancelled => 'download_cancelled',
    DownloaderEvent.cleanupCompleted => 'cleanup_completed',
    DownloaderEvent.providerError => 'provider_error',
  };
}
