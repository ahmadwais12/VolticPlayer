import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/ui_helper.dart';

/// Reusable playback speed selector bottom sheet.
///
/// Used by both video and audio players to avoid duplicating the speed menu.
class SpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSelected;

  const SpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelected,
  });

  /// Convenience method that shows this sheet and returns the selected speed.
  static Future<double?> show(
    BuildContext context, {
    required double currentSpeed,
  }) {
    double? result;
    UIHelper.showAppBottomSheet<double>(
      context,
      title: 'Playback Speed',
      child: SpeedSheet(
        currentSpeed: currentSpeed,
        onSelected: (speed) {
          result = speed;
          Navigator.pop(context);
        },
      ),
    );
    return Future.value(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: AppConstants.playbackSpeeds.length,
      itemBuilder: (context, i) {
        final speed = AppConstants.playbackSpeeds[i];
        final selected = speed == currentSpeed;
        return ListTile(
          title: Text('${speed}x'),
          trailing: selected
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          selected: selected,
          onTap: () => onSelected(speed),
        );
      },
    );
  }
}
