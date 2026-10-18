import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../domain/entities/media_item.dart';

// ── Player mode ────────────────────────────────────────────────────────────

enum PlayerMode { audio, video, none }

// ── Global player state ────────────────────────────────────────────────────

class GlobalPlayerState {
  final PlayerMode mode;
  final MediaItem? currentItem;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final Player? player;

  const GlobalPlayerState({
    this.mode = PlayerMode.none,
    this.currentItem,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.player,
  });

  GlobalPlayerState copyWith({
    PlayerMode? mode,
    MediaItem? Function()? currentItem,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    Player? Function()? player,
  }) =>
      GlobalPlayerState(
        mode: mode ?? this.mode,
        currentItem: currentItem != null ? currentItem() : this.currentItem,
        isPlaying: isPlaying ?? this.isPlaying,
        isBuffering: isBuffering ?? this.isBuffering,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        player: player != null ? player() : this.player,
      );

  bool get hasMedia => currentItem != null;
  bool get hasActivePlayer => player != null;
  bool get isVideo => mode == PlayerMode.video;
  bool get isAudio => mode == PlayerMode.audio;
}

// ── Global player controller ───────────────────────────────────────────────

class GlobalPlayerController extends Notifier<GlobalPlayerState> {
  final List<StreamSubscription> _subs = [];

  @override
  GlobalPlayerState build() => const GlobalPlayerState();

  /// Start tracking a player instance for the mini player.
  void attachPlayer({
    required Player player,
    required PlayerMode mode,
    required MediaItem item,
  }) {
    // Detach previous
    detachPlayer();

    state = state.copyWith(
      mode: mode,
      currentItem: () => item,
      player: () => player,
    );

    _subs.add(player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    }));

    _subs.add(player.stream.buffering.listen((buffering) {
      state = state.copyWith(isBuffering: buffering);
    }));

    _subs.add(player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
    }));

    _subs.add(player.stream.duration.listen((dur) {
      state = state.copyWith(duration: dur);
    }));
  }

  /// Detach the current player (e.g. when navigating to full player screen).
  void detachPlayer() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    state = state.copyWith(
      mode: PlayerMode.none,
      currentItem: () => null,
      player: () => null,
      isPlaying: false,
      isBuffering: false,
      position: Duration.zero,
      duration: Duration.zero,
    );
  }

  /// Toggle play/pause on the active player.
  void togglePlayPause() {
    final player = state.player;
    if (player == null) return;
    if (state.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }

  /// Stop and clear everything.
  void stopAll() {
    state.player?.pause();
    detachPlayer();
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
  }
}

final globalPlayerProvider =
    NotifierProvider<GlobalPlayerController, GlobalPlayerState>(
  GlobalPlayerController.new,
);
