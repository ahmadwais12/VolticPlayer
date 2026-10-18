import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../controllers/settings_controller.dart';

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playback Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          padding: UIHelper.screenPadding,
          children: [
            _buildSwitch(
              label: 'Remember position',
              subtitle: 'Resume from last position when reopening',
              value: settings[SettingsKeys.rememberPosition] ?? true,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.rememberPosition, v),
            ),
            _buildSwitch(
              label: 'Background audio',
              subtitle: 'Continue audio when app is in background',
              value: settings[SettingsKeys.backgroundAudio] ?? true,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.backgroundAudio, v),
            ),
            _buildSwitch(
              label: 'Auto-rotate to landscape',
              subtitle: 'Automatically rotate when playing video',
              value: settings[SettingsKeys.autoRotate] ?? true,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.autoRotate, v),
            ),
            _buildSwitch(
              label: 'Hardware decoder',
              subtitle: 'Use hardware acceleration when available',
              value: settings[SettingsKeys.hardwareDecoding] ?? true,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.hardwareDecoding, v),
            ),
            _buildSwitch(
              label: 'Crossfade tracks',
              subtitle: 'Smoothly fade between audio tracks',
              value: settings[SettingsKeys.crossfade] ?? false,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.crossfade, v),
            ),
            _buildSwitch(
              label: 'Gapless playback',
              subtitle: 'Play tracks without gaps between them',
              value: settings[SettingsKeys.gapless] ?? true,
              onChanged: (v) => _updateSetting(ref, SettingsKeys.gapless, v),
            ),

            UIHelper.vMD,
            const Divider(),
            UIHelper.vMD,

            Text('Default speed', style: Theme.of(context).textTheme.titleMedium),
            UIHelper.vSM,
            Wrap(
              spacing: UIHelper.spaceSM,
              runSpacing: UIHelper.spaceSM,
              children: AppConstants.playbackSpeeds.map((speed) {
                return ChoiceChip(
                  label: Text('${speed}x'),
                  selected: speed == 1.0,
                  onSelected: (_) {},
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _updateSetting(WidgetRef ref, String key, bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(key, value);
    ref.invalidate(settingsMapProvider);
  }
}
