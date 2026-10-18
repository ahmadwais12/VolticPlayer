import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import 'downloader_limits.dart';

/// Runtime admin controls for the downloader (prompt §25).
///
/// Values are persisted in the existing Drift key/value `settings` table and
/// are always clamped to the build-time ceilings in [DownloaderLimits] — an
/// admin can lower a limit but can never raise it above the compiled one.
class DownloaderSettings {
  const DownloaderSettings({
    this.enabled = true,
    this.videoEnabled = true,
    this.audioEnabled = true,
    this.wifiOnly = false,
    this.autoResume = true,
    this.clipboardDetection = true,
    this.showHiddenFiles = false,
    this.downloadPath,
    this.musicQuality = 'Medium',
    this.downloadSubtitle = 'System Language',
    this.fastDownload = false,
    this.notifyOnComplete = false,
    this.deleteApkAfterInstall = true,
    this.smartMuxer = true,
    this.maxFileSizeBytes = DownloaderLimits.maxFileSizeBytes,
    this.maxConcurrent = 2,
    this.tempTtlMinutes = DownloaderLimits.tempFileTtlSeconds ~/ 60,
  });

  final bool enabled;
  final bool videoEnabled;
  final bool audioEnabled;
  final bool wifiOnly;
  final bool autoResume;
  final bool clipboardDetection;
  final bool showHiddenFiles;
  final String? downloadPath;
  final String musicQuality;
  final String downloadSubtitle;
  final bool fastDownload;
  final bool notifyOnComplete;
  final bool deleteApkAfterInstall;
  final bool smartMuxer;
  final int maxFileSizeBytes;
  final int maxConcurrent;
  final int tempTtlMinutes;

  DownloaderSettings copyWith({
    bool? enabled,
    bool? videoEnabled,
    bool? audioEnabled,
    bool? wifiOnly,
    bool? autoResume,
    bool? clipboardDetection,
    bool? showHiddenFiles,
    String? downloadPath,
    String? musicQuality,
    String? downloadSubtitle,
    bool? fastDownload,
    bool? notifyOnComplete,
    bool? deleteApkAfterInstall,
    bool? smartMuxer,
    int? maxFileSizeBytes,
    int? maxConcurrent,
    int? tempTtlMinutes,
  }) => DownloaderSettings(
    enabled: enabled ?? this.enabled,
    videoEnabled: videoEnabled ?? this.videoEnabled,
    audioEnabled: audioEnabled ?? this.audioEnabled,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    autoResume: autoResume ?? this.autoResume,
    clipboardDetection: clipboardDetection ?? this.clipboardDetection,
    showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
    downloadPath: downloadPath ?? this.downloadPath,
    musicQuality: musicQuality ?? this.musicQuality,
    downloadSubtitle: downloadSubtitle ?? this.downloadSubtitle,
    fastDownload: fastDownload ?? this.fastDownload,
    notifyOnComplete: notifyOnComplete ?? this.notifyOnComplete,
    deleteApkAfterInstall:
        deleteApkAfterInstall ?? this.deleteApkAfterInstall,
    smartMuxer: smartMuxer ?? this.smartMuxer,
    maxFileSizeBytes: maxFileSizeBytes ?? this.maxFileSizeBytes,
    maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    tempTtlMinutes: tempTtlMinutes ?? this.tempTtlMinutes,
  );

  Duration get tempTtl => Duration(minutes: tempTtlMinutes);

  /// All values clamped to build-time ceilings.
  DownloaderSettings get normalized => copyWith(
    maxFileSizeBytes: maxFileSizeBytes.clamp(
      1,
      DownloaderLimits.maxFileSizeBytes,
    ),
    maxConcurrent: maxConcurrent.clamp(1, DownloaderLimits.maxConcurrent),
    tempTtlMinutes: tempTtlMinutes.clamp(1, 24 * 60),
  );
}

