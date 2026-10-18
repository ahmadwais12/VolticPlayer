/// Lightweight analytics service for VolticPlayer.
///
/// Centralises all event tracking so the implementation can be swapped
/// (e.g. Firebase Analytics, Mixpanel, PostHog) without touching feature code.
///
/// HOW TO WIRE UP FIREBASE:
///   1. Add `firebase_core` and `firebase_analytics` to pubspec.yaml.
///   2. Run `flutterfire configure` to generate google-services.json / GoogleService-Info.plist.
///   3. Replace the `_log` stub below with `FirebaseAnalytics.instance.logEvent(...)`.
///
/// Until Firebase is wired up, events are printed in debug mode only.
library;

import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once from main() after all initialisation is complete.
  static Future<void> init() async {
    // TODO: await Firebase.initializeApp() here when Firebase is added.
    _log('analytics_init', {});
  }

  // ── Onboarding ───────────────────────────────────────────────────────────

  static void onboardingStarted() =>
      _log('onboarding_started', {});

  static void onboardingCompleted({required String themeChosen}) =>
      _log('onboarding_completed', {'theme': themeChosen});

  // ── Playback ─────────────────────────────────────────────────────────────

  static void videoPlayed({required String source}) =>
      _log('video_played', {'source': _sourceType(source)});

  static void audioPlayed({required String source}) =>
      _log('audio_played', {'source': _sourceType(source)});

  static void streamOpened({required String protocol}) =>
      _log('stream_opened', {'protocol': protocol});

  static void iptvOpened() => _log('iptv_opened', {});

  // ── Downloads ────────────────────────────────────────────────────────────

  static void downloadStarted({required String mediaType}) =>
      _log('download_started', {'media_type': mediaType});

  static void downloadCompleted({required String mediaType}) =>
      _log('download_completed', {'media_type': mediaType});

  static void downloadFailed({required String reason}) =>
      _log('download_failed', {'reason': reason});

  // ── Search ───────────────────────────────────────────────────────────────

  static void searchPerformed({required String query}) =>
      _log('search', {'query_length': query.length.toString()});

  static void webSearchPerformed() => _log('web_search', {});

  // ── Features ─────────────────────────────────────────────────────────────

  static void equalizerOpened() => _log('equalizer_opened', {});

  static void equalizerPresetChanged({required String preset}) =>
      _log('equalizer_preset_changed', {'preset': preset});

  static void subtitleLoaded({required String format}) =>
      _log('subtitle_loaded', {'format': format});

  static void bookmarkAdded() => _log('bookmark_added', {});

  static void playlistCreated() => _log('playlist_created', {});

  static void themeChanged({required String theme}) =>
      _log('theme_changed', {'theme': theme});

  static void pipActivated() => _log('pip_activated', {});

  static void screenshotTaken() => _log('screenshot_taken', {});

  // ── Engagement ───────────────────────────────────────────────────────────

  static void shareTriggered({required String context}) =>
      _log('share', {'context': context});

  static void ratingPromptShown() => _log('rating_prompt_shown', {});

  static void ratingPromptAccepted() => _log('rating_prompt_accepted', {});

  static void ratingPromptDismissed() => _log('rating_prompt_dismissed', {});

  // ── Errors ───────────────────────────────────────────────────────────────

  static void playbackError({required String error}) =>
      _log('playback_error', {'error': error.substring(0, error.length.clamp(0, 100))});

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _sourceType(String uri) {
    if (uri.startsWith('http')) return 'network';
    if (uri.startsWith('file://') || uri.startsWith('/')) return 'local';
    return 'unknown';
  }

  static void _log(String event, Map<String, String> params) {
    // TODO: replace with FirebaseAnalytics.instance.logEvent(name: event, parameters: params)
    if (kDebugMode) {
      debugPrint('[Analytics] $event ${params.isEmpty ? '' : params}');
    }
  }
}
