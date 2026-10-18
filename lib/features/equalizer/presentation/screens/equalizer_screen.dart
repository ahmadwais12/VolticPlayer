import 'package:flutter/material.dart';

import '../../../../core/constants/ui_helper.dart';

/// Equalizer presets matching the requirements doc.
enum EqualizerPreset {
  flat,
  classical,
  dance,
  electronic,
  hipHop,
  jazz,
  pop,
  rock,
  vocal,
  custom,
}

extension EqualizerPresetExtension on EqualizerPreset {
  String get label {
    switch (this) {
      case EqualizerPreset.flat:
        return 'Flat';
      case EqualizerPreset.classical:
        return 'Classical';
      case EqualizerPreset.dance:
        return 'Dance';
      case EqualizerPreset.electronic:
        return 'Electronic';
      case EqualizerPreset.hipHop:
        return 'Hip Hop';
      case EqualizerPreset.jazz:
        return 'Jazz';
      case EqualizerPreset.pop:
        return 'Pop';
      case EqualizerPreset.rock:
        return 'Rock';
      case EqualizerPreset.vocal:
        return 'Vocal';
      case EqualizerPreset.custom:
        return 'Custom';
    }
  }

  /// Pre-configured gain values for each band (60Hz..15kHz), range -12 to +12 dB.
  List<double> get gains {
    switch (this) {
      case EqualizerPreset.flat:
        return [0, 0, 0, 0, 0, 0, 0];
      case EqualizerPreset.classical:
        return [0, 0, 0, 0, 0, -2, -4];
      case EqualizerPreset.dance:
        return [4, 3, 0, 0, -2, -4, 0];
      case EqualizerPreset.electronic:
        return [4, 3, 0, -2, 0, 3, 4];
      case EqualizerPreset.hipHop:
        return [4, 3, 1, 0, -1, 1, 3];
      case EqualizerPreset.jazz:
        return [0, 0, 2, 4, 4, 2, 0];
      case EqualizerPreset.pop:
        return [-1, 2, 4, 4, 2, 0, -1];
      case EqualizerPreset.rock:
        return [4, 3, 1, 0, -1, 1, 3];
      case EqualizerPreset.vocal:
        return [-2, -1, 0, 3, 4, 3, 1];
      case EqualizerPreset.custom:
        return [0, 0, 0, 0, 0, 0, 0];
    }
  }
}

/// Full equalizer screen with 7-band EQ sliders and presets.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const _frequencies = ['60', '150', '400', '1K', '2.4K', '6K', '15K'];
  static const _minDb = -12.0;
  static const _maxDb = 12.0;

  EqualizerPreset _selectedPreset = EqualizerPreset.flat;
  late List<double> _gains;
  double _bassBoost = 0;
  double _treble = 0;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _gains = List.from(_selectedPreset.gains);
  }

  void _applyPreset(EqualizerPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _gains = List.from(preset.gains);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Switch(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: !_enabled,
        child: Opacity(
          opacity: _enabled ? 1.0 : 0.4,
          child: SingleChildScrollView(
            padding: UIHelper.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Presets ──────────────────────────────────────────
                Text('Presets', style: theme.textTheme.titleMedium),
                UIHelper.vSM,
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: EqualizerPreset.values.length,
                    separatorBuilder: (_, __) => UIHelper.hSM,
                    itemBuilder: (context, index) {
                      final preset = EqualizerPreset.values[index];
                      final isSelected = preset == _selectedPreset;
                      return ChoiceChip(
                        label: Text(preset.label),
                        selected: isSelected,
                        onSelected: (_) => _applyPreset(preset),
                      );
                    },
                  ),
                ),
                UIHelper.vLG,

                // ── 7-Band EQ Sliders ───────────────────────────────
                Text('Frequency Bands', style: theme.textTheme.titleMedium),
                UIHelper.vMD,
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      return _BandSlider(
                        label: _frequencies[index],
                        value: _gains[index],
                        min: _minDb,
                        max: _maxDb,
                        onChanged: (value) {
                          setState(() {
                            _gains[index] = value;
                            _selectedPreset = EqualizerPreset.custom;
                          });
                        },
                      );
                    }),
                  ),
                ),
                UIHelper.vLG,

                // ── Bass Boost ───────────────────────────────────────
                _EnhancementSlider(
                  label: 'Bass Boost',
                  icon: Icons.surround_sound,
                  value: _bassBoost,
                  onChanged: (v) => setState(() => _bassBoost = v),
                ),
                UIHelper.vSM,

                // ── Treble ───────────────────────────────────────────
                _EnhancementSlider(
                  label: 'Treble',
                  icon: Icons.graphic_eq,
                  value: _treble,
                  onChanged: (v) => setState(() => _treble = v),
                ),
                UIHelper.vLG,

                // ── Reset Button ─────────────────────────────────────
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _applyPreset(EqualizerPreset.flat);
                      setState(() {
                        _bassBoost = 0;
                        _treble = 0;
                      });
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset to Flat'),
                  ),
                ),
                UIHelper.vLG,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // dB value
        Text(
          '${value > 0 ? '+' : ''}${value.round()}',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Frequency label
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _EnhancementSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _EnhancementSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        UIHelper.hSM,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 3),
                child: Slider(
                  value: value,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  label: '${value.round()} dB',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${value.round()} dB',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
