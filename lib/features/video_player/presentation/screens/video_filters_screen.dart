import 'package:flutter/material.dart';

import '../../../../core/constants/ui_helper.dart';

/// Video filter adjustments matching requirements doc §66.
/// Controls brightness, contrast, saturation, hue, gamma, sharpness.
class VideoFiltersScreen extends StatefulWidget {
  const VideoFiltersScreen({super.key});

  @override
  State<VideoFiltersScreen> createState() => _VideoFiltersScreenState();
}

class _VideoFiltersScreenState extends State<VideoFiltersScreen> {
  double _brightness = 0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _hue = 0;
  double _gamma = 1.0;
  double _sharpness = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Filters'),
        actions: [
          TextButton(
            onPressed: _resetAll,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          _FilterSlider(
            label: 'Brightness',
            icon: Icons.brightness_6,
            value: _brightness,
            min: -1.0,
            max: 1.0,
            defaultValue: 0,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          _FilterSlider(
            label: 'Contrast',
            icon: Icons.contrast,
            value: _contrast,
            min: 0.0,
            max: 2.0,
            defaultValue: 1.0,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          _FilterSlider(
            label: 'Saturation',
            icon: Icons.palette,
            value: _saturation,
            min: 0.0,
            max: 3.0,
            defaultValue: 1.0,
            onChanged: (v) => setState(() => _saturation = v),
          ),
          _FilterSlider(
            label: 'Hue',
            icon: Icons.colorize,
            value: _hue,
            min: -180,
            max: 180,
            defaultValue: 0,
            divisions: 360,
            onChanged: (v) => setState(() => _hue = v),
          ),
          _FilterSlider(
            label: 'Gamma',
            icon: Icons.light_mode,
            value: _gamma,
            min: 0.1,
            max: 5.0,
            defaultValue: 1.0,
            onChanged: (v) => setState(() => _gamma = v),
          ),
          _FilterSlider(
            label: 'Sharpness',
            icon: Icons.details,
            value: _sharpness,
            min: 0,
            max: 1.0,
            defaultValue: 0,
            onChanged: (v) => setState(() => _sharpness = v),
          ),
          UIHelper.vLG,

          // Preset buttons
          Text('Presets', style: theme.textTheme.titleMedium),
          UIHelper.vSM,
          Wrap(
            spacing: UIHelper.spaceSM,
            runSpacing: UIHelper.spaceSM,
            children: [
              _PresetChip(
                label: 'Normal',
                onTap: () => _applyPreset(
                    brightness: 0, contrast: 1, saturation: 1, hue: 0, gamma: 1, sharpness: 0),
              ),
              _PresetChip(
                label: 'Vivid',
                onTap: () => _applyPreset(
                    brightness: 0.05, contrast: 1.2, saturation: 1.5, hue: 0, gamma: 1.1, sharpness: 0.3),
              ),
              _PresetChip(
                label: 'Warm',
                onTap: () => _applyPreset(
                    brightness: 0.05, contrast: 1.05, saturation: 1.1, hue: 15, gamma: 1.05, sharpness: 0),
              ),
              _PresetChip(
                label: 'Cool',
                onTap: () => _applyPreset(
                    brightness: 0, contrast: 1.05, saturation: 0.9, hue: -15, gamma: 1, sharpness: 0),
              ),
              _PresetChip(
                label: 'Night',
                onTap: () => _applyPreset(
                    brightness: 0.15, contrast: 1.3, saturation: 0.8, hue: 0, gamma: 1.2, sharpness: 0.2),
              ),
              _PresetChip(
                label: 'B&W',
                onTap: () => _applyPreset(
                    brightness: 0, contrast: 1.2, saturation: 0, hue: 0, gamma: 1, sharpness: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyPreset({
    required double brightness,
    required double contrast,
    required double saturation,
    required double hue,
    required double gamma,
    required double sharpness,
  }) {
    setState(() {
      _brightness = brightness;
      _contrast = contrast;
      _saturation = saturation;
      _hue = hue;
      _gamma = gamma;
      _sharpness = sharpness;
    });
  }

  void _resetAll() => _applyPreset(
      brightness: 0, contrast: 1, saturation: 1, hue: 0, gamma: 1, sharpness: 0);
}

class _FilterSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _FilterSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UIHelper.spaceSM),
      child: Row(
        children: [
          Icon(icon, size: 20),
          UIHelper.hSM,
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: value.toStringAsFixed(1),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
