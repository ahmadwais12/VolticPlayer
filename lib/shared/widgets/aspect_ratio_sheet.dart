import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Aspect ratio options for video playback.
enum VideoAspectRatio {
  fit,
  fill,
  original,
  r16x9,
  r4x3,
  r18x9,
  r21x9,
  stretch,
}

extension VideoAspectRatioExtension on VideoAspectRatio {
  String get label {
    switch (this) {
      case VideoAspectRatio.fit:
        return 'Fit';
      case VideoAspectRatio.fill:
        return 'Fill';
      case VideoAspectRatio.original:
        return 'Original';
      case VideoAspectRatio.r16x9:
        return '16:9';
      case VideoAspectRatio.r4x3:
        return '4:3';
      case VideoAspectRatio.r18x9:
        return '18:9';
      case VideoAspectRatio.r21x9:
        return '21:9';
      case VideoAspectRatio.stretch:
        return 'Stretch';
    }
  }

  IconData get icon {
    switch (this) {
      case VideoAspectRatio.fit:
        return Icons.fit_screen;
      case VideoAspectRatio.fill:
        return Icons.fullscreen;
      case VideoAspectRatio.original:
        return Icons.crop_original;
      case VideoAspectRatio.r16x9:
        return Icons.crop_16_9;
      case VideoAspectRatio.r4x3:
        return Icons.crop_3_2;
      case VideoAspectRatio.r18x9:
        return Icons.crop_landscape;
      case VideoAspectRatio.r21x9:
        return Icons.crop_landscape;
      case VideoAspectRatio.stretch:
        return Icons.fit_screen;
    }
  }

  /// Returns the aspect ratio multiplier, or null for auto modes.
  double? get ratio {
    switch (this) {
      case VideoAspectRatio.r16x9:
        return 16 / 9;
      case VideoAspectRatio.r4x3:
        return 4 / 3;
      case VideoAspectRatio.r18x9:
        return 18 / 9;
      case VideoAspectRatio.r21x9:
        return 21 / 9;
      default:
        return null;
    }
  }
}

/// Bottom sheet for selecting video aspect ratio.
class AspectRatioSheet extends StatelessWidget {
  final VideoAspectRatio current;
  final ValueChanged<VideoAspectRatio> onSelected;

  const AspectRatioSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required VideoAspectRatio current,
    required ValueChanged<VideoAspectRatio> onSelected,
  }) {
    return UIHelper.showAppBottomSheet(
      context,
      title: 'Aspect Ratio',
      child: AspectRatioSheet(current: current, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: UIHelper.spaceSM,
      runSpacing: UIHelper.spaceSM,
      children: VideoAspectRatio.values.map((ratio) {
        final isSelected = ratio == current;
        return ChoiceChip(
          label: Text(ratio.label),
          avatar: Icon(ratio.icon, size: 18),
          selected: isSelected,
          onSelected: (_) {
            onSelected(ratio);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}
