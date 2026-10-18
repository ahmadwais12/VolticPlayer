import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Overlay that shows volume/brightness level or seek delta
/// during gesture interactions on the video player.
class GestureVolumeBrightnessOverlay extends StatelessWidget {
  final double volume;
  final double brightness;
  final Duration? seekDelta;
  final bool isVisible;

  const GestureVolumeBrightnessOverlay({
    super.key,
    this.volume = 0.5,
    this.brightness = 0.5,
    this.seekDelta,
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (seekDelta != null) {
      return _SeekFeedback(
        delta: seekDelta!,
        color: theme.colorScheme.primary,
      );
    }

    return Positioned(
      top: UIHelper.spaceXL,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UIHelper.spaceMD,
            vertical: UIHelper.spaceSM,
          ),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                brightness > 0.5 ? Icons.brightness_high : Icons.brightness_low,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                width: 4,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: brightness,
                    backgroundColor: Colors.white24,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekFeedback extends StatelessWidget {
  final Duration delta;
  final Color color;

  const _SeekFeedback({required this.delta, required this.color});

  @override
  Widget build(BuildContext context) {
    final seconds = delta.inSeconds;
    final prefix = seconds >= 0 ? '+' : '';
    final text = '$prefix${seconds}s';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UIHelper.spaceMD,
          vertical: UIHelper.spaceSM,
        ),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              seconds >= 0 ? Icons.fast_forward : Icons.fast_rewind,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Volume indicator shown on the right side during volume gestures.
class GestureVolumeIndicator extends StatelessWidget {
  final double volume;
  final bool isVisible;

  const GestureVolumeIndicator({
    super.key,
    this.volume = 0.5,
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      right: UIHelper.spaceXXL,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          width: 40,
          height: 140,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
          ),
          child: Column(
            children: [
              Icon(
                volume > 0
                    ? (volume > 0.5 ? Icons.volume_up : Icons.volume_down)
                    : Icons.volume_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: volume,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${(volume * 100).round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
