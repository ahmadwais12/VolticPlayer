import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callbacks for video gesture events.
class VideoGestureCallbacks {
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<Duration>? onSeekDelta;
  final VoidCallback? onDoubleTapLeft;
  final VoidCallback? onDoubleTapRight;
  final VoidCallback? onDoubleTapCenter;
  final ValueChanged<double>? onZoomChanged;

  const VideoGestureCallbacks({
    this.onBrightnessChanged,
    this.onVolumeChanged,
    this.onSeekDelta,
    this.onDoubleTapLeft,
    this.onDoubleTapRight,
    this.onDoubleTapCenter,
    this.onZoomChanged,
  });
}

/// Gesture state exposed to the UI for overlay feedback.
enum GestureType { none, brightness, volume, seek }

class VideoGestureState {
  final GestureType type;
  final double value; // 0-1
  final Duration? seekDelta;
  final bool isVisible;

  const VideoGestureState({
    this.type = GestureType.none,
    this.value = 0,
    this.seekDelta,
    this.isVisible = false,
  });

  VideoGestureState copyWith({
    GestureType? type,
    double? value,
    Duration? seekDelta,
    bool? isVisible,
  }) =>
      VideoGestureState(
        type: type ?? this.type,
        value: value ?? this.value,
        seekDelta: seekDelta,
        isVisible: isVisible ?? this.isVisible,
      );
}

/// Full-screen gesture overlay for the video player.
///
/// Handles:
/// - Left swipe: brightness
/// - Right swipe: volume
/// - Horizontal swipe: seek
/// - Double-tap left/right: ±10s
/// - Double-tap center: play/pause
/// - Pinch: zoom
class VideoGestureDetector extends StatefulWidget {
  final Widget child;
  final VideoGestureCallbacks callbacks;
  final ValueChanged<VideoGestureState>? onGestureStateChanged;
  final bool enabled;
  final double initialBrightness;
  final double initialVolume;

  const VideoGestureDetector({
    super.key,
    required this.child,
    required this.callbacks,
    this.onGestureStateChanged,
    this.enabled = true,
    this.initialBrightness = 0.5,
    this.initialVolume = 0.5,
  });

  @override
  State<VideoGestureDetector> createState() => _VideoGestureDetectorState();
}

