import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/utils/extensions.dart';

/// A horizontal seek slider with time labels.
///
/// Shared between video and audio players for consistent seek behavior.
class PlayerSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? activeColor;
  final Color? inactiveColor;

  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final pos = position.inMilliseconds
        .clamp(0, max == 0 ? 0 : max)
        .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: activeColor,
            inactiveTrackColor: inactiveColor,
          ),
          child: Slider(
            value: max == 0 ? 0 : pos,
            max: max == 0 ? 1 : max,
            onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceMD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(position.formatted,
                  style: Theme.of(context).textTheme.labelSmall),
              Text(duration.formatted,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}
