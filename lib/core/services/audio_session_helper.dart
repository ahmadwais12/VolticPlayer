import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Configures the audio session so background playback, audio focus,
/// and ducking work correctly on both Android and iOS.
///
/// Call [configure] once during app startup.
class AudioSessionHelper {
  static bool _configured = false;

  /// Configure the audio session for media playback.
  /// Safe to call multiple times — only runs once.
  static Future<void> configure() async {
    if (_configured) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: false,
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));

      // Listen for audio interruptions (e.g. phone calls)
      session.interruptionEventStream.listen((event) {
        debugPrint('[AudioSession] interruption: ${event.begin}');
      });

      // Listen for "becoming noisy" (headphone unplugged)
      session.becomingNoisyEventStream.listen((_) {
        debugPrint('[AudioSession] becoming noisy — pausing');
      });

      _configured = true;
      debugPrint('[AudioSession] configured successfully');
    } catch (e) {
      debugPrint('[AudioSession] configuration failed: $e');
    }
  }
}
