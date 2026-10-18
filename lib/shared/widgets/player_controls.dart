import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/utils/extensions.dart';

/// Shared playback progress slider used by video & audio players.
///
/// Supports precise scrubbing: press and drag the thumb / track left–right
/// to seek. While dragging, live position stream updates do not fight the
/// finger position.
class PlayerProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final live = widget.position.inMilliseconds
        .clamp(0, max == 0 ? 0 : max)
        .toDouble();
    final value = _dragValue ?? (max == 0 ? 0.0 : live);
    final display = Duration(milliseconds: value.round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              display.formatted,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor:
                    widget.activeColor ?? Theme.of(context).colorScheme.primary,
                inactiveTrackColor:
                    widget.inactiveColor ??
                    Colors.white.withValues(alpha: 0.28),
                thumbColor:
                    widget.thumbColor ?? Theme.of(context).colorScheme.primary,
                overlayColor:
                    (widget.thumbColor ?? Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.18),
              ),
              child: Slider(
                value: max == 0 ? 0 : value.clamp(0, max),
                max: max == 0 ? 1 : max,
                onChangeStart: (v) => setState(() => _dragValue = v),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  widget.onSeek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              widget.duration.formatted,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared play/pause icon button.
class PlayPauseButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onToggle;
  final double size;

  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onToggle,
    this.size = UIHelper.iconLG,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: size,
      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
      onPressed: onToggle,
    );
  }
}

class PlayerAction {
  final String? id;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const PlayerAction({
    this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
}

/// Scrollable round control strip used by the immersive video and audio
/// players. It stays usable on narrow screens while matching the landscape UI.
class PlayerActionRail extends StatelessWidget {
  final List<PlayerAction> actions;
  final bool large;

  const PlayerActionRail({
    super.key,
    required this.actions,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: large ? 112 : 102,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: actions.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final action = actions[index];
        return SizedBox(
          width: large ? 88 : 72,
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: large ? 30 : 22,
                  backgroundColor: action.active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black.withValues(alpha: large ? 0.48 : 0.12),
                  child: Icon(
                    action.icon,
                    color: Colors.white,
                    size: large ? 27 : 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
