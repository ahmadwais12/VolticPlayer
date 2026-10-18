import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../web_search/domain/web_search_models.dart';
import '../../../web_search/presentation/controllers/web_search_providers.dart';
import '../../../web_search/presentation/widgets/download_options_sheet.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/screenshot_helper.dart';
import '../../../../shared/widgets/ab_repeat_overlay.dart';
import '../../../../shared/widgets/add_bookmark_sheet.dart';
import '../../../../shared/widgets/aspect_ratio_sheet.dart';
import '../../../../shared/widgets/buffering_indicator.dart';
import '../../../../shared/widgets/media_info_sheet.dart';
import '../../../../shared/widgets/playback_stats_overlay.dart';
import '../../../../shared/widgets/player_controls.dart';
import '../../../../shared/widgets/speed_sheet.dart';
import '../../../../shared/widgets/subtitle_delay_sheet.dart';
import '../../../../shared/widgets/subtitle_sheet.dart';
import '../../../../shared/widgets/sleep_timer_sheet.dart';
import '../../../../shared/widgets/volume_boost_sheet.dart';
import '../../../../core/di/providers.dart';
import '../../../../shared/widgets/gesture_feedback_overlay.dart';
import '../../../../shared/widgets/video_gesture_detector.dart';
import '../../../bookmarks/presentation/controllers/bookmarks_controller.dart';
import '../controllers/video_controller.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String uri;
  final String title;
  final int positionMs;
  final String? thumbnailPath;
  final WebResult? webResult;
  final List<WebResult> recommendations;

  const VideoPlayerScreen({
    super.key,
    required this.uri,
    required this.title,
    this.positionMs = 0,
    this.thumbnailPath,
    this.webResult,
    this.recommendations = const [],
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _controls = true;
  bool _showStats = false;
  bool _rotationLocked = false;
  bool _nightMode = false;
  bool _loopVideo = false;
  bool _shuffleEnabled = false;
  final Set<String> _hiddenPlayerActions = {};
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  double _subtitleDelay = 0;
  VideoAspectRatio _aspectRatio = VideoAspectRatio.fit;
  Duration? _abPointA;
  Duration? _abPointB;
  Timer? _hideControlsTimer;
  WebViewController? _youtubeController;
  bool _youtubeEmbedReady = false;
  bool _playbackKickoffStarted = false;
  double _brightnessLevel = 0.5;
  double _volumeLevel = 0.5;
  VideoGestureState _gestureFeedback = const VideoGestureState();

  @override
  void initState() {
    super.initState();
    VolumeController.instance.showSystemUI = false;
    unawaited(_loadGestureLevels());
    // Keep controls visible while the player is starting. Playback state changes
    // will start the three second auto-hide once playback actually begins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_kickOffPlaybackAfterLayout());
    });
  }

  Future<void> _loadGestureLevels() async {
    try {
      final brightness = await ScreenBrightness.instance.application;
      if (mounted)
        setState(() => _brightnessLevel = brightness.clamp(0.0, 1.0));
    } catch (_) {}
    try {
      final volume = await VolumeController.instance.getVolume();
      if (mounted) setState(() => _volumeLevel = volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _onBrightnessGesture(double value) async {
    _brightnessLevel = value;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  Future<void> _onVolumeGesture(double value) async {
    _volumeLevel = value;
    try {
      await VolumeController.instance.setVolume(value);
    } catch (_) {}
  }

  Future<void> _kickOffPlaybackAfterLayout() async {
    if (_playbackKickoffStarted || !mounted) return;
    _playbackKickoffStarted = true;

    // Give the Video widget one frame to mount and register its Surface
    // with the VideoController before we call open().
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final args = VideoPlayerArgs(widget.uri, widget.title, widget.positionMs);
    await ref
        .read(videoPlayerControllerProvider(args).notifier)
        .startPlayback();

    // Enter landscape after playback starts for local files.
    if (widget.webResult == null && mounted && !_rotationLocked) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted && !_rotationLocked) _enableLandscapePlayback();
    }
  }

  void _maybeEnterLandscapeAfterFirstFrame(
    VideoPlayerState? previous,
    VideoPlayerState next,
  ) {
    if (widget.webResult != null || _rotationLocked) return;
    if (!next.hasFirstFrame) return;
    if (previous?.hasFirstFrame == true) return;
    _enableLandscapePlayback();
  }

  String? _youtubeVideoId(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (!host.endsWith('youtube.com') &&
        !host.endsWith('youtube-nocookie.com')) {
      return null;
    }
    if (uri.path == '/watch') return uri.queryParameters['v'];
    if (uri.pathSegments.length >= 2 &&
        const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
      return uri.pathSegments[1];
    }
    return null;
  }

  void _ensureYoutubeEmbed() {
    if (_youtubeEmbedReady) return;
    final videoId = _youtubeVideoId(widget.uri);
    if (videoId == null) return;
    _youtubeEmbedReady = true;
    _youtubeController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('[YouTubeEmbed] ${error.description}');
          },
        ),
      )
      ..loadHtmlString('''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
  html,body{margin:0;height:100%;background:#000;overflow:hidden}
  iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
</style>
</head>
<body>
<iframe
  src="https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1"
  title="YouTube player"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
  allowfullscreen
  referrerpolicy="strict-origin-when-cross-origin"></iframe>
</body>
</html>
''', baseUrl: 'https://www.youtube.com');
  }

  void _enableLandscapePlayback() {
    // Default video playback to horizontal (landscape).
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _rotationLocked = true;
  }

  void _toggleRotationLock() {
    setState(() => _rotationLocked = !_rotationLocked);
    if (_rotationLocked) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _toggleFullscreen(
    VideoPlayerState state,
    VideoPlayerNotifier notifier,
  ) async {
    final enteringFullscreen = !state.fullscreen;
    await SystemChrome.setPreferredOrientations(
      enteringFullscreen || _rotationLocked
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
    await SystemChrome.setEnabledSystemUIMode(
      enteringFullscreen
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
    await notifier.toggleFullscreen();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  void _revealControls() {
    if (!mounted) return;
    setState(() => _controls = true);
    _startHideTimer();
  }

  void _toggleControls() {
    if (_controls) {
      _hideControlsTimer?.cancel();
      setState(() => _controls = false);
    } else {
      _revealControls();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _sleepTimer?.cancel();
    VolumeController.instance.showSystemUI = true;
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = VideoPlayerArgs(widget.uri, widget.title, widget.positionMs);
    final provider = videoPlayerControllerProvider(args);
    final asyncState = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    ref.listen(provider, (previous, next) {
      final prevState = previous?.asData?.value;
      final state = next.asData?.value;
      if (state == null) return;
      _maybeEnterLandscapeAfterFirstFrame(prevState, state);
      // Start the timer when playback begins or resumes. Position updates
      // arrive continuously, so rearming it on every state change prevents
      // the controls from ever hiding.
      final wasPlaying =
          prevState?.playing == true && prevState?.buffering != true;
      if (state.playing && !state.buffering && !wasPlaying) {
        _revealControls();
      } else if (!state.playing) {
        // Paused — keep controls visible.
        _hideControlsTimer?.cancel();
        if (mounted && !_controls) setState(() => _controls = true);
      }
    });

    // The Video widget MUST stay alive across loading→data transitions.
    // Placing it inside asyncState.when() destroys the native Android Surface
    // every time the provider state changes, causing a black screen.
    // Instead we always render the Video surface and overlay loading/error/data
    // UI on top of it.
    final videoSurface = _aspectRatio.ratio == null
        ? Video(
            key: const ValueKey('voltic-video-surface'),
            controller: notifier.videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          )
        : Center(
            child: AspectRatio(
              aspectRatio: _aspectRatio.ratio!,
              child: Video(
                key: const ValueKey('voltic-video-surface'),
                controller: notifier.videoController,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            ),
          );

    Widget body = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        videoSurface,
        asyncState.when(
          loading: () => Stack(
            fit: StackFit.expand,
            children: [
              if (_posterImage() case final poster?)
                Positioned.fill(child: poster),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
          error: (e, _) =>
              _ErrorOverlay(message: e.toString(), onRetry: notifier.retry),
          data: (state) => _buildContent(state, notifier),
        ),
      ],
    );

    if (widget.webResult != null) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final playerHeight = (screenWidth * 9 / 16).clamp(220.0, 420.0);
      final state = asyncState.asData?.value;
      body = Column(
        children: [
          SizedBox(height: playerHeight, width: double.infinity, child: body),
          if (state != null)
            Expanded(
              child: _WatchDetails(
                result: widget.webResult!,
                recommendations: widget.recommendations,
                onSave: () => _showBookmarkSheet(state),
                onPlayAudio: notifier.toggleAudioOnly,
                onPopup: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Picture-in-picture coming soon.'),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: widget.webResult != null
          ? Theme.of(context).colorScheme.surface
          : Colors.black,
      body: body,
    );
  }

  Widget? _posterImage() {
    final path = widget.thumbnailPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(VideoPlayerState state, VideoPlayerNotifier notifier) {
    // AB repeat: loop between A and B
    if (_abPointA != null && _abPointB != null) {
      if (state.position >= _abPointB!) {
        notifier.seek(_abPointA!);
      }
    }
    final isYouTube = state.useYoutubeEmbed;
    if (isYouTube) _ensureYoutubeEmbed();
    // The actual Video widget lives in build() above the asyncState.when().
    // Here we only render overlays on top of it.
    final playerSurface = Stack(
      children: [
        // ── Content overlay (YouTube / audio-only / error / poster) ──────
        if (isYouTube ||
            state.error != null ||
            state.isAudioOnly ||
            (!state.hasFirstFrame && _posterImage() != null))
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: isYouTube
                  ? (_youtubeController == null
                        ? const Center(child: CircularProgressIndicator())
                        : WebViewWidget(controller: _youtubeController!))
                  : state.error != null
                  ? _ErrorOverlay(
                      message: state.error!,
                      onRetry: notifier.retry,
                    )
                  : state.isAudioOnly
                  ? _AudioOnlyOverlay(
                      title: state.title,
                      playing: state.playing,
                      position: state.position,
                      duration: state.duration,
                    )
                  : _posterImage()!,
            ),
          ),

        if (!isYouTube && _nightMode)
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x28FF6D00))),
          ),

        // Minimize / back when watching online content
        if (widget.webResult != null)
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
            ),
          ),

        // ── Gesture overlay (local player only) ───────────────
        // Left vertical swipe = brightness, right vertical swipe = volume.
        // Keep active while unlocked so gestures work with controls hidden.
        if (!isYouTube)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: state.isLocked,
              child: VideoGestureDetector(
                enabled: !state.isLocked,
                initialBrightness: _brightnessLevel,
                initialVolume: _volumeLevel,
                callbacks: VideoGestureCallbacks(
                  onBrightnessChanged: _onBrightnessGesture,
                  onVolumeChanged: _onVolumeGesture,
                  onDoubleTapLeft: () {
                    _revealControls();
                    notifier.seekBy(
                      const Duration(seconds: -AppConstants.seekStep),
                    );
                  },
                  onDoubleTapRight: () {
                    _revealControls();
                    notifier.seekBy(
                      const Duration(seconds: AppConstants.seekStep),
                    );
                  },
                  onDoubleTapCenter: () {
                    _revealControls();
                    notifier.togglePlay();
                  },
                  onSeekDelta: (delta) {
                    _revealControls();
                    notifier.seekBy(delta);
                  },
                ),
                onGestureStateChanged: (gesture) {
                  if (!mounted) return;
                  setState(() => _gestureFeedback = gesture);
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),

        // ── Volume / brightness gesture feedback ─────────────
        if (!isYouTube &&
            _gestureFeedback.isVisible &&
            (_gestureFeedback.type == GestureType.brightness ||
                _gestureFeedback.type == GestureType.volume))
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: GestureFeedbackOverlay(
                      icon: _gestureFeedback.type == GestureType.brightness
                          ? (_gestureFeedback.value > 0.5
                                ? Icons.brightness_high
                                : Icons.brightness_low)
                          : (_gestureFeedback.value == 0
                                ? Icons.volume_off
                                : _gestureFeedback.value > 0.5
                                ? Icons.volume_up
                                : Icons.volume_down),
                      value: _gestureFeedback.value,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Buffering ─────────────────────────────────────────
        if (!isYouTube) BufferingIndicator(visible: state.buffering),

        // ── AB Repeat overlay ─────────────────────────────────
        if (!isYouTube && _controls && !state.isLocked && !state.isAudioOnly)
          ABRepeatOverlay(
            pointA: _abPointA,
            pointB: _abPointB,
            currentPosition: state.position,
            duration: state.duration,
            enabled: true,
            onSetA: (pos) => setState(() => _abPointA = pos),
            onSetB: (pos) => setState(() => _abPointB = pos),
            onClear: () => setState(() {
              _abPointA = null;
              _abPointB = null;
            }),
          ),

        // ── Playback stats overlay ────────────────────────────
        if (!isYouTube && _showStats && _controls)
          PlaybackStatsOverlay(
            resolution: '1920x1080',
            fps: '30',
            videoCodec: 'H.264',
            audioCodec: 'AAC',
            videoBitrate: 5000,
            droppedFrames: 0,
            hwDecoder: true,
            isVisible: true,
            onClose: () => setState(() => _showStats = false),
          ),

        // ── Controls overlay ──────────────────────────────────
        // Tap anywhere on the video (outside gesture detector) to toggle.
        if (!isYouTube && !state.isLocked)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              child: const SizedBox.expand(),
            ),
          ),
        if (!isYouTube && _controls && state.error == null) ...[
          _TopBar(
            title: state.title,
            onBack: () => context.pop(),
            onAudioTrackTap: () => _showAudioTrackSheet(state, notifier),
            onSubtitleTap: () => _showSubtitleSheet(state, notifier),
            onMoreTap: () => _showMoreOptions(state, notifier),
          ),
          if (!state.isAudioOnly && !state.isLocked)
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: PlayerActionRail(
                large: true,
                actions:
                    [
                      PlayerAction(
                        id: 'Speed',
                        icon: Icons.speed_rounded,
                        label: '${state.speed}x',
                        onTap: () => _showSpeedSheet(state, notifier),
                      ),
                      PlayerAction(
                        id: 'Screenshot',
                        icon: Icons.camera_alt_outlined,
                        label: 'Screenshot',
                        onTap: () => _takeScreenshot(notifier),
                      ),
                      PlayerAction(
                        id: 'Background Play',
                        icon: Icons.headphones_rounded,
                        label: 'Audio only',
                        onTap: notifier.toggleAudioOnly,
                      ),
                      PlayerAction(
                        id: 'Screen Rotation',
                        icon: _rotationLocked
                            ? Icons.screen_lock_rotation
                            : Icons.screen_rotation,
                        label: 'Rotate',
                        active: _rotationLocked,
                        onTap: _toggleRotationLock,
                      ),
                      PlayerAction(
                        id: 'Loop',
                        icon: Icons.repeat_rounded,
                        label: 'Loop',
                        active: _loopVideo,
                        onTap: () {
                          final enabled = !_loopVideo;
                          setState(() => _loopVideo = enabled);
                          notifier.player.setPlaylistMode(
                            enabled ? PlaylistMode.single : PlaylistMode.none,
                          );
                        },
                      ),
                      PlayerAction(
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        onTap: () => _showMoreOptions(state, notifier),
                      ),
                    ].where((action) {
                      final id = action.id ?? action.label;
                      return !_hiddenPlayerActions.contains(id);
                    }).toList(),
              ),
            ),
          _BottomControls(
            state: state,
            onSeek: notifier.seek,
            onPreviousTap: notifier.player.previous,
            onNextTap: notifier.player.next,
            onTogglePlay: notifier.togglePlay,
            onLockTap: notifier.toggleLock,
            onAspectRatioTap: _showAspectRatioSheet,
            onFullscreenTap: () => _toggleFullscreen(state, notifier),
          ),
        ],

        // ── Lock button ───────────────────────────────────────
        if (!isYouTube && state.isLocked)
          Positioned(
            top: UIHelper.spaceMD,
            right: UIHelper.spaceMD,
            child: FloatingActionButton.small(
              onPressed: notifier.toggleLock,
              child: const Icon(Icons.lock),
            ),
          ),
      ],
    );

    return playerSurface;
  }

  // ── Speed sheet ─────────────────────────────────────────────
  void _showSpeedSheet(VideoPlayerState state, VideoPlayerNotifier notifier) {
    SpeedSheet.show(context, currentSpeed: state.speed).then((speed) {
      if (speed != null) notifier.setSpeed(speed);
      _startHideTimer();
    });
  }

  void _showVolumeBoost(VideoPlayerState state, VideoPlayerNotifier notifier) {
    VolumeBoostSheet.show(
      context,
      currentVolume: state.volume,
      onChanged: notifier.setVolume,
    ).whenComplete(_startHideTimer);
  }

  // ── Subtitle sheet ──────────────────────────────────────────
  void _showSubtitleSheet(
    VideoPlayerState state,
    VideoPlayerNotifier notifier,
  ) {
    UIHelper.showAppBottomSheet(
      context,
      title: 'Subtitles',
      child: SubtitleSheet(
        tracks: state.subtitleTracks,
        selected: state.selectedSubtitle,
        onSelected: (track) {
          notifier.selectSubtitle(track);
          Navigator.pop(context);
          _startHideTimer();
        },
      ),
    );
  }

  // ── Audio track sheet ───────────────────────────────────────
  void _showAudioTrackSheet(
    VideoPlayerState state,
    VideoPlayerNotifier notifier,
  ) {
    UIHelper.showAppBottomSheet(
      context,
      title: 'Audio Track',
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final track in state.audioTracks)
            ListTile(
              title: Text(
                track.title ??
                    track.language ??
                    'Track ${state.audioTracks.indexOf(track) + 1}',
              ),
              trailing: track == state.selectedAudio
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                notifier.selectAudio(track);
                Navigator.pop(context);
                _startHideTimer();
              },
            ),
          if (state.audioTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No additional audio tracks found'),
            ),
        ],
      ),
    );
  }

  void _showSubtitleDelaySheet() {
    SubtitleDelaySheet.show(
      context,
      currentDelay: _subtitleDelay,
      onDelayChanged: (delay) {
        setState(() => _subtitleDelay = delay);
        _startHideTimer();
      },
    );
  }

  void _showAspectRatioSheet() {
    AspectRatioSheet.show(
      context,
      current: _aspectRatio,
      onSelected: (ratio) {
        setState(() => _aspectRatio = ratio);
        _startHideTimer();
      },
    );
  }

  // ── More options bottom sheet ───────────────────────────────
  void _showMoreOptions(VideoPlayerState state, VideoPlayerNotifier notifier) {
    UIHelper.showAppBottomSheet(
      context,
      title: 'More Options',
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: Text('Playback speed (${state.speed}x)'),
            onTap: () {
              Navigator.pop(context);
              _showSpeedSheet(state, notifier);
            },
          ),
          ListTile(
            leading: Icon(
              state.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            title: Text(state.fullscreen ? 'Exit fullscreen' : 'Fullscreen'),
            onTap: () {
              Navigator.pop(context);
              _toggleFullscreen(state, notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.aspect_ratio_rounded),
            title: const Text('Aspect ratio'),
            onTap: () {
              Navigator.pop(context);
              _showAspectRatioSheet();
            },
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('Subtitles'),
            onTap: () {
              Navigator.pop(context);
              _showSubtitleSheet(state, notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note_rounded),
            title: const Text('Audio track'),
            onTap: () {
              Navigator.pop(context);
              _showAudioTrackSheet(state, notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Playlist'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRouter.queue);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Sleep timer'),
            onTap: () {
              Navigator.pop(context);
              _showVideoSleepTimer(notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.screen_lock_rotation),
            title: const Text('Lock controls'),
            onTap: () {
              Navigator.pop(context);
              notifier.toggleLock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_up_rounded),
            title: const Text('Volume boost'),
            onTap: () {
              Navigator.pop(context);
              _showVolumeBoost(state, notifier);
            },
          ),
          ListTile(
            leading: Icon(
              state.volume == 0 ? Icons.volume_off : Icons.volume_up,
            ),
            title: Text(state.volume == 0 ? 'Unmute' : 'Mute'),
            onTap: () {
              Navigator.pop(context);
              notifier.toggleMute();
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat_rounded),
            title: const Text('A–B repeat'),
            subtitle: Text(
              _abPointA == null
                  ? 'Set repeat start'
                  : _abPointB == null
                  ? 'Set repeat end'
                  : 'Clear repeat points',
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                if (_abPointA == null) {
                  _abPointA = state.position;
                } else if (_abPointB == null) {
                  _abPointB = state.position;
                } else {
                  _abPointA = null;
                  _abPointB = null;
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.screen_rotation_rounded),
            title: const Text('Screen rotation lock'),
            onTap: () {
              Navigator.pop(context);
              _toggleRotationLock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.spatial_audio_outlined),
            title: const Text('Audio effects'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRouter.audioEffects);
            },
          ),
          ListTile(
            leading: const Icon(Icons.equalizer_rounded),
            title: const Text('Equalizer'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRouter.equalizer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.nightlight_round),
            title: Text(_nightMode ? 'Turn night mode off' : 'Night mode'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _nightMode = !_nightMode);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded),
            title: const Text('Shuffle'),
            onTap: () {
              Navigator.pop(context);
              _toggleShuffle(state, notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat_rounded),
            title: Text(_loopVideo ? 'Turn loop off' : 'Loop video'),
            onTap: () {
              Navigator.pop(context);
              final enabled = !_loopVideo;
              setState(() => _loopVideo = enabled);
              notifier.player.setPlaylistMode(
                enabled ? PlaylistMode.single : PlaylistMode.none,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.headphones),
            title: const Text('Play as Audio'),
            subtitle: const Text('Switch to audio-only playback'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to audio player with same URI
              context.push(
                AppRouter.audioPlayer,
                extra: {'uri': widget.uri, 'title': widget.title},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Save Audio File'),
            subtitle: const Text('Copy video as audio file'),
            onTap: () {
              Navigator.pop(context);
              _saveAudioFile(state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: const Text('Video Filters'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRouter.videoFilters);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Add Bookmark'),
            onTap: () {
              Navigator.pop(context);
              _showBookmarkSheet(state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Screenshot'),
            onTap: () {
              Navigator.pop(context);
              _takeScreenshot(notifier);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Subtitle Delay'),
            onTap: () {
              Navigator.pop(context);
              _showSubtitleDelaySheet();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              SharePlus.instance.share(ShareParams(text: state.title));
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Playback Statistics'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _showStats = true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Media Info'),
            onTap: () {
              Navigator.pop(context);
              _showMediaInfo(state);
            },
          ),
        ],
      ),
    );
  }

  void _showVideoSleepTimer(VideoPlayerNotifier notifier) {
    SleepTimerSheet.show(
      context,
      currentDuration: _sleepTimerDuration,
      onSelected: (duration) {
        _sleepTimer?.cancel();
        _sleepTimerDuration = duration;
        if (duration != null) {
          _sleepTimer = Timer(duration, () {
            if (!mounted) return;
            if (notifier.player.state.playing) notifier.togglePlay();
            setState(() => _sleepTimerDuration = null);
          });
        }
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _showCustomizeItems() async {
    const labels = [
      'Night Mode',
      'Shuffle',
      'Mute',
      'Volume Boost',
      'A - B Repeat',
      'Sleep Timer',
      'Audio Effect',
      'Equalizer',
      'Speed',
      'Screenshot',
      'Background Play',
      'Screen Rotation',
      'Subtitles',
      'Loop',
      'More',
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: ListView(
              children: [
                const ListTile(
                  title: Text('Customize player controls'),
                  subtitle: Text(
                    'Choose which actions appear in the control row.',
                  ),
                ),
                for (final label in labels)
                  CheckboxListTile(
                    value: !_hiddenPlayerActions.contains(label),
                    title: Text(label),
                    onChanged: (visible) {
                      setSheetState(() {
                        if (visible == true) {
                          _hiddenPlayerActions.remove(label);
                        } else {
                          _hiddenPlayerActions.add(label);
                        }
                      });
                      if (mounted) setState(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleShuffle(
    VideoPlayerState state,
    VideoPlayerNotifier notifier,
  ) async {
    final enable = !_shuffleEnabled;
    if (enable) {
      final videos = await ref.read(mediaRepositoryProvider).getVideos();
      if (videos.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add more videos to use Shuffle.')),
          );
        }
        return;
      }
      final playlist = videos.map((item) => Media(item.uri)).toList();
      var index = videos.indexWhere((item) => item.uri == widget.uri);
      if (index < 0) {
        playlist.insert(0, Media(widget.uri));
        index = 0;
      }
      await notifier.player.open(
        Playlist(playlist, index: index),
        play: state.playing,
      );
      notifier.seek(state.position);
    }
    await notifier.player.setShuffle(enable);
    if (mounted) setState(() => _shuffleEnabled = enable);
  }

  void _showBookmarkSheet(VideoPlayerState state) {
    AddBookmarkSheet.show(
      context,
      currentPosition: state.position,
      onConfirm: (title) async {
        final mediaRepo = ref.read(mediaRepositoryProvider);
        final items = await mediaRepo.search(widget.title);
        final match = items.isNotEmpty ? items.first : null;
        if (match?.id != null) {
          final bookmarksNotifier = ref.read(bookmarksProvider.notifier);
          await bookmarksNotifier.add(
            mediaId: match!.id!,
            positionMs: state.position.inMilliseconds,
            title: title,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bookmark saved at ${state.position.inSeconds}s'),
              ),
            );
          }
        }
        _startHideTimer();
      },
    );
  }

  void _showMediaInfo(VideoPlayerState state) {
    MediaInfoSheet.show(
      context,
      title: state.title,
      duration: state.duration,
      resolution: '1920x1080',
      videoCodec: 'H.264',
      audioCodec: 'AAC',
      bitrate: 5000,
    );
  }

  // ── Save audio file ──────────────────────────────────────
  Future<void> _saveAudioFile(VideoPlayerState state) async {
    try {
      final sourcePath = widget.uri;
      if (sourcePath.isEmpty || sourcePath.startsWith('http')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot save audio from network stream'),
            ),
          );
        }
        return;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Source file not found')),
          );
        }
        return;
      }

      // Determine output path with audio extension
      final lastDot = sourcePath.lastIndexOf('.');
      final baseName = lastDot > 0
          ? sourcePath.substring(0, lastDot)
          : sourcePath;
      final outputPath = '$baseName.m4a';

      // Copy the file (same container, just renamed as audio)
      await sourceFile.copy(outputPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Audio saved: ${outputPath.split(RegExp(r'[/\\]')).last}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save audio: $e')));
      }
    }
    _startHideTimer();
  }

  Future<void> _takeScreenshot(VideoPlayerNotifier notifier) async {
    final path = await ScreenshotHelper.captureVideoFrame(
      notifier.videoController,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'Screenshot saved' : 'Screenshot failed',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _startHideTimer();
  }
}

// ─── Watch page (YouTube-style details under the player) ────────────────

class _WatchDetails extends ConsumerStatefulWidget {
  const _WatchDetails({
    required this.result,
    required this.recommendations,
    required this.onSave,
    required this.onPlayAudio,
    required this.onPopup,
  });
  final WebResult result;
  final List<WebResult> recommendations;
  final VoidCallback onSave;
  final VoidCallback onPlayAudio;
  final VoidCallback onPopup;

  @override
  ConsumerState<_WatchDetails> createState() => _WatchDetailsState();
}

class _WatchDetailsState extends ConsumerState<_WatchDetails> {
  bool _liked = false;
  bool _disliked = false;
  List<WebResult>? _related;
  bool _loadingRelated = false;

  @override
  void initState() {
    super.initState();
    final seeded = widget.recommendations
        .where((v) => v.id != widget.result.id && v.kind == WebResultKind.video)
        .toList();
    if (seeded.isNotEmpty) {
      _related = seeded;
    } else {
      _loadRelated();
    }
  }

  Future<void> _loadRelated() async {
    if (_loadingRelated) return;
    setState(() => _loadingRelated = true);
    try {
      final service = ref.read(webSearchServiceProvider);
      if (!service.hasYouTube) {
        setState(() {
          _related = const [];
          _loadingRelated = false;
        });
        return;
      }
      final q = widget.result.title.split('|').first.trim();
      final videos = await service.youtube(
        q.isEmpty ? widget.result.title : q,
        type: 'video',
        max: 12,
        enrich: false,
      );
      if (!mounted) return;
      setState(() {
        _related = videos.where((v) => v.id != widget.result.id).toList();
        _loadingRelated = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _related = const [];
        _loadingRelated = false;
      });
    }
  }

  String _relativeAge(DateTime? date) {
    if (date == null) return '';
    final d = DateTime.now().difference(date);
    if (d.inDays >= 365) {
      final y = d.inDays ~/ 365;
      return y == 1 ? '1 year ago' : '$y years ago';
    }
    if (d.inDays >= 30) {
      final m = d.inDays ~/ 30;
      return m == 1 ? '1 month ago' : '$m months ago';
    }
    if (d.inDays >= 7) {
      final w = d.inDays ~/ 7;
      return w == 1 ? '1 week ago' : '$w weeks ago';
    }
    if (d.inDays >= 1) {
      return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
    }
    if (d.inHours >= 1) return '${d.inHours} hours ago';
    return 'Just now';
  }

  Future<void> _shareWhatsApp(String url) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(url)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await SharePlus.instance.share(ShareParams(text: url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final channel = result.subtitle ?? 'YouTube';
    final age = _relativeAge(result.publishedAt);
    final meta = age.isEmpty ? channel : '$channel · $age';
    final related = _related;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          // Title + like / dislike
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: result.thumbnailUrl == null
                    ? null
                    : NetworkImage(result.thumbnailUrl!),
                child: result.thumbnailUrl == null
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LikeDislikePill(
                liked: _liked,
                disliked: _disliked,
                onLike: () => setState(() {
                  _liked = !_liked;
                  if (_liked) _disliked = false;
                }),
                onDislike: () => setState(() {
                  _disliked = !_disliked;
                  if (_disliked) _liked = false;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WatchAction(
                icon: Icons.library_add_outlined,
                label: 'Save',
                onTap: widget.onSave,
              ),
              _WatchAction(
                icon: Icons.picture_in_picture_alt_outlined,
                label: 'Popup',
                onTap: widget.onPopup,
              ),
              _WatchAction(
                icon: Icons.headphones_outlined,
                label: 'Play Audio',
                onTap: widget.onPlayAudio,
              ),
              _WatchAction(
                label: 'Share',
                onTap: () => _shareWhatsApp(result.url),
                child: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF25D366),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              _WatchAction(
                label: 'Download',
                onTap: () => showDownloadOptionsSheet(context, result),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE53935),
                  child: Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Comments
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.65,
            ),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => launchUrl(
                Uri.parse(result.url),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Comments · 1.8K',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.expand_more,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Open on YouTube to view comments…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Related videos
          if (_loadingRelated)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (related != null && related.isNotEmpty)
            for (final video in related)
              _RecommendedVideo(video: video, recommendations: related),
        ],
      ),
    );
  }
}

class _LikeDislikePill extends StatelessWidget {
  const _LikeDislikePill({
    required this.liked,
    required this.disliked,
    required this.onLike,
    required this.onDislike,
  });
  final bool liked;
  final bool disliked;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onLike,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    liked ? 'Liked' : 'Like',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 20, color: theme.dividerColor),
          InkWell(
            onTap: onDislike,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchAction extends StatelessWidget {
  const _WatchAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.child,
  });
  final IconData? icon;
  final Widget? child;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: Center(child: child ?? Icon(icon, size: 26)),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

class _RecommendedVideo extends StatelessWidget {
  const _RecommendedVideo({required this.video, required this.recommendations});
  final WebResult video;
  final List<WebResult> recommendations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: () => context.push(
          AppRouter.videoPlayer,
          extra: {
            'uri': video.url,
            'title': video.title,
            'webResult': video,
            'recommendations': recommendations,
          },
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    video.thumbnailUrl == null
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.play_circle_outline,
                              size: 48,
                            ),
                          )
                        : Image.network(
                            video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.play_circle_outline,
                                size: 48,
                              ),
                            ),
                          ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 56,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Video',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: video.thumbnailUrl == null
                      ? null
                      : NetworkImage(video.thumbnailUrl!),
                  child: video.thumbnailUrl == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.subtitle ?? 'YouTube',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Download',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showDownloadOptionsSheet(context, video),
                  icon: Icon(
                    Icons.download_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  tooltip: 'More',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.open_in_new),
                            title: const Text('Open on YouTube'),
                            onTap: () {
                              Navigator.pop(ctx);
                              launchUrl(
                                Uri.parse(video.url),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.share_outlined),
                            title: const Text('Share'),
                            onTap: () {
                              Navigator.pop(ctx);
                              SharePlus.instance.share(
                                ShareParams(text: video.url),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onAudioTrackTap;
  final VoidCallback onSubtitleTap;
  final VoidCallback onMoreTap;

  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onAudioTrackTap,
    required this.onSubtitleTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(gradient: UIHelper.topGradient()),
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Audio tracks',
              icon: const Icon(Icons.music_note_rounded, color: Colors.white),
              onPressed: onAudioTrackTap,
            ),
            IconButton(
              tooltip: 'Subtitles',
              icon: const Icon(Icons.subtitles_rounded, color: Colors.white),
              onPressed: onSubtitleTap,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hd_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 2),
                  Text(
                    'HW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Controls ────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final VideoPlayerState state;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPreviousTap;
  final VoidCallback onNextTap;
  final VoidCallback onTogglePlay;
  final VoidCallback onLockTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback onFullscreenTap;

  const _BottomControls({
    required this.state,
    required this.onSeek,
    required this.onPreviousTap,
    required this.onNextTap,
    required this.onTogglePlay,
    required this.onLockTap,
    required this.onAspectRatioTap,
    required this.onFullscreenTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(gradient: UIHelper.bottomGradient()),
        child: Column(
          children: [
            PlayerProgressBar(
              position: state.position,
              duration: state.duration,
              onSeek: onSeek,
              activeColor: Colors.lightBlueAccent,
              thumbColor: Colors.lightBlueAccent,
              inactiveColor: Colors.white.withValues(alpha: 0.28),
            ),
            SizedBox(
              width: double.infinity,
              child: ColoredBox(
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ControlButton(
                      icon: state.isLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      onTap: onLockTap,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: Icons.skip_previous_rounded,
                          onTap: onPreviousTap,
                        ),
                        PlayPauseButton(
                          playing: state.playing,
                          onToggle: onTogglePlay,
                          size: 54,
                        ),
                        _ControlButton(
                          icon: Icons.skip_next_rounded,
                          onTap: onNextTap,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: Icons.aspect_ratio_rounded,
                          onTap: onAspectRatioTap,
                        ),
                        _ControlButton(
                          icon: state.fullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          onTap: onFullscreenTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _AudioOnlyOverlay extends StatelessWidget {
  final String title;
  final bool playing;
  final Duration position;
  final Duration duration;

  const _AudioOnlyOverlay({
    required this.title,
    required this.playing,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing music icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: playing ? 40 : 20,
                    spreadRadius: playing ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                playing ? Icons.music_note_rounded : Icons.music_note_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Audio-only label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Audio Only',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Position info
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorOverlay({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UIHelper.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            UIHelper.vMD,
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            UIHelper.vMD,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
