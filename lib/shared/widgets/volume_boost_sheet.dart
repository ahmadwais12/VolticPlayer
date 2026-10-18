import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/ui_helper.dart';

/// Volume + boost sheet: normal range 0–100%, boost 100–200%.
class VolumeBoostSheet extends StatefulWidget {
  final double currentVolume;
  final ValueChanged<double> onChanged;

  const VolumeBoostSheet({
    super.key,
    required this.currentVolume,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required double currentVolume,
    required ValueChanged<double> onChanged,
  }) {
    return UIHelper.showAppBottomSheet<void>(
      context,
      title: 'Volume Boost',
      child: VolumeBoostSheet(
        currentVolume: currentVolume,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<VolumeBoostSheet> createState() => _VolumeBoostSheetState();
}

class _VolumeBoostSheetState extends State<VolumeBoostSheet> {
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = widget.currentVolume.clamp(
      0.0,
      AppConstants.volumeBoostMax,
    );
  }

  bool get _isBoosted => _volume > AppConstants.volumeNormalMax;

  void _set(double value) {
    final next = value.clamp(0.0, AppConstants.volumeBoostMax);
    setState(() => _volume = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boostColor = theme.colorScheme.tertiary;
    final percent = _volume.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _volume == 0
                    ? Icons.volume_off_rounded
                    : _isBoosted
                    ? Icons.surround_sound_rounded
                    : Icons.volume_up_rounded,
                color: _isBoosted ? boostColor : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                '$percent%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _isBoosted ? boostColor : null,
                ),
              ),
              const SizedBox(width: 10),
              if (_isBoosted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: boostColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'BOOST',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: boostColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                _isBoosted ? 'Boost zone' : 'Normal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              activeTrackColor: _isBoosted
                  ? boostColor
                  : theme.colorScheme.primary,
              thumbColor: _isBoosted
                  ? boostColor
                  : theme.colorScheme.primary,
            ),
            child: Slider(
              value: _volume,
              min: 0,
              max: AppConstants.volumeBoostMax,
              divisions: 40,
              label: '$percent%',
              onChanged: _set,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0%',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  '100%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '200%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: boostColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in AppConstants.volumePresets)
                ChoiceChip(
                  label: Text('${preset.round()}%'),
                  selected: (_volume - preset).abs() < 0.5,
                  onSelected: (_) => _set(preset),
                ),
            ],
          ),
          if (_isBoosted) ...[
            const SizedBox(height: 12),
            Text(
              'Boost amplifies in-app playback (may distort on some tracks).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
