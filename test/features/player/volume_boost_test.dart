import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/constants/app_constants.dart';

void main() {
  group('Volume boost range', () {
    test('normal max is 100 and boost max is 200', () {
      expect(AppConstants.volumeNormalMax, 100);
      expect(AppConstants.volumeBoostMax, 200);
    });

    test('clamp keeps volume inside 0–200', () {
      expect((-10.0).clamp(0.0, AppConstants.volumeBoostMax), 0);
      expect(50.0.clamp(0.0, AppConstants.volumeBoostMax), 50);
      expect(100.0.clamp(0.0, AppConstants.volumeBoostMax), 100);
      expect(150.0.clamp(0.0, AppConstants.volumeBoostMax), 150);
      expect(250.0.clamp(0.0, AppConstants.volumeBoostMax), 200);
    });

    test('boost is detected above 100%', () {
      expect(100.0 > AppConstants.volumeNormalMax, isFalse);
      expect(101.0 > AppConstants.volumeNormalMax, isTrue);
      expect(200.0 > AppConstants.volumeNormalMax, isTrue);
    });

    test('presets include normal and boost values', () {
      expect(AppConstants.volumePresets, containsAll([0, 50, 100, 125, 150, 200]));
    });
  });
}
