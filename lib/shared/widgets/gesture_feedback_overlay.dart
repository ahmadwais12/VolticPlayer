import 'package:flutter/material.dart';

/// A small overlay that briefly shows volume or brightness change.
///
/// Used by the gesture system in the video player to give visual feedback.
class GestureFeedbackOverlay extends StatelessWidget {
  final IconData icon;
  final double value; // 0.0 – 1.0
  final bool visible;

  const GestureFeedbackOverlay({
    super.key,
    required this.icon,
    required this.value,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
