import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/app_media_player.dart';
import '../../../../core/services/audio_background_bootstrap.dart';
import '../../../../core/services/global_player_controller.dart';
import '../../../../core/services/playback_history_service.dart';
import '../../../../domain/entities/media_item.dart';

class AudioPlayerArgs {
  final String uri;
  final String title;
  final String? artist;
  final int positionMs;
  const AudioPlayerArgs(this.uri, this.title, this.artist, this.positionMs);

  @override
  bool operator ==(Object other) =>
      other is AudioPlayerArgs &&
      other.uri == uri &&
      other.title == title &&
      other.positionMs == positionMs &&
      other.artist == artist;

  @override
  int get hashCode =>
      uri.hashCode ^ title.hashCode ^ positionMs.hashCode ^ artist.hashCode;
}

enum AudioRepeatMode { off, one, all }

class AudioPlayerState {
  final String title;
  final String? artist;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final bool isFavorite;
  final bool shuffleEnabled;
  final AudioRepeatMode repeatMode;
  final Duration? sleepTimerRemaining;
  final String? error;

  const AudioPlayerState({
    this.title = '',
    this.artist,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.volume = 100.0,
    this.isFavorite = false,
    this.shuffleEnabled = false,
    this.repeatMode = AudioRepeatMode.off,
    this.sleepTimerRemaining,
    this.error,
  });

  AudioPlayerState copyWith({
    String? title,
    String? artist,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
    bool? isFavorite,
    bool? shuffleEnabled,
    AudioRepeatMode? repeatMode,
    Duration? sleepTimerRemaining,
    String? error,
    bool clearError = false,
    bool clearSleepTimer = false,
  }) => AudioPlayerState(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    isFavorite: isFavorite ?? this.isFavorite,
    shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    repeatMode: repeatMode ?? this.repeatMode,
    sleepTimerRemaining: clearSleepTimer
        ? null
        : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    error: clearError ? null : (error ?? this.error),
  );
}

/// MVVM ViewModel for audio playback, wrapping the shared media_kit engine.
class AudioPlayerNotifier extends AsyncNotifier<AudioPlayerState> {
  AudioPlayerNotifier(this._args);
  final AudioPlayerArgs _args;

  late final Player player;
  final List<StreamSubscription> _subs = [];
  double _volumeBeforeMute = AppConstants.volumeNormalMax;

  @override
  Future<AudioPlayerState> build() async {
    AppMediaPlayer.ensureInitialized();
    player = AppMediaPlayer.player;
    ref.onDispose(_dispose);

    final initialState = AudioPlayerState(
      title: _args.title,
      artist: _args.artist,
    );
    state = AsyncData(initialState);

    _subs.add(
      player.stream.position.listen((p) {
        if (!ref.mounted) return;
        state = AsyncData(state.value!.copyWith(position: p));
      }),
    );
    _subs.add(
      player.stream.duration.listen((d) {
        if (!ref.mounted) return;
        state = AsyncData(state.value!.copyWith(duration: d));
      }),
    );
    _subs.add(
      player.stream.playing.listen((p) {
        if (!ref.mounted) return;
        state = AsyncData(state.value!.copyWith(playing: p));
        if (p) _syncNotification();
      }),
    );
    _subs.add(
      player.stream.buffering.listen((b) {
        if (!ref.mounted) return;
        state = AsyncData(state.value!.copyWith(buffering: b));
      }),
    );
    _subs.add(
      player.stream.error.listen((e) {
        if (!ref.mounted) return;
        final current = state.value;
        if (e.isEmpty || current == null || current.error == e) return;
        state = AsyncData(current.copyWith(error: e));
      }),
    );

    // Provider state changes are forbidden while this AsyncNotifier is building.
    Timer.run(() {
      if (ref.mounted) _attachGlobalPlayer();
    });
    unawaited(_open());

    return state.value ?? initialState;
  }