class _VideoGestureDetectorState extends State<VideoGestureDetector>
    with SingleTickerProviderStateMixin {
  // Gesture state
  late double _brightness;
  late double _volume;
  double _zoom = 1.0;
  double _gestureStartBrightness = 0.5;
  double _gestureStartVolume = 0.5;

  // Swipe tracking
  double _startX = 0;
  double _startY = 0;
  bool _isVerticalSwipe = false;
  bool _isHorizontalSwipe = false;
  bool _swipeDecided = false;

  // Double-tap tracking
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Timer? _doubleTapTimer;

  // Long press (speed boost) reserved for future use

  // Hide gesture feedback
  Timer? _hideTimer;

  static const double _swipeThreshold = 10.0;
  static const double _seekSensitivity = 150.0; // pixels per second
  /// Vertical pixels → level change. Swipe up increases, down decreases.
  static const double _brightnessVolumeSensitivity = 0.004;
  static const int _doubleTapWindowMs = 300;
  static const Duration _feedbackHideDelay = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness.clamp(0.0, 1.0);
    _volume = widget.initialVolume.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant VideoGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isVerticalSwipe) {
      if (oldWidget.initialBrightness != widget.initialBrightness) {
        _brightness = widget.initialBrightness.clamp(0.0, 1.0);
      }
      if (oldWidget.initialVolume != widget.initialVolume) {
        _volume = widget.initialVolume.clamp(0.0, 1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _onTapDown : null,
      onDoubleTapDown: widget.enabled ? _onDoubleTapDown : null,
      onDoubleTap: widget.enabled ? _onDoubleTap : null,
      onScaleStart: widget.enabled ? _onScaleStart : null,
      onScaleUpdate: widget.enabled ? _onScaleUpdate : null,
      onScaleEnd: widget.enabled ? _onScaleEnd : null,
      onLongPressStart: widget.enabled ? _onLongPressStart : null,
      onLongPressEnd: widget.enabled ? _onLongPressEnd : null,
      child: widget.child,
    );
  }

  // ── Tap / Double-tap ──────────────────────────────────────────────────

  void _onTapDown(TapDownDetails details) {
    final now = DateTime.now();
    final pos = details.localPosition;

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _doubleTapWindowMs &&
        _lastTapPosition != null) {
      // Second tap — this is a double tap (Flutter may or may not call onDoubleTap)
      _doubleTapTimer?.cancel();
    } else {
      // First tap — start a timer
      _lastTapTime = now;
      _lastTapPosition = pos;
      _doubleTapTimer = Timer(const Duration(milliseconds: _doubleTapWindowMs), () {
        // Single tap — do nothing (controls toggle is handled by parent)
      });
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapTimer?.cancel();
    final dx = details.localPosition.dx;
    final screenWidth = MediaQuery.of(context).size.width;

    if (dx < screenWidth / 3) {
      // Left third: rewind
      HapticFeedback.lightImpact();
      widget.callbacks.onDoubleTapLeft?.call();
    } else if (dx > screenWidth * 2 / 3) {
      // Right third: forward
      HapticFeedback.lightImpact();
      widget.callbacks.onDoubleTapRight?.call();
    } else {
      // Center: play/pause
      HapticFeedback.mediumImpact();
      widget.callbacks.onDoubleTapCenter?.call();
    }
  }

  void _onDoubleTap() {
    // Already handled in onDoubleTapDown
  }

  // ── Scale (pinch zoom + swipe) ────────────────────────────────────────

  double? _initialScale;

  void _onScaleStart(ScaleStartDetails details) {
    _startX = details.focalPoint.dx;
    _startY = details.focalPoint.dy;
    _swipeDecided = false;
    _isVerticalSwipe = false;
    _isHorizontalSwipe = false;
    _initialScale = _zoom;
    _gestureStartBrightness = _brightness;
    _gestureStartVolume = _volume;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dx = details.focalPoint.dx - _startX;
    final dy = details.focalPoint.dy - _startY;

    // Pinch zoom
    if (details.scale != 1.0 && _initialScale != null) {
      final newZoom = (_initialScale! * details.scale).clamp(0.5, 5.0);
      _zoom = newZoom;
      widget.callbacks.onZoomChanged?.call(_zoom);
      return;
    }

    // Decide swipe direction on first significant movement
    if (!_swipeDecided &&
        (dx.abs() > _swipeThreshold || dy.abs() > _swipeThreshold)) {
      _swipeDecided = true;
      _isVerticalSwipe = dy.abs() > dx.abs();
      _isHorizontalSwipe = !_isVerticalSwipe;
    }

    if (_isVerticalSwipe) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isLeftSide = _startX < screenWidth / 2;
      // Finger up (negative dy) raises level; finger down lowers it.
      final levelDelta = -dy * _brightnessVolumeSensitivity;

      if (isLeftSide) {
        _brightness = (_gestureStartBrightness + levelDelta).clamp(0.0, 1.0);
        widget.callbacks.onBrightnessChanged?.call(_brightness);
        _notifyState(GestureType.brightness, _brightness);
      } else {
        _volume = (_gestureStartVolume + levelDelta).clamp(0.0, 1.0);
        widget.callbacks.onVolumeChanged?.call(_volume);
        _notifyState(GestureType.volume, _volume);
      }
    } else if (_isHorizontalSwipe) {
      // Horizontal: seek
      final seconds = dx / _seekSensitivity;
      final delta = Duration(milliseconds: (seconds * 1000).round());
      _notifyState(GestureType.seek, 0, seekDelta: delta);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _swipeDecided = false;
    _initialScale = null;

    if (_isHorizontalSwipe) {
      final dx = details.velocity.pixelsPerSecond.dx;
      final seconds = dx / _seekSensitivity;
      final delta = Duration(milliseconds: (seconds * 1000).round());
      widget.callbacks.onSeekDelta?.call(delta);
    }

    _hideGestureFeedback();
  }

  // ── Long press (speed boost) ──────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.heavyImpact();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    // Reserved for long-press speed boost
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Size? get size => context.size;

  void _notifyState(GestureType type, double value, {Duration? seekDelta}) {
    widget.onGestureStateChanged?.call(VideoGestureState(
      type: type,
      value: value,
      seekDelta: seekDelta,
      isVisible: true,
    ));
  }

  void _hideGestureFeedback() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_feedbackHideDelay, () {
      widget.onGestureStateChanged?.call(const VideoGestureState());
    });
  }

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }
}
