import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/sleep_timer_service.dart';
import '../../../../shared/widgets/player_controls.dart';
import '../../../../shared/widgets/poster_image.dart';
import '../../../../shared/widgets/sleep_timer_sheet.dart';
import '../../../../shared/widgets/speed_sheet.dart';
import '../../../../shared/widgets/volume_boost_sheet.dart';
import '../controllers/audio_controller.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String uri;
  final String title;
  final String? artist;
  final String? artworkPath;
  final int positionMs;

  const AudioPlayerScreen({
    super.key,
    required this.uri,
    required this.title,
    this.artist,
    this.artworkPath,
    this.positionMs = 0,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  final _sleepTimer = SleepTimerService();
  late AnimationController _visualizerController;
  bool _nightMode = false;
  bool _rotationLocked = false;
  Duration? _repeatPointA;
  Duration? _repeatPointB;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;
  final Set<String> _hiddenAudioActions = {};

  @override
  void initState() {
    super.initState();
    // Allow all orientations — landscape-only open caused a black dead screen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _rotationLocked = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startControlsHideTimer();
    });
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    SystemChrome.setPreferredOrientations([]);
    _visualizerController.dispose();
    _sleepTimer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = AudioPlayerArgs(
      widget.uri,
      widget.title,
      widget.artist,
      widget.positionMs,
    );
    final provider = audioPlayerControllerProvider(args);
    final asyncState = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    ref.listen(provider, (previous, next) {
      final wasPlaying = previous?.asData?.value.playing == true;
      final state = next.asData?.value;
      if (state == null) return;
      if (state.playing && !state.buffering && !wasPlaying) {
        _revealControls();
      } else if (!state.playing && mounted && !_controlsVisible) {
        setState(() => _controlsVisible = true);
        _controlsHideTimer?.cancel();
      }
    });
    final theme = Theme.of(context);

    final current = asyncState.asData?.value;
    if (current != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _revealControls(),
          child: SafeArea(
            child: _buildReferenceAudioDisplay(context, current, notifier),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorContent(message: e.toString(), onRetry: notifier.retry),
        data: (state) => state.error != null
            ? _ErrorContent(message: state.error!, onRetry: notifier.retry)
            : Theme(
                data: theme.copyWith(brightness: Brightness.dark),
                child: Padding(
                  padding: UIHelper.screenPadding,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              state.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Queue',
                            onPressed: () => context.push(AppRouter.queue),
                            icon: const Icon(
                              Icons.queue_music,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      PlayerActionRail(
                        actions: [
                          PlayerAction(
                            icon: state.shuffleEnabled
                                ? Icons.shuffle_on
                                : Icons.shuffle,
                            label: 'Shuffle',
                            active: state.shuffleEnabled,
                            onTap: notifier.toggleShuffle,
                          ),
                          PlayerAction(
                            icon: state.volume == 0
                                ? Icons.volume_off
                                : Icons.volume_up,
                            label: state.volume == 0 ? 'Unmute' : 'Mute',
                            active: state.volume == 0,
                            onTap: notifier.toggleMute,
                          ),
                          PlayerAction(
                            icon: state.volume > 100
                                ? Icons.surround_sound_rounded
                                : Icons.volume_up_rounded,
                            id: 'Volume Boost',
                            label: state.volume > 100
                                ? 'Boost ${state.volume.round()}%'
                                : 'Volume ${state.volume.round()}%',
                            active: state.volume > 100,
                            onTap: () => _showVolumeBoost(state, notifier),
                          ),
                          PlayerAction(
                            icon: Icons.timer_outlined,
                            label: 'Sleep Timer',
                            active: state.sleepTimerRemaining != null,
                            onTap: _showSleepTimer,
                          ),
                          PlayerAction(
                            icon: state.repeatMode == AudioRepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            label: 'Repeat',
                            active: state.repeatMode != AudioRepeatMode.off,
                            onTap: notifier.cycleRepeat,
                          ),
                          PlayerAction(
                            icon: Icons.spatial_audio_outlined,
                            label: 'Audio Effect',
                            onTap: () => context.push(AppRouter.audioEffects),
                          ),
                          PlayerAction(
                            icon: Icons.equalizer_rounded,
                            label: 'Equalizer',
                            onTap: () => context.push(AppRouter.equalizer),
                          ),
                          PlayerAction(
                            icon: Icons.speed_rounded,
                            label: '${state.speed}x Speed',
                            onTap: _showSpeedSheet,
                          ),
                        ],
                      ),
                      // ── Audio visualizer / Album art ──────────────────────
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                UIHelper.radiusLG,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PosterImage(
                                    path: widget.artworkPath,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: Icons.album_rounded,
                                  ),
                                  if (state.playing)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        height: 110,
                                        alignment: Alignment.bottomCenter,
                                        padding: const EdgeInsets.only(
                                          bottom: 18,
                                        ),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black54,
                                            ],
                                          ),
                                        ),
                                        child: _AudioVisualizer(
                                          controller: _visualizerController,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      UIHelper.vLG,

                      // ── Title & artist ───────────────────────────────────
                      UIHelper.ellipsisText(
                        state.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (state.artist != null)
                        UIHelper.ellipsisText(
                          state.artist!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      UIHelper.vMD,

                      // ── Seek bar ─────────────────────────────────────────
                      PlayerProgressBar(
                        position: state.position,
                        duration: state.duration,
                        onSeek: notifier.seek,
                      ),
                      UIHelper.vMD,

                      // ── Main controls ────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionIconButton(
                            icon: Icons.replay_10,
                            onTap: () =>
                                notifier.seekBy(const Duration(seconds: -10)),
                          ),
                          const SizedBox(width: 16),
                          PlayPauseButton(
                            playing: state.playing,
                            onToggle: notifier.togglePlay,
                            size: 64,
                          ),
                          const SizedBox(width: 16),
                          _ActionIconButton(
                            icon: Icons.forward_10,
                            onTap: () =>
                                notifier.seekBy(const Duration(seconds: 10)),
                          ),
                        ],
                      ),
                      UIHelper.vSM,

                      // ── Primary controls row ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Favorite
                          _SmallIconButton(
                            icon: state.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: state.isFavorite ? Colors.redAccent : null,
                            onTap: () async {
                              final items = await ref
                                  .read(mediaRepositoryProvider)
                                  .search(widget.uri.split('/').last);
                              final matches = items.where(
                                (m) => m.uri == widget.uri,
                              );
                              final id = matches.isEmpty
                                  ? null
                                  : matches.first.id;
                              if (id != null && mounted) {
                                notifier.toggleFavorite(id);
                              }
                            },
                            tooltip: 'Favorite',
                          ),
                          // Shuffle
                          _SmallIconButton(
                            icon: Icons.shuffle,
                            color: state.shuffleEnabled
                                ? theme.colorScheme.primary
                                : null,
                            onTap: notifier.toggleShuffle,
                            tooltip: 'Shuffle',
                          ),
                          // Repeat
                          _SmallIconButton(
                            icon: state.repeatMode == AudioRepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: state.repeatMode != AudioRepeatMode.off
                                ? theme.colorScheme.primary
                                : null,
                            onTap: notifier.cycleRepeat,
                            tooltip: state.repeatMode == AudioRepeatMode.one
                                ? 'Repeat one'
                                : state.repeatMode == AudioRepeatMode.all
                                ? 'Repeat all'
                                : 'Repeat off',
                          ),
                          // Sleep timer
                          _SmallIconButton(
                            icon: Icons.timer_outlined,
                            onTap: _showSleepTimer,
                            tooltip: 'Sleep timer',
                          ),
                          // Share
                          _SmallIconButton(
                            icon: Icons.share_outlined,
                            onTap: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    '${state.title}${state.artist != null ? ' - ${state.artist}' : ''}',
                              ),
                            ),
                            tooltip: 'Share',
                          ),
                        ],
                      ),
                      UIHelper.vXS,

                      // ── Secondary controls row ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Speed
                          _FeatureButton(
                            icon: Icons.speed,
                            label: '${state.speed}x',
                            onTap: _showSpeedSheet,
                          ),
                          // Equalizer
                          _FeatureButton(
                            icon: Icons.equalizer,
                            label: 'EQ',
                            onTap: () => context.push(AppRouter.equalizer),
                          ),
                          // Audio Effects
                          _FeatureButton(
                            icon: Icons.spatial_audio_outlined,
                            label: 'Effects',
                            onTap: () => context.push(AppRouter.audioEffects),
                          ),
                        ],
                      ),

                      // ── Volume + boost slider (0–200%) ────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIHelper.spaceSM,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state.volume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_down,
                              size: 20,
                              color: state.volume > 100
                                  ? Theme.of(context).colorScheme.tertiary
                                  : null,
                            ),
                            Expanded(
                              child: Slider(
                                value: state.volume.clamp(
                                  0,
                                  AppConstants.volumeBoostMax,
                                ),
                                max: AppConstants.volumeBoostMax,
                                divisions: 40,
                                label: '${state.volume.round()}%',
                                onChanged: notifier.setVolume,
                              ),
                            ),
                            Icon(
                              state.volume > 100
                                  ? Icons.surround_sound_rounded
                                  : Icons.volume_up,
                              size: 20,
                              color: state.volume > 100
                                  ? Theme.of(context).colorScheme.tertiary
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${state.volume.round()}%',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: state.volume > 100
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.tertiary
                                          : null,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _isActivelyPlaying() {
    final value = ref
        .read(
          audioPlayerControllerProvider(
            AudioPlayerArgs(
              widget.uri,
              widget.title,
              widget.artist,
              widget.positionMs,
            ),
          ),
        )
        .asData
        ?.value;
    return value != null && value.playing && !value.buffering;
  }

  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel();
    if (!_isActivelyPlaying()) return;
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isActivelyPlaying()) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _revealControls() {
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startControlsHideTimer();
  }

  Widget _buildReferenceAudioDisplay(
    BuildContext context,
    AudioPlayerState state,
    AudioPlayerNotifier notifier,
  ) {
    if (state.error != null) {
      return _ErrorContent(message: state.error!, onRetry: notifier.retry);
    }
    if (_repeatPointA != null &&
        _repeatPointB != null &&
        state.position >= _repeatPointB!) {
      notifier.seek(_repeatPointA!);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: PosterImage(
            path: widget.artworkPath,
            width: double.infinity,
            height: double.infinity,
            placeholder: Icons.album_rounded,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.black26, Colors.black87],
                stops: [0, .48, 1],
              ),
            ),
          ),
        ),
        if (_nightMode)
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x28FF6D00))),
          ),
        if (state.buffering)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
        if (_controlsVisible)
          Positioned(
            top: 0,
            left: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    state.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Queue',
                  onPressed: () => context.push(AppRouter.queue),
                  icon: const Icon(Icons.queue_music, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => context.push(AppRouter.audioEffects),
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                ),
              ],
            ),
          ),
        if (_controlsVisible)
          Positioned(
            top: 76,
            left: 0,
            right: 0,
            child: PlayerActionRail(
              actions:
                  [
                        PlayerAction(
                          icon: Icons.nightlight_round,
                          label: 'Night Mode',
                          active: _nightMode,
                          onTap: () => setState(() => _nightMode = !_nightMode),
                        ),
                        PlayerAction(
                          icon: Icons.tune_rounded,
                          label: 'Customize Items',
                          onTap: _showCustomizeAudioItems,
                        ),
                        PlayerAction(
                          icon: state.shuffleEnabled
                              ? Icons.shuffle_on
                              : Icons.shuffle,
                          label: 'Shuffle',
                          active: state.shuffleEnabled,
                          onTap: notifier.toggleShuffle,
                        ),
                        PlayerAction(
                          icon: state.volume == 0
                              ? Icons.volume_off
                              : Icons.volume_up,
                          id: 'Mute',
                          label: state.volume == 0 ? 'Unmute' : 'Mute',
                          active: state.volume == 0,
                          onTap: notifier.toggleMute,
                        ),
                        PlayerAction(
                          icon: state.volume > 100
                              ? Icons.surround_sound_rounded
                              : Icons.volume_up_rounded,
                          id: 'Volume Boost',
                          label: state.volume > 100
                              ? 'Boost ${state.volume.round()}%'
                              : 'Volume ${state.volume.round()}%',
                          active: state.volume > 100,
                          onTap: () => _showVolumeBoost(state, notifier),
                        ),
                        PlayerAction(
                          icon: Icons.timer_outlined,
                          label: 'Sleep Timer',
                          active: state.sleepTimerRemaining != null,
                          onTap: _showSleepTimer,
                        ),
                        PlayerAction(
                          icon: Icons.repeat,
                          label: 'A - B Repeat',
                          active: _repeatPointA != null,
                          onTap: () => setState(() {
                            if (_repeatPointA == null) {
                              _repeatPointA = state.position;
                            } else if (_repeatPointB == null) {
                              _repeatPointB = state.position;
                            } else {
                              _repeatPointA = null;
                              _repeatPointB = null;
                            }
                          }),
                        ),
                        PlayerAction(
                          icon: state.repeatMode == AudioRepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          label: 'Loop',
                          id: 'Loop',
                          active: state.repeatMode != AudioRepeatMode.off,
                          onTap: notifier.cycleRepeat,
                        ),
                        PlayerAction(
                          icon: Icons.spatial_audio_outlined,
                          label: 'Audio Effect',
                          onTap: () => context.push(AppRouter.audioEffects),
                        ),
                        PlayerAction(
                          icon: Icons.equalizer_rounded,
                          label: 'Equalizer',
                          onTap: () => context.push(AppRouter.equalizer),
                        ),
                        PlayerAction(
                          icon: Icons.speed_rounded,
                          label: '${state.speed}x Speed',
                          id: 'Speed',
                          onTap: _showSpeedSheet,
                        ),
                        PlayerAction(
                          icon: Icons.headphones_rounded,
                          label: 'Background Play',
                          onTap: () => context.pop(),
                        ),
                        PlayerAction(
                          icon: _rotationLocked
                              ? Icons.screen_lock_rotation
                              : Icons.screen_rotation,
                          label: 'Screen Rotation',
                          active: _rotationLocked,
                          onTap: () {
                            setState(() => _rotationLocked = !_rotationLocked);
                            SystemChrome.setPreferredOrientations(
                              _rotationLocked
                                  ? const [
                                      DeviceOrientation.landscapeLeft,
                                      DeviceOrientation.landscapeRight,
                                    ]
                                  : [],
                            );
                          },
                        ),
                      ]
                      .where(
                        (action) =>
                            action.label == 'Customize Items' ||
                            !_hiddenAudioActions.contains(
                              action.id ?? action.label,
                            ),
                      )
                      .toList(),
            ),
          ),
        if (state.playing)
          Positioned(
            left: 0,
            right: 0,
            bottom: 112,
            child: SizedBox(
              height: 54,
              child: _AudioVisualizer(
                controller: _visualizerController,
                color: Colors.white70,
              ),
            ),
          ),
        if (_controlsVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PlayerProgressBar(
                    position: state.position,
                    duration: state.duration,
                    onSeek: notifier.seek,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.lock_open,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  notifier.seekBy(const Duration(seconds: -10)),
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            PlayPauseButton(
                              playing: state.playing,
                              onToggle: notifier.togglePlay,
                              size: 54,
                            ),
                            IconButton(
                              onPressed: () =>
                                  notifier.seekBy(const Duration(seconds: 10)),
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Queue',
                          onPressed: () => context.push(AppRouter.queue),
                          icon: const Icon(
                            Icons.queue_music,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showCustomizeAudioItems() async {
    const labels = [
      'Night Mode',
      'Shuffle',
      'Mute',
      'Volume Boost',
      'Sleep Timer',
      'A - B Repeat',
      'Audio Effect',
      'Equalizer',
      'Speed',
      'Background Play',
      'Screen Rotation',
      'Loop',
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
                    value: !_hiddenAudioActions.contains(label),
                    title: Text(label),
                    onChanged: (visible) {
                      setSheetState(() {
                        if (visible == true) {
                          _hiddenAudioActions.remove(label);
                        } else {
                          _hiddenAudioActions.add(label);
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

  void _showSpeedSheet() {
    final provider = audioPlayerControllerProvider(
      AudioPlayerArgs(
        widget.uri,
        widget.title,
        widget.artist,
        widget.positionMs,
      ),
    );
    final asyncState = ref.read(provider);
    final notifier = ref.read(provider.notifier);
    asyncState.whenData((state) {
      SpeedSheet.show(context, currentSpeed: state.speed).then((speed) {
        if (speed != null) notifier.setSpeed(speed);
      });
    });
  }

  void _showVolumeBoost(
    AudioPlayerState state,
    AudioPlayerNotifier notifier,
  ) {
    VolumeBoostSheet.show(
      context,
      currentVolume: state.volume,
      onChanged: notifier.setVolume,
    );
  }

  void _showSleepTimer() {
    final provider = audioPlayerControllerProvider(
      AudioPlayerArgs(
        widget.uri,
        widget.title,
        widget.artist,
        widget.positionMs,
      ),
    );
    final notifier = ref.read(provider.notifier);
    final asyncState = ref.read(provider);
    asyncState.whenData((state) {
      SleepTimerSheet.show(
        context,
        currentDuration: state.sleepTimerRemaining,
        onSelected: (duration) {
          if (duration == null) {
            _sleepTimer.stop();
            notifier.clearSleepTimer();
          } else {
            notifier.setSleepTimer(duration);
            _sleepTimer.start(
              duration,
              onPause: () {
                notifier.clearSleepTimer();
                notifier.togglePlay(); // Pause playback
              },
            );
          }
        },
      );
    });
  }
}

// ─── Extracted sub-widgets ──────────────────────────────────────────────────

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorContent({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UIHelper.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            UIHelper.vMD,
            Text(message, textAlign: TextAlign.center),
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

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(iconSize: 36, icon: Icon(icon), onPressed: onTap);
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final String tooltip;

  const _SmallIconButton({
    required this.icon,
    this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ─── Audio Visualizer ──────────────────────────────────────────────────

class _AudioVisualizer extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _AudioVisualizer({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final phase = (controller.value + i * 0.12) % 1.0;
            final wave = _sinWave(phase, i);
            final height = 20.0 + 60.0 * (0.5 + 0.5 * wave);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6 + 0.4 * phase),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _sinWave(double phase, int index) {
    return sin(phase * 2 * pi) * (0.5 + 0.5 * ((index * 0.7 + 0.3) % 1.0));
  }
}