/// Persistence keys inside the existing `settings` table.
class DownloaderSettingsKeys {
  DownloaderSettingsKeys._();
  static const enabled = 'downloader_enabled';
  static const videoEnabled = 'downloader_video_enabled';
  static const audioEnabled = 'downloader_audio_enabled';
  static const wifiOnly = 'downloader_wifi_only';
  static const autoResume = 'downloader_auto_resume';
  static const clipboardDetection = 'downloader_clipboard_detection';
  static const showHiddenFiles = 'downloader_show_hidden_files';
  static const downloadPath = 'downloader_download_path';
  static const musicQuality = 'downloader_music_quality';
  static const downloadSubtitle = 'downloader_download_subtitle';
  static const fastDownload = 'downloader_fast_download';
  static const notifyOnComplete = 'downloader_notify_on_complete';
  static const deleteApkAfterInstall = 'downloader_delete_apk_after_install';
  static const smartMuxer = 'downloader_smart_muxer';
  static const maxFileSize = 'downloader_max_file_size';
  static const maxConcurrent = 'downloader_max_concurrent';
  static const tempTtlMinutes = 'downloader_temp_ttl_minutes';
}

/// Loads and persists the downloader admin settings.
class DownloaderSettingsController extends AsyncNotifier<DownloaderSettings> {
  @override
  Future<DownloaderSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    Future<bool> boolOf(String key) async =>
        await repo.getSetting<bool>(key, defaultValue: true) ?? true;
    Future<int> intOf(String key, int fallback) async =>
        await repo.getSetting<int>(key, defaultValue: fallback) ?? fallback;
    final downloadPath = await repo.getSetting<String>(
      DownloaderSettingsKeys.downloadPath,
      defaultValue: '',
    );

