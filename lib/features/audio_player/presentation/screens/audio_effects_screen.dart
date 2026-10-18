import 'package:flutter/material.dart';

import '../../../../core/constants/ui_helper.dart';

/// Audio effects matching requirements doc §65.
/// Bass Boost, Treble, Balance, Loudness, Virtualizer, Reverb.
class AudioEffectsScreen extends StatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  State<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends State<AudioEffectsScreen> {
  double _bassBoost = 0;
  double _treble = 0;
  double _balance = 0; // -1.0 left, 0 center, 1.0 right
  double _loudness = 0;
  double _virtualizer = 0;
  double _reverb = 0;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Effects'),
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
          child: ListView(
            padding: UIHelper.screenPadding,
            children: [
              _EffectSlider(
                label: 'Bass Boost',
                icon: Icons.surround_sound,
                value: _bassBoost,
                max: 12,
                onChanged: (v) => setState(() => _bassBoost = v),
              ),
              _EffectSlider(
                label: 'Treble',
                icon: Icons.graphic_eq,
                value: _treble,
                max: 12,
                onChanged: (v) => setState(() => _treble = v),
              ),
              _BalanceSlider(
                value: _balance,
                onChanged: (v) => setState(() => _balance = v),
              ),
              _EffectSlider(
                label: 'Loudness',
                icon: Icons.volume_up,
                value: _loudness,
                max: 12,
                onChanged: (v) => setState(() => _loudness = v),
              ),
              _EffectSlider(
                label: 'Virtualizer',
                icon: Icons.surround_sound_outlined,
                value: _virtualizer,
                max: 12,
                onChanged: (v) => setState(() => _virtualizer = v),
              ),
              _EffectSlider(
                label: 'Reverb',
                icon: Icons.spatial_audio,
                value: _reverb,
                max: 12,
                onChanged: (v) => setState(() => _reverb = v),
              ),
              UIHelper.vLG,
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _bassBoost = 0;
                      _treble = 0;
                      _balance = 0;
                      _loudness = 0;
                      _virtualizer = 0;
                      _reverb = 0;
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset All'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _EffectSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        UIHelper.hSM,
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: value,
              min: 0,
              max: max,
              divisions: 12,
              label: '${value.round()} dB',
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.round()} dB',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _BalanceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _BalanceSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.surround_sound, size: 20),
        UIHelper.hSM,
        const SizedBox(
          width: 90,
          child: Text('Balance', style: TextStyle(fontSize: 12)),
        ),
        const Text('L', style: TextStyle(fontSize: 10)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ),
        const Text('R', style: TextStyle(fontSize: 10)),
      ],
    );
  }
}
