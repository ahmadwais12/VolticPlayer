import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Reusable section header widget for screens with grouped content.
///
/// Wraps [UIHelper.sectionTitle] as a standalone widget for consistent
/// use across all list/grid screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return UIHelper.sectionTitle(
      context,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
