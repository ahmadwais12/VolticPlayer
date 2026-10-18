import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sleep timer that pauses playback after a configurable duration.
/// Can also stop at end of current track.
class SleepTimerService {
  Timer? _timer;
  Duration? _remaining;
  bool _active = false;

  bool get isActive => _active;
  Duration? get remaining => _remaining;

  /// Callback to pause playback when timer fires.
  VoidCallback? onPause;

  /// Start the sleep timer with the given duration.
  void start(Duration duration, {VoidCallback? onPause}) {
    stop();
    this.onPause = onPause;
    _remaining = duration;
    _active = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining == null || _remaining!.inSeconds <= 0) {
        _fire();
        return;
      }
      _remaining = Duration(seconds: _remaining!.inSeconds - 1);
    });

    debugPrint('[SleepTimer] Started: ${duration.inMinutes} minutes');
  }

  /// Cancel the sleep timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _remaining = null;
    _active = false;
    debugPrint('[SleepTimer] Stopped');
  }

  /// Pause at end of current track.
  void pauseAtEndOfTrack({VoidCallback? onPause}) {
    this.onPause = onPause;
    _active = true;
    debugPrint('[SleepTimer] Will pause at end of track');
  }

  void _fire() {
    debugPrint('[SleepTimer] Timer fired — pausing playback');
    stop();
    onPause?.call();
  }

  void dispose() {
    stop();
  }
}
