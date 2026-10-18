import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

/// Wraps a [media_kit] [Player] behind [audio_service]'s [BaseAudioHandler]
/// so the system notification, lock-screen, and Android Auto all work.
///
/// Usage:
/// ```dart
/// final handler = SarwariAudioHandler(player);
/// await handler.setMediaInfo(title: 'Song', artist: 'Artist', uri: '...');
/// await handler.play();
/// ```
class SarwariAudioHandler extends BaseAudioHandler with SeekHandler {
  final Player _player;
  final List<StreamSubscription> _subs = [];
  final Stopwatch _positionUpdateClock = Stopwatch()..start();
  Duration _lastPublishedPosition = Duration.zero;
  int _lastPositionUpdateMs = -1;

  SarwariAudioHandler(this._player) {
    _wireStreams();
  }

  // ── Wire media_kit streams → audio_service media state ────────────────

  void _wireStreams() {
    _subs.add(_player.stream.playing.listen((playing) {
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        processingState: AudioProcessingState.ready,
      ));
    }));

    _subs.add(_player.stream.position.listen((pos) {
      final nowMs = _positionUpdateClock.elapsedMilliseconds;
      final deltaMs = pos.inMilliseconds - _lastPublishedPosition.inMilliseconds;
      // Android's media session only needs periodic seek-bar updates. Sending
      // every decoder tick floods Logcat and needlessly wakes the system UI.
      if (_lastPositionUpdateMs >= 0 &&
          nowMs - _lastPositionUpdateMs < 1000 &&
          deltaMs >= 0 &&
          deltaMs < 1000) {
        return;
      }
      _lastPositionUpdateMs = nowMs;
      _lastPublishedPosition = pos;
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    }));

    _subs.add(_player.stream.buffering.listen((buffering) {
      if (buffering) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.buffering,
        ));
      } else {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
        ));
      }
    }));

    _subs.add(_player.stream.completed.listen((completed) {
      if (completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
      }
    }));

    _subs.add(_player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      }
    }));
  }

  // ── Media item metadata ───────────────────────────────────────────────

  /// Update the notification / lock-screen with track metadata.
  void setMediaInfo({
    required String title,
    String? artist,
    String? artUri,
  }) {
    mediaItem.add(MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    ));
  }

  // ── AudioService overrides ────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Single-track player — no-op; extend for playlist support.
  }

  @override
  Future<void> skipToPrevious() async {
    // Single-track player — no-op; extend for playlist support.
  }

  Future<void> setSpeed(double speed) => _player.setRate(speed);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await super.stop();
  }
}
