import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';

class SubtitleSettingsScreen extends ConsumerWidget {
  const SubtitleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subtitle Settings')),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(UIHelper.spaceLG),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(UIHelper.radiusMD),
            ),
            child: Text(
              'Sample subtitle text\nSecond line',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
          UIHelper.vLG,

          // Font size
          Text('Font size', style: theme.textTheme.titleMedium),
          Slider(
            value: 18,
            min: 10,
            max: 40,
            divisions: 30,
            label: '18px',
            onChanged: (_) {},
          ),

          // Font color
          Text('Font color', style: theme.textTheme.titleMedium),
          UIHelper.vSM,
          Wrap(
            spacing: UIHelper.spaceSM,
            children: [
              Colors.white,
              Colors.yellow,
              Colors.cyan,
              Colors.green,
              Colors.orange,
              theme.colorScheme.primary,
            ].map((color) {
              return GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
          UIHelper.vMD,

          // Background
          Text('Background', style: theme.textTheme.titleMedium),
          UIHelper.vSM,
          Wrap(
            spacing: UIHelper.spaceSM,
            children: ['None', 'Black', 'Semi-transparent', 'Outline only']
                .map((label) {
              return ChoiceChip(
                label: Text(label),
                selected: label == 'Semi-transparent',
                onSelected: (_) {},
              );
            }).toList(),
          ),
          UIHelper.vMD,

          // Outline width
          Text('Outline width', style: theme.textTheme.titleMedium),
          Slider(
            value: 1,
            min: 0,
            max: 3,
            divisions: 6,
            label: '1.0',
            onChanged: (_) {},
          ),

          // Delay
          Text('Subtitle delay', style: theme.textTheme.titleMedium),
          UIHelper.vSM,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('-1.0s'),
              ),
              UIHelper.hSM,
              OutlinedButton(
                onPressed: () {},
                child: const Text('-0.5s'),
              ),
              UIHelper.hSM,
              FilledButton(
                onPressed: () {},
                child: const Text('Reset'),
              ),
              UIHelper.hSM,
              OutlinedButton(
                onPressed: () {},
                child: const Text('+0.5s'),
              ),
              UIHelper.hSM,
              OutlinedButton(
                onPressed: () {},
                child: const Text('+1.0s'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
