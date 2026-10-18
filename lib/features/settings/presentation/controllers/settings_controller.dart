import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

class SettingsKeys {
  SettingsKeys._();
  static const rememberPosition = 'remember_position';
  static const autoRotate = 'auto_rotate';
  static const hardwareDecoding = 'hardware_decoding';
  static const backgroundAudio = 'background_audio';
  static const gestureSeek = 'gesture_seek';
  static const gestureVolume = 'gesture_volume';
  static const gestureBrightness = 'gesture_brightness';
  static const doubleTap = 'double_tap';
  static const analytics = 'analytics';
  static const crossfade = 'crossfade';
  static const gapless = 'gapless';

  static const all = [
    rememberPosition,
    autoRotate,
    hardwareDecoding,
    backgroundAudio,
    gestureSeek,
    gestureVolume,
    gestureBrightness,
    doubleTap,
    analytics,
    crossfade,
    gapless,
  ];

  static bool defaultFor(String key) =>
      key == analytics || key == crossfade ? false : true;
}

/// Loads the boolean settings map. Toggling persists and invalidates.
final settingsMapProvider = FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  final map = <String, bool>{};
  for (final k in SettingsKeys.all) {
    map[k] = await repo.getSetting<bool>(k,
            defaultValue: SettingsKeys.defaultFor(k)) ??
        SettingsKeys.defaultFor(k);
  }
  return map;
});
