import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcut mappings for tablet/keyboard devices.
/// Matches requirements doc §121.
///
/// Space       → Play/Pause
/// Arrow Left  → Seek Back
/// Arrow Right → Seek Forward
/// Arrow Up    → Volume Up
/// Arrow Down  → Volume Down
/// F           → Fullscreen
/// M           → Mute
/// S           → Subtitle
/// A           → Audio track
/// Esc         → Exit Fullscreen
class VideoKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSeekBack;
  final VoidCallback? onSeekForward;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMute;
  final VoidCallback? onSubtitle;
  final VoidCallback? onAudioTrack;
  final VoidCallback? onEscape;

  const VideoKeyboardShortcuts({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onFullscreen,
    this.onMute,
    this.onSubtitle,
    this.onAudioTrack,
    this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): _SeekBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): _VolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): _VolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): _FullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyM): _MuteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): _SubtitleIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyA): _AudioTrackIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
            onInvoke: (_) => onPlayPause?.call(),
          ),
          _SeekBackIntent: CallbackAction<_SeekBackIntent>(
            onInvoke: (_) => onSeekBack?.call(),
          ),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
            onInvoke: (_) => onSeekForward?.call(),
          ),
          _VolumeUpIntent: CallbackAction<_VolumeUpIntent>(
            onInvoke: (_) => onVolumeUp?.call(),
          ),
          _VolumeDownIntent: CallbackAction<_VolumeDownIntent>(
            onInvoke: (_) => onVolumeDown?.call(),
          ),
          _FullscreenIntent: CallbackAction<_FullscreenIntent>(
            onInvoke: (_) => onFullscreen?.call(),
          ),
          _MuteIntent: CallbackAction<_MuteIntent>(
            onInvoke: (_) => onMute?.call(),
          ),
          _SubtitleIntent: CallbackAction<_SubtitleIntent>(
            onInvoke: (_) => onSubtitle?.call(),
          ),
          _AudioTrackIntent: CallbackAction<_AudioTrackIntent>(
            onInvoke: (_) => onAudioTrack?.call(),
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) => onEscape?.call(),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

// ── Intent classes ──────────────────────────────────────────────────────

class _PlayPauseIntent extends Intent {}
class _SeekBackIntent extends Intent {}
class _SeekForwardIntent extends Intent {}
class _VolumeUpIntent extends Intent {}
class _VolumeDownIntent extends Intent {}
class _FullscreenIntent extends Intent {}
class _MuteIntent extends Intent {}
class _SubtitleIntent extends Intent {}
class _AudioTrackIntent extends Intent {}
class _EscapeIntent extends Intent {}
