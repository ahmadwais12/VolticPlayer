/// Compile-time limits for the video & audio downloader.
///
/// Every value can be overridden when building the app with `--dart-define`,
/// e.g.:
///
/// ```sh
/// flutter build apk \
///   --dart-define=DOWNLOADER_MAX_CONCURRENT=6 \
///   --dart-define=DOWNLOADER_ANALYZE_RATE_LIMIT=10 \
///   --dart-define=DOWNLOADER_DOWNLOAD_RATE_LIMIT=5 \
///   --dart-define=DOWNLOADER_MAX_FILE_SIZE=524288000 \
///   --dart-define=DOWNLOADER_MAX_DURATION=3600 \
///   --dart-define=DOWNLOADER_TEMP_FILE_TTL=1800 \
///   --dart-define=DOWNLOADER_MAX_STORAGE=5368709120
/// ```
///
/// Matching keys also live in `.env` for documentation / tooling. Runtime
/// (admin) settings in `DownloaderSettings` may lower these values but can
/// never raise them above the build-time ceilings defined here.
class DownloaderLimits {
  DownloaderLimits._();

  /// Maximum number of simultaneous transfers (global, single-user app).
  static const maxConcurrent = int.fromEnvironment(
    'DOWNLOADER_MAX_CONCURRENT',
    defaultValue: 6,
  );

  /// Hard ceiling for a single downloaded file, in bytes (500 MB).
  static const maxFileSizeBytes = int.fromEnvironment(
    'DOWNLOADER_MAX_FILE_SIZE',
    defaultValue: 524288000,
  );

  /// Maximum accepted media duration for analysis, in seconds.
  static const maxDurationSeconds = int.fromEnvironment(
    'DOWNLOADER_MAX_DURATION',
    defaultValue: 3600,
  );

  /// Analyze (URL inspection) requests allowed per minute.
  static const analyzeRateLimit = int.fromEnvironment(
    'DOWNLOADER_ANALYZE_RATE_LIMIT',
    defaultValue: 10,
  );

  /// Download requests allowed per minute.
  static const downloadRateLimit = int.fromEnvironment(
    'DOWNLOADER_DOWNLOAD_RATE_LIMIT',
    defaultValue: 5,
  );

  /// Lifetime of an unfinished temporary download file, in seconds
  /// (30 minutes). Expired files are removed by the cleanup job.
  static const tempFileTtlSeconds = int.fromEnvironment(
    'DOWNLOADER_TEMP_FILE_TTL',
    defaultValue: 1800,
  );

  /// Total storage the downloads folder may occupy, in bytes (5 GB).
  /// `0` disables the cap.
  static const maxStorageBytes = int.fromEnvironment(
    'DOWNLOADER_MAX_STORAGE',
    defaultValue: 5368709120,
  );
}
