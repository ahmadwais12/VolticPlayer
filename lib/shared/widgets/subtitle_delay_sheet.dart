import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/ui_helper.dart';

/// Bottom sheet for adjusting subtitle delay (±10s range).
/// Matches requirements doc §24.
class SubtitleDelaySheet extends StatefulWidget {
  final double currentDelay; // in seconds
  final ValueChanged<double> onDelayChanged;

  const SubtitleDelaySheet({
    super.key,
    this.currentDelay = 0,
    required this.onDelayChanged,
  });

  static Future<void> show(
    BuildContext context, {
    double currentDelay = 0,
    required ValueChanged<double> onDelayChanged,
  }) {
    return UIHelper.showAppBottomSheet(
      context,
      title: 'Subtitle Delay',
      child: SubtitleDelaySheet(
        currentDelay: currentDelay,
        onDelayChanged: onDelayChanged,
      ),
    );
  }

  @override
  State<SubtitleDelaySheet> createState() => _SubtitleDelaySheetState();
}

class _SubtitleDelaySheetState extends State<SubtitleDelaySheet> {
  late double _delay;

  @override
  void initState() {
    super.initState();
    _delay = widget.currentDelay;
  }

  void _adjust(double delta) {
    setState(() {
      _delay = (_delay + delta).clamp(-10.0, 10.0);
    });
    HapticFeedback.selectionClick();
    widget.onDelayChanged(_delay);
  }

  void _reset() {
    setState(() => _delay = 0);
    HapticFeedback.lightImpact();
    widget.onDelayChanged(0);
  }

  String get _formattedDelay {
    final sign = _delay >= 0 ? '+' : '';
    return '${sign}${_delay.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current delay display
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: UIHelper.spaceSM),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
          ),
          child: Text(
            _formattedDelay,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        UIHelper.vMD,

        // Slider
        Slider(
          value: _delay,
          min: -10,
          max: 10,
          divisions: 200,
          label: _formattedDelay,
          onChanged: (v) {
            setState(() => _delay = v);
            widget.onDelayChanged(v);
          },
        ),
        UIHelper.vMD,

        // Quick adjustment buttons (§24)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DelayButton(label: '-1.0s', onTap: () => _adjust(-1.0)),
            UIHelper.hSM,
            _DelayButton(label: '-0.5s', onTap: () => _adjust(-0.5)),
            UIHelper.hSM,
            FilledButton.tonal(
              onPressed: _reset,
              child: const Text('Reset'),
            ),
            UIHelper.hSM,
            _DelayButton(label: '+0.5s', onTap: () => _adjust(0.5)),
            UIHelper.hSM,
            _DelayButton(label: '+1.0s', onTap: () => _adjust(1.0)),
          ],
        ),
      ],
    );
  }
}

class _DelayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DelayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
