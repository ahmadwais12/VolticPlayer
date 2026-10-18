import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../widgets/settings_widgets.dart';

class GestureSettingsScreen extends ConsumerWidget {
  const GestureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesture Settings')),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          SettingsSwitch(
            label: 'Enable gestures',
            subtitle: 'Master toggle for all gesture controls',
            settingKey: 'gestures_enabled',
            value: true,
            onChanged: (_) {},
          ),
          const Divider(),
          SettingsSwitch(
            label: 'Brightness gesture',
            subtitle: 'Swipe up/down on left side to adjust brightness',
            settingKey: 'gesture_brightness',
            value: true,
            onChanged: (_) {},
          ),
          SettingsSwitch(
            label: 'Volume gesture',
            subtitle: 'Swipe up/down on right side to adjust volume',
            settingKey: 'gesture_volume',
            value: true,
            onChanged: (_) {},
          ),
          SettingsSwitch(
            label: 'Seek gesture',
            subtitle: 'Swipe left/right to seek through the video',
            settingKey: 'gesture_seek',
            value: true,
            onChanged: (_) {},
          ),
          SettingsSwitch(
            label: 'Double-tap seek',
            subtitle: 'Double-tap left/right side to skip ±10 seconds',
            settingKey: 'gesture_double_tap',
            value: true,
            onChanged: (_) {},
          ),
          SettingsSwitch(
            label: 'Pinch to zoom',
            subtitle: 'Pinch to zoom in/out on video',
            settingKey: 'gesture_pinch_zoom',
            value: true,
            onChanged: (_) {},
          ),
          SettingsSwitch(
            label: 'Long press for speed',
            subtitle: 'Hold to temporarily increase playback speed',
            settingKey: 'gesture_long_press_speed',
            value: false,
            onChanged: (_) {},
          ),

          UIHelper.vMD,
          const Divider(),
          UIHelper.vMD,

          Text('Double-tap seek duration', style: Theme.of(context).textTheme.titleMedium),
          UIHelper.vSM,
          Wrap(
            spacing: UIHelper.spaceSM,
            children: [5, 10, 15, 20, 30].map((seconds) {
              return ChoiceChip(
                label: Text('±${seconds}s'),
                selected: seconds == 10,
                onSelected: (_) {},
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
