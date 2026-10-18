import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'app_media_player.dart';
import 'audio_handler.dart';

/// Initializes [audio_service] against the shared [AppMediaPlayer].
class AudioBackgroundBootstrap {
  static SarwariAudioHandler? _handler;

  static SarwariAudioHandler get handler {
    assert(_handler != null, 'Call AudioBackgroundBootstrap.init() first.');
    return _handler!;
  }

  static bool get isInitialized => _handler != null;

  /// Initialize audio_service. Returns the handler for immediate use.
  static Future<SarwariAudioHandler> init() async {
    if (_handler != null) return _handler!;

    try {
      AppMediaPlayer.ensureInitialized();
      _handler = await AudioService.init<SarwariAudioHandler>(
        builder: () => SarwariAudioHandler(AppMediaPlayer.player),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.voltic.player.audio',
          androidNotificationChannelName: 'VolticPlayer',
          androidNotificationChannelDescription:
              'Controls for audio and video playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );

      debugPrint('[AudioBackground] initialized successfully');
      return _handler!;
    } catch (e) {
      debugPrint('[AudioBackground] initialization failed: $e');
      rethrow;
    }
  }
}
