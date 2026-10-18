import 'package:flutter/foundation.dart';

import 'audio_background_bootstrap.dart';

/// Manages media playback notifications via [audio_service].
///
/// This is a thin facade over [SarwariAudioHandler] that provides
/// a cleaner API for feature controllers to update notifications.
class NotificationService {
  /// Update the media notification with track metadata.
  static void updateMediaInfo({
    required String title,
    String? artist,
    String? artUri,
  }) {
    if (!AudioBackgroundBootstrap.isInitialized) return;

    try {
      AudioBackgroundBootstrap.handler.setMediaInfo(
        title: title,
        artist: artist,
        artUri: artUri,
      );
    } catch (e) {
      debugPrint('[NotificationService] updateMediaInfo failed: $e');
    }
  }

  /// Notify that playback state changed.
  static void notifyPlaying() {
    if (!AudioBackgroundBootstrap.isInitialized) return;
    try {
      AudioBackgroundBootstrap.handler.play();
    } catch (e) {
      debugPrint('[NotificationService] notifyPlaying failed: $e');
    }
  }

  /// Notify that playback paused.
  static void notifyPaused() {
    if (!AudioBackgroundBootstrap.isInitialized) return;
    try {
      AudioBackgroundBootstrap.handler.pause();
    } catch (e) {
      debugPrint('[NotificationService] notifyPaused failed: $e');
    }
  }

  /// Stop the notification.
  static Future<void> stop() async {
    if (!AudioBackgroundBootstrap.isInitialized) return;
    try {
      await AudioBackgroundBootstrap.handler.stop();
    } catch (e) {
      debugPrint('[NotificationService] stop failed: $e');
    }
  }
}
