import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_media_player.dart';
import '../../../../core/services/audio_background_bootstrap.dart';
import '../../../../core/services/global_player_controller.dart';
import '../../../../core/services/playback_history_service.dart';
import '../../../../core/services/youtube_media_resolver.dart';
import '../../../../domain/entities/media_item.dart';

class VideoPlayerArgs {
  final String uri;
  final String title;
  final int positionMs;
  const VideoPlayerArgs(this.uri, this.title, this.positionMs);

  @override
  bool operator ==(Object other) =>
      other is VideoPlayerArgs &&
      other.uri == uri &&
      other.title == title &&
      other.positionMs == positionMs;

  @override
  int get hashCode => uri.hashCode ^ title.hashCode ^ positionMs.hashCode;
}

class VideoPlayerState {
  final String title;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final bool fullscreen;
  final bool isLocked;
  final bool isAudioOnly;
  final bool useYoutubeEmbed;
  final bool hasFirstFrame;
  final String? resolvedStreamUrl;
  final String? error;
  final List<SubtitleTrack> subtitleTracks;
  final List<AudioTrack> audioTracks;
  final SubtitleTrack? selectedSubtitle;
  final AudioTrack? selectedAudio;

  const VideoPlayerState({
    this.title = '',
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.volume = 100.0,
    this.fullscreen = false,
    this.isLocked = false,
    this.isAudioOnly = false,
    this.useYoutubeEmbed = false,
    this.hasFirstFrame = false,
    this.resolvedStreamUrl,
    this.error,
    this.subtitleTracks = const [],
    this.audioTracks = const [],
    this.selectedSubtitle,
    this.selectedAudio,
  });

  VideoPlayerState copyWith({
    String? title,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
    bool? fullscreen,
    bool? isLocked,
    bool? isAudioOnly,
    bool? useYoutubeEmbed,
    bool? hasFirstFrame,
    String? resolvedStreamUrl,
    String? error,
    List<SubtitleTrack>? subtitleTracks,
    List<AudioTrack>? audioTracks,
    SubtitleTrack? selectedSubtitle,
    AudioTrack? selectedAudio,
    bool clearError = false,
  }) => VideoPlayerState(
    title: title ?? this.title,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    fullscreen: fullscreen ?? this.fullscreen,
    isLocked: isLocked ?? this.isLocked,
    isAudioOnly: isAudioOnly ?? this.isAudioOnly,
    useYoutubeEmbed: useYoutubeEmbed ?? this.useYoutubeEmbed,
    hasFirstFrame: hasFirstFrame ?? this.hasFirstFrame,
    resolvedStreamUrl: resolvedStreamUrl ?? this.resolvedStreamUrl,
    error: clearError ? null : (error ?? this.error),
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    audioTracks: audioTracks ?? this.audioTracks,
    selectedSubtitle: selectedSubtitle ?? this.selectedSubtitle,
    selectedAudio: selectedAudio ?? this.selectedAudio,
  );
}

/// MVVM ViewModel for video playback, wrapping the shared media_kit engine.
class VideoPlayerNotifier extends AsyncNotifier<VideoPlayerState> {
  VideoPlayerNotifier(this._args);
  final VideoPlayerArgs _args;

  late final Player player;
  late final PlaybackHistoryService _historyService;
  late VideoController videoController;
  final List<StreamSubscription> _subs = [];
  bool _playbackStarted = false;
  int? _activeOpenRequest;
  double _volumeBeforeMute = AppConstants.volumeNormalMax;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

  @override
  Future<VideoPlayerState> build() async {
    AppMediaPlayer.ensureInitialized();
    player = AppMediaPlayer.player;
    videoController = AppMediaPlayer.videoController;
    _historyService = ref.read(playbackHistoryServiceProvider);
    ref.onDispose(_dispose);

    final initialState = VideoPlayerState(title: _args.title, fullscreen: true);
    state = AsyncData(initialState);

    _subs.add(
      player.stream.position.listen((p) {
        _lastPosition = p;
        if (!ref.mounted) return;
        state = AsyncData(state.value!.copyWith(position: p));
      }),
    );
    _subs.add(
      player.stream.duration.listen((d) {
        _lastDuration = d;
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
        final friendly = e.toLowerCase().contains('failed to open')
            ? 'Could not open this media. If it is an online sample, the link may be blocked — try a file from your device.'
            : e;
        state = AsyncData(current.copyWith(error: friendly, buffering: false));
      }),
    );
    _subs.add(
      player.stream.tracks.listen((t) {
        if (!ref.mounted) return;
        state = AsyncData(
          state.value!.copyWith(
            subtitleTracks: t.subtitle,
            audioTracks: t.audio,
            selectedSubtitle: player.state.track.subtitle,
            selectedAudio: player.state.track.audio,
          ),
        );
      }),
    );

    // Provider state changes are forbidden while this AsyncNotifier is building.
    Timer.run(() {
      if (ref.mounted) _attachGlobalPlayer();
    });
    // Do not open media here. Opening before the Video widget is mounted (and
    // before landscape rotation settles) produces a black Android surface.
    return state.value ?? initialState;
  }

  /// Called by the screen after landscape layout + Video mount.
  Future<void> startPlayback() async {
    if (_playbackStarted) return;
    _playbackStarted = true;
    await _prepareAndOpen();
  }

  bool _isYouTubeUrl(String value) {
    return YoutubeMediaResolver().isYouTubeUrl(value);
  }

