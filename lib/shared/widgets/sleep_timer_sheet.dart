import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Sleep timer options for audio/video playback.
class SleepTimerSheet extends StatelessWidget {
  final Duration? currentDuration;
  final ValueChanged<Duration?> onSelected;

  const SleepTimerSheet({
    super.key,
    this.currentDuration,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    Duration? currentDuration,
    required ValueChanged<Duration?> onSelected,
  }) {
    return UIHelper.showAppBottomSheet(
      context,
      title: 'Sleep Timer',
      child: SleepTimerSheet(
        currentDuration: currentDuration,
        onSelected: onSelected,
      ),
    );
  }

  static const _presets = [
    _TimerOption(label: '5 minutes', duration: Duration(minutes: 5)),
    _TimerOption(label: '10 minutes', duration: Duration(minutes: 10)),
    _TimerOption(label: '15 minutes', duration: Duration(minutes: 15)),
    _TimerOption(label: '30 minutes', duration: Duration(minutes: 30)),
    _TimerOption(label: '45 minutes', duration: Duration(minutes: 45)),
    _TimerOption(label: '1 hour', duration: Duration(hours: 1)),
    _TimerOption(label: '2 hours', duration: Duration(hours: 2)),
    _TimerOption(label: 'End of track', duration: null),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentDuration != null)
          Padding(
            padding: const EdgeInsets.only(bottom: UIHelper.spaceMD),
            child: Row(
              children: [
                Icon(Icons.timer, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Timer active: ${currentDuration!.inMinutes} min',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ..._presets.map((option) {
          final isSelected = option.duration == currentDuration;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
            title: Text(option.label),
            onTap: () {
              onSelected(option.duration);
              Navigator.pop(context);
            },
          );
        }),
        const Divider(),
        ListTile(
          leading: Icon(
            Icons.timer_off,
            color: currentDuration != null ? theme.colorScheme.error : null,
          ),
          title: Text(
            'Turn off',
            style: TextStyle(
              color: currentDuration != null ? theme.colorScheme.error : null,
            ),
          ),
          onTap: () {
            onSelected(null);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _TimerOption {
  final String label;
  final Duration? duration;

  const _TimerOption({required this.label, this.duration});
}
