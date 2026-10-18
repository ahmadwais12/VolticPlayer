import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Single app-wide media_kit [Player] used by video, audio, and audio_service.
///
/// Creating multiple [Player] instances (plus a separate notification player)
/// caused black screens and silent playback failures on Android.
class AppMediaPlayer {
  AppMediaPlayer._();

  static Player? _player;
  static VideoController? _videoController;
  static bool _ready = false;
  static int _playbackRequest = 0;
  static Future<void> _openQueue = Future<void>.value();

  static Player get player {
    ensureInitialized();
    return _player!;
  }

  static VideoController get videoController {
    ensureInitialized();
    return _videoController!;
  }

  static bool get isReady => _ready;

  /// Gives a screen a token so a slow open cannot replace a newer selection.
  static int beginPlaybackRequest() => ++_playbackRequest;

  static void cancelPlaybackRequest(int request) {
    if (_playbackRequest == request) _playbackRequest++;
  }

  /// Stops a video when its screen closes, unless a newer screen has already
  /// taken ownership of the shared player. The stop is queued behind any open
  /// operation so closing an old route cannot interrupt a newly selected item.
  static Future<void> closePlaybackRequest(int request) {
    if (request != _playbackRequest) return Future<void>.value();

    final closingRequest = ++_playbackRequest;
    final operation = _openQueue.then((_) async {
      if (closingRequest != _playbackRequest) return;
      try {
        await player.stop();
      } catch (_) {
        // Route disposal should not leave an unhandled async error.
      }
    });
    _openQueue = operation.catchError((Object _) {});
    return operation;
  }

  static VideoControllerConfiguration get _videoConfig {
    if (Platform.isAndroid) {
      // Use the default (mediacodec/surface) VO on Android.
      // gpu VO can leave a permanent black surface on Mali/Adreno devices.
      // androidAttachSurfaceAfterVideoParameters ensures the Surface is
      // registered only after mpv knows the video dimensions, which is the
      // primary fix for black-screen on Android.
      return const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: true,
      );
    }
    return const VideoControllerConfiguration(enableHardwareAcceleration: true);
  }

  /// Safe to call multiple times. Must run after [MediaKit.ensureInitialized].
  static void ensureInitialized() {
    if (_ready) return;
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'VolticPlayer',
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player!, configuration: _videoConfig);
    _ready = true;
  }

  /// Normalize local paths / content URIs so media_kit can open them.
  static String normalizeSource(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;

    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('rtsp://') ||
        value.startsWith('rtmp://') ||
        value.startsWith('content://') ||
        value.startsWith('file://')) {
      return value;
    }

    // Absolute filesystem path → file URI. Keep raw path as fallback open
    // candidate when file:// fails on some Android builds.
    if (value.startsWith('/') ||
        (Platform.isWindows &&
            value.length > 2 &&
            value[1] == ':' &&
            (value[2] == '\\' || value[2] == '/'))) {
      return Uri.file(value).toString();
    }

    return value;
  }

  static bool _isNetwork(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static Map<String, String>? _httpHeadersFor(String value) {
    if (!_isNetwork(value)) return null;
    return const {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
  }

  /// Open and start playback. Tries normalized URI first, then raw path.
  static Future<void> openAndPlay(
    String source, {
    Duration start = Duration.zero,
    int? request,
  }) async {
    ensureInitialized();
    final operation = _openQueue.then(
      (_) => _openAndPlayNow(source, start: start, request: request),
    );
    // Keep the queue alive after a failed open while still returning the
    // failure to the caller.
    _openQueue = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> _openAndPlayNow(
    String source, {
    required Duration start,
    required int? request,
  }) async {
    if (request != null && request != _playbackRequest) return;
    final normalized = normalizeSource(source);
    final candidates = <String>{
      if (normalized.isNotEmpty) normalized,
      if (source.trim().isNotEmpty) source.trim(),
    }.toList();

    Object? lastError;
    for (final candidate in candidates) {
      try {
        if (request != null && request != _playbackRequest) return;
        await player.open(
          Media(
            candidate,
            start: start,
            httpHeaders: _httpHeadersFor(candidate),
          ),
          play: true,
        );
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Unable to open media source.');
  }
}