  Future<void> _prepareAndOpen() async {
    if (_args.uri.isEmpty) {
      state = AsyncData(
        state.value!.copyWith(error: 'No media source provided.'),
      );
      return;
    }

    var openUri = _args.uri;
    if (_isYouTubeUrl(openUri)) {
      state = AsyncData(state.value!.copyWith(buffering: true));
      try {
        final stream = await YoutubeMediaResolver().playableUrl(openUri);
        if (!ref.mounted) return;
        if (stream != null && stream.isNotEmpty) {
          openUri = stream;
          state = AsyncData(
            state.value!.copyWith(
              resolvedStreamUrl: stream,
              useYoutubeEmbed: false,
              buffering: false,
            ),
          );
        } else {
          state = AsyncData(
            state.value!.copyWith(useYoutubeEmbed: true, buffering: false),
          );
          return;
        }
      } catch (_) {
        if (!ref.mounted) return;
        state = AsyncData(
          state.value!.copyWith(useYoutubeEmbed: true, buffering: false),
        );
        return;
      }
    }

    await _open(openUri);
  }

  Future<void> _open([String? uri]) async {
    final source = uri ?? state.value?.resolvedStreamUrl ?? _args.uri;
    if (source.isEmpty) {
      state = AsyncData(
        state.value!.copyWith(error: 'No media source provided.'),
      );
      return;
    }
    state = AsyncData(
      state.value!.copyWith(
        buffering: true,
        hasFirstFrame: false,
        clearError: true,
      ),
    );
    final request = AppMediaPlayer.beginPlaybackRequest();
    _activeOpenRequest = request;
    try {
      try {
        await videoController.platform.future.timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!ref.mounted || request != _activeOpenRequest) return;

      await AppMediaPlayer.openAndPlay(
        source,
        start: Duration(milliseconds: _args.positionMs),
        request: request,
      );
      if (!ref.mounted || request != _activeOpenRequest) return;

      state = AsyncData(
        state.value!.copyWith(buffering: false, hasFirstFrame: true),
      );
      if (state.value?.isAudioOnly != true) {
        unawaited(_markFirstFrameWhenReady(request: request));
      }
      _syncNotification();
    } catch (e) {
      if (!ref.mounted) return;
      if (_isYouTubeUrl(_args.uri)) {
        state = AsyncData(
          state.value!.copyWith(
            useYoutubeEmbed: true,
            buffering: false,
            clearError: true,
          ),
        );
        return;
      }
      state = AsyncData(
        state.value!.copyWith(error: e.toString(), buffering: false),
      );
    }
  }

  Future<void> _markFirstFrameWhenReady({int? request}) async {
    try {
      final platform = await videoController.platform.future.timeout(
        const Duration(seconds: 5),
      );
      await platform.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {}
    if (!ref.mounted) return;
    if (request != null && request != _activeOpenRequest) return;
    final current = state.value;
    if (current == null || current.hasFirstFrame) return;
    state = AsyncData(current.copyWith(hasFirstFrame: true));
  }

  void _syncNotification() {
    if (!AudioBackgroundBootstrap.isInitialized) return;
    try {
      AudioBackgroundBootstrap.handler.setMediaInfo(title: _args.title);
    } catch (_) {}
  }

  void _attachGlobalPlayer() {
    final controller = ref.read(globalPlayerProvider.notifier);
    controller.attachPlayer(
      player: player,
      mode: PlayerMode.video,
      item: MediaItem(
        id: 0,
        uri: _args.uri,
        fileName: _args.uri.split('/').last,
        displayName: _args.title,
        isAudio: false,
      ),
    );
  }

  void togglePlay() {
    if (state.value!.playing) {
      player.pause();
    } else {
      player.play();
    }
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

  Future<void> toggleFullscreen() async {
    state = AsyncData(
      state.value!.copyWith(fullscreen: !state.value!.fullscreen),
    );
  }

  void toggleLock() => state = AsyncData(
    state.value!.copyWith(isLocked: !state.value!.isLocked),
  );

  void toggleAudioOnly() => state = AsyncData(
    state.value!.copyWith(isAudioOnly: !state.value!.isAudioOnly),
  );

  Future<void> retry() async {
    _playbackStarted = true;
    state = AsyncData(
      state.value!.copyWith(
        clearError: true,
        useYoutubeEmbed: false,
        hasFirstFrame: false,
      ),
    );
    await _prepareAndOpen();
  }

  Future<void> selectSubtitle(SubtitleTrack? track) async {
    await player.setSubtitleTrack(track ?? SubtitleTrack.no());
    state = AsyncData(state.value!.copyWith(selectedSubtitle: track));
  }

  Future<void> selectAudio(AudioTrack track) async {
    await player.setAudioTrack(track);
    state = AsyncData(state.value!.copyWith(selectedAudio: track));
  }

  void _dispose() {
    if (_activeOpenRequest != null) {
      if (state.value?.isAudioOnly == true) {
        // Audio-only playback was explicitly requested; keep it alive after
        // the video route is dismissed.
        AppMediaPlayer.cancelPlaybackRequest(_activeOpenRequest!);
      } else {
        unawaited(AppMediaPlayer.closePlaybackRequest(_activeOpenRequest!));
      }
    }
    final uri = _args.uri;
    if (uri.isNotEmpty) {
      final title = _args.title;
      final positionMs = _lastPosition.inMilliseconds;
      final durationMs = _lastDuration.inMilliseconds;
      final historyService = _historyService;
      // Riverpod disallows provider reads/writes during onDispose. Defer the
      // already-snapshotted values until after the lifecycle callback returns.
      Timer.run(() {
        unawaited(
          historyService.record(
            uri: uri,
            title: title,
            isVideo: true,
            positionMs: positionMs,
            durationMs: durationMs,
          ),
        );
      });
    }
    for (final s in _subs) {
      s.cancel();
    }
    // Keep the shared player alive for the mini player / next media.
  }
}

final videoPlayerControllerProvider = AsyncNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, VideoPlayerArgs>(
      VideoPlayerNotifier.new,
    );