    return DownloaderSettings(
      enabled: await boolOf(DownloaderSettingsKeys.enabled),
      videoEnabled: await boolOf(DownloaderSettingsKeys.videoEnabled),
      audioEnabled: await boolOf(DownloaderSettingsKeys.audioEnabled),
      wifiOnly:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.wifiOnly,
            defaultValue: false,
          ) ??
          false,
      autoResume:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.autoResume,
            defaultValue: true,
          ) ??
          true,
      clipboardDetection:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.clipboardDetection,
            defaultValue: true,
          ) ??
          true,
      showHiddenFiles:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.showHiddenFiles,
            defaultValue: false,
          ) ??
          false,
      downloadPath: downloadPath == null || downloadPath.isEmpty
          ? null
          : downloadPath,
      musicQuality:
          await repo.getSetting<String>(
            DownloaderSettingsKeys.musicQuality,
            defaultValue: 'Medium',
          ) ??
          'Medium',
      downloadSubtitle:
          await repo.getSetting<String>(
            DownloaderSettingsKeys.downloadSubtitle,
            defaultValue: 'System Language',
          ) ??
          'System Language',
      fastDownload:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.fastDownload,
            defaultValue: false,
          ) ??
          false,
      notifyOnComplete:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.notifyOnComplete,
            defaultValue: false,
          ) ??
          false,
      deleteApkAfterInstall:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.deleteApkAfterInstall,
            defaultValue: true,
          ) ??
          true,
      smartMuxer:
          await repo.getSetting<bool>(
            DownloaderSettingsKeys.smartMuxer,
            defaultValue: true,
          ) ??
          true,
      maxFileSizeBytes: await intOf(
        DownloaderSettingsKeys.maxFileSize,
        DownloaderLimits.maxFileSizeBytes,
      ),
      maxConcurrent: await intOf(DownloaderSettingsKeys.maxConcurrent, 2),
      tempTtlMinutes: await intOf(
        DownloaderSettingsKeys.tempTtlMinutes,
        DownloaderLimits.tempFileTtlSeconds ~/ 60,
      ),
    ).normalized;
  }

  Future<void> _persist(String key, Object value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(key, value);
  }

  void _apply(DownloaderSettings next) {
    state = AsyncData(next.normalized);
  }

  Future<void> setEnabled(bool value) async {
    await _persist(DownloaderSettingsKeys.enabled, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(enabled: value),
    );
  }

  Future<void> setVideoEnabled(bool value) async {
    await _persist(DownloaderSettingsKeys.videoEnabled, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(videoEnabled: value),
    );
  }

  Future<void> setAudioEnabled(bool value) async {
    await _persist(DownloaderSettingsKeys.audioEnabled, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(audioEnabled: value),
    );
  }

  Future<void> setWifiOnly(bool value) async {
    await _persist(DownloaderSettingsKeys.wifiOnly, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(wifiOnly: value),
    );
  }

  Future<void> setAutoResume(bool value) async {
    await _persist(DownloaderSettingsKeys.autoResume, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(autoResume: value),
    );
  }

  Future<void> setClipboardDetection(bool value) async {
    await _persist(DownloaderSettingsKeys.clipboardDetection, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        clipboardDetection: value,
      ),
    );
  }

  Future<void> setShowHiddenFiles(bool value) async {
    await _persist(DownloaderSettingsKeys.showHiddenFiles, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        showHiddenFiles: value,
      ),
    );
  }

  Future<void> setDownloadPath(String value) async {
    await _persist(DownloaderSettingsKeys.downloadPath, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(downloadPath: value),
    );
  }

  Future<void> setMusicQuality(String value) async {
    await _persist(DownloaderSettingsKeys.musicQuality, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(musicQuality: value),
    );
  }

  Future<void> setDownloadSubtitle(String value) async {
    await _persist(DownloaderSettingsKeys.downloadSubtitle, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        downloadSubtitle: value,
      ),
    );
  }

  Future<void> setFastDownload(bool value) async {
    await _persist(DownloaderSettingsKeys.fastDownload, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(fastDownload: value),
    );
  }

  Future<void> setNotifyOnComplete(bool value) async {
    await _persist(DownloaderSettingsKeys.notifyOnComplete, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        notifyOnComplete: value,
      ),
    );
  }

  Future<void> setDeleteApkAfterInstall(bool value) async {
    await _persist(DownloaderSettingsKeys.deleteApkAfterInstall, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        deleteApkAfterInstall: value,
      ),
    );
  }

  Future<void> setSmartMuxer(bool value) async {
    await _persist(DownloaderSettingsKeys.smartMuxer, value);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(smartMuxer: value),
    );
  }

  Future<void> setMaxFileSize(int bytes) async {
    final clamped = bytes.clamp(1, DownloaderLimits.maxFileSizeBytes);
    await _persist(DownloaderSettingsKeys.maxFileSize, clamped);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        maxFileSizeBytes: clamped,
      ),
    );
  }

  Future<void> setMaxConcurrent(int value) async {
    final clamped = value.clamp(1, DownloaderLimits.maxConcurrent);
    await _persist(DownloaderSettingsKeys.maxConcurrent, clamped);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        maxConcurrent: clamped,
      ),
    );
  }

  Future<void> setTempTtlMinutes(int minutes) async {
    final clamped = minutes.clamp(1, 24 * 60);
    await _persist(DownloaderSettingsKeys.tempTtlMinutes, clamped);
    _apply(
      (state.value ?? const DownloaderSettings()).copyWith(
        tempTtlMinutes: clamped,
      ),
    );
  }
}

final downloaderSettingsProvider =
    AsyncNotifierProvider<DownloaderSettingsController, DownloaderSettings>(
      DownloaderSettingsController.new,
    );

/// Synchronous accessor: while settings are loading (or on error) the
/// build-time defaults are used, so hot paths never have to await.
final downloaderSettingsValueProvider = Provider<DownloaderSettings>((ref) {
  return ref.watch(downloaderSettingsProvider).value ??
      const DownloaderSettings();
});
