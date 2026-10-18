import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/downloader_limits.dart';
import 'package:voltic_player/core/services/downloader_settings.dart';

void main() {
  group('DownloaderSettings (§25 admin controls)', () {
    test('defaults match the build-time limits', () {
      const settings = DownloaderSettings();
      expect(settings.enabled, isTrue);
      expect(settings.videoEnabled, isTrue);
      expect(settings.audioEnabled, isTrue);
      expect(settings.maxFileSizeBytes, DownloaderLimits.maxFileSizeBytes);
      // Startup default is 2 parallel downloads, capped by the build limit.
      expect(settings.maxConcurrent, 2);
      expect(
        settings.maxConcurrent,
        lessThanOrEqualTo(DownloaderLimits.maxConcurrent),
      );
      expect(
        settings.tempTtlMinutes,
        DownloaderLimits.tempFileTtlSeconds ~/ 60,
      );
    });

    test('copyWith overrides only the requested fields', () {
      const settings = DownloaderSettings();
      final changed = settings.copyWith(
        enabled: false,
        videoEnabled: false,
        maxConcurrent: 1,
      );
      expect(changed.enabled, isFalse);
      expect(changed.videoEnabled, isFalse);
      expect(changed.maxConcurrent, 1);
      expect(changed.audioEnabled, settings.audioEnabled);
      expect(changed.maxFileSizeBytes, settings.maxFileSizeBytes);
    });

    test('normalized clamps values to the build-time ceilings', () {
      const settings = DownloaderSettings(
        maxFileSizeBytes: 999999999999,
        maxConcurrent: 999,
        tempTtlMinutes: 999999,
      );
      final normalized = settings.normalized;
      expect(normalized.maxFileSizeBytes, DownloaderLimits.maxFileSizeBytes);
      expect(normalized.maxConcurrent, DownloaderLimits.maxConcurrent);
      expect(normalized.tempTtlMinutes, 24 * 60);
    });

    test('tempTtl getter converts minutes to a Duration', () {
      const settings = DownloaderSettings(tempTtlMinutes: 30);
      expect(settings.tempTtl, const Duration(minutes: 30));
    });
  });
}
