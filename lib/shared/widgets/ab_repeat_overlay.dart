import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/ui_helper.dart';

/// AB Repeat controls — lets users set point A and point B
/// to loop a segment of video/audio.
///
/// Usage in player: wrap the player with this widget, and it will
/// manage the A/B state and emit seek callbacks.
class ABRepeatOverlay extends StatelessWidget {
  final Duration? pointA;
  final Duration? pointB;
  final Duration currentPosition;
  final Duration duration;
  final ValueChanged<Duration?> onSetA;
  final ValueChanged<Duration?> onSetB;
  final VoidCallback onClear;
  final bool enabled;

  const ABRepeatOverlay({
    super.key,
    this.pointA,
    this.pointB,
    required this.currentPosition,
    required this.duration,
    required this.onSetA,
    required this.onSetB,
    required this.onClear,
    this.enabled = true,
  });

  bool get isLooping => pointA != null && pointB != null;
  bool get hasPointA => pointA != null;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Positioned(
      top: UIHelper.spaceXXL,
      right: UIHelper.spaceMD,
      child: Column(
        children: [
          // A/B indicator badge
          if (isLooping)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UIHelper.spaceSM,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
              ),
              child: const Text(
                'A→B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (isLooping) const SizedBox(height: 4),

          // A button
          _ABButton(
            label: 'A',
            isActive: hasPointA && !isLooping,
            isSet: hasPointA,
            onTap: () {
              HapticFeedback.lightImpact();
              if (hasPointA && !isLooping) {
                onSetA(null); // Clear
              } else {
                onSetA(currentPosition);
              }
            },
          ),
          const SizedBox(height: 4),

          // B button
          _ABButton(
            label: 'B',
            isActive: hasPointA && !isLooping,
            isSet: isLooping,
            enabled: hasPointA,
            onTap: () {
              if (!hasPointA) return;
              HapticFeedback.lightImpact();
              if (isLooping) {
                onClear(); // Clear both
              } else {
                onSetB(currentPosition);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ABButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isSet;
  final bool enabled;
  final VoidCallback onTap;

  const _ABButton({
    required this.label,
    required this.isActive,
    required this.isSet,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSet
        ? theme.colorScheme.primary
        : isActive
            ? theme.colorScheme.secondary
            : theme.colorScheme.surface;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSet
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSet
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