  Future<void> _open() async {
    if (_args.uri.isEmpty) {
      state = AsyncData(
        state.value!.copyWith(error: 'No media source provided.'),
      );
      return;
    }
    state = AsyncData(state.value!.copyWith(buffering: true, clearError: true));
    try {
      await AppMediaPlayer.openAndPlay(
        _args.uri,
        start: Duration(milliseconds: _args.positionMs),
      );
      if (!ref.mounted) return;
      state = AsyncData(state.value!.copyWith(buffering: false));
      _syncNotification();
    } catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        state.value!.copyWith(error: e.toString(), buffering: false),
      );
    }
  }

  void _syncNotification() {
    if (!AudioBackgroundBootstrap.isInitialized) return;
    try {
      AudioBackgroundBootstrap.handler.setMediaInfo(
        title: _args.title,
        artist: _args.artist,
      );
    } catch (_) {}
  }

  void _attachGlobalPlayer() {
    final controller = ref.read(globalPlayerProvider.notifier);
    controller.attachPlayer(
      player: player,
      mode: PlayerMode.audio,
      item: MediaItem(
        id: 0,
        uri: _args.uri,
        fileName: _args.uri.split('/').last,
        displayName: _args.title,
        isAudio: true,
        artist: _args.artist,
      ),
    );
  }

  void togglePlay() {
    state.value!.playing ? player.pause() : player.play();
  }

  void seek(Duration pos) => player.seek(pos);
  void seekBy(Duration delta) => player.seek(state.value!.position + delta);

  Future<void> setSpeed(double s) async {
    state = AsyncData(state.value!.copyWith(speed: s));
    await player.setRate(s);
  }

  Future<void> setVolume(double v) async {
    final next = v.clamp(0.0, AppConstants.volumeBoostMax);
    if (next > 0) _volumeBeforeMute = next;
    state = AsyncData(state.value!.copyWith(volume: next));
    await player.setVolume(next);
  }

  Future<void> toggleMute() async {
    final current = state.value?.volume ?? AppConstants.volumeNormalMax;
    if (current == 0) {
      await setVolume(
        _volumeBeforeMute > 0
            ? _volumeBeforeMute
            : AppConstants.volumeNormalMax,
      );
    } else {
      _volumeBeforeMute = current;
      await setVolume(0);
    }
  }

  Future<void> toggleFavorite(int? mediaId) async {
    if (mediaId == null) return;
    final lib = ref.read(libraryRepositoryProvider);
    final next = !state.value!.isFavorite;
    await lib.toggleFavorite(mediaId, next);
    state = AsyncData(state.value!.copyWith(isFavorite: next));
  }

  void toggleShuffle() {
    state = AsyncData(
      state.value!.copyWith(shuffleEnabled: !state.value!.shuffleEnabled),
    );
  }

  void cycleRepeat() {
    final modes = AudioRepeatMode.values;
    final nextIndex = (state.value!.repeatMode.index + 1) % modes.length;
    state = AsyncData(state.value!.copyWith(repeatMode: modes[nextIndex]));
  }

  void setSleepTimer(Duration duration) {
    state = AsyncData(state.value!.copyWith(sleepTimerRemaining: duration));
  }

  void clearSleepTimer() {
    state = AsyncData(state.value!.copyWith(clearSleepTimer: true));
  }

  Future<void> retry() async {
    state = AsyncData(state.value!.copyWith(clearError: true));
    await _open();
  }

  void _dispose() {
    _recordHistory();
    for (final s in _subs) {
      s.cancel();
    }
    // Do not dispose the shared AppMediaPlayer — mini player / next screen
    // continue using it.
  }

  void _recordHistory() {
    final playbackState = state.value;
    if (playbackState == null || _args.uri.isEmpty) return;
    unawaited(
      ref
          .read(playbackHistoryServiceProvider)
          .record(
            uri: _args.uri,
            title: _args.title,
            isVideo: false,
            positionMs: playbackState.position.inMilliseconds,
            durationMs: playbackState.duration.inMilliseconds,
            artist: _args.artist,
          ),
    );
  }
}

final audioPlayerControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AudioPlayerNotifier, AudioPlayerState, AudioPlayerArgs>(
      AudioPlayerNotifier.new,
    );
