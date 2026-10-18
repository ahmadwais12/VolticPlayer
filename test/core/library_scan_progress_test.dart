import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/library_scan_progress.dart';

void main() {
  group('LibraryScanProgress', () {
    test('percent comes from displayValue', () {
      const p = LibraryScanProgress(
        isScanning: true,
        scanned: 20,
        total: 100,
        displayValue: 0.2,
      );
      expect(p.percent, 20);
      expect(p.value, 0.2);
    });

    test('ui duration bounds are 3s–60s', () {
      expect(kMinScanUi, const Duration(seconds: 3));
      expect(kMaxScanUi, const Duration(minutes: 1));
    });
  });
}
