import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// A reusable key-value row for displaying media information.
///
/// Used in the media info sheet, about screen, and any detail view
/// that needs a label-value pair layout.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool showDivider;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UIHelper.spaceMD,
            vertical: UIHelper.spaceSM,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: UIHelper.iconSM, color: theme.colorScheme.outline),
                UIHelper.hSM,
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              UIHelper.hSM,
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// A compact chip-style info row for inline details.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIHelper.spaceSM,
        vertical: UIHelper.spaceXS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(UIHelper.radiusXS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: UIHelper.iconSM, color: theme.colorScheme.outline),
          UIHelper.hXS,
          Text(
            label,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
