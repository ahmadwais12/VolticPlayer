import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Polished header used on Videos / Music / Playlists / Downloads tabs.
class LibraryPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget>? actions;
  final Widget? trailing;

  const LibraryPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIHelper.spaceMD,
        UIHelper.spaceSM,
        UIHelper.spaceMD,
        UIHelper.spaceMD,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(UIHelper.spaceMD),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIHelper.radiusLG),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.16),
              colors.tertiary.withValues(alpha: 0.08),
              colors.surfaceContainerHighest.withValues(alpha: 0.4),
            ],
          ),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(UIHelper.radiusSM),
              ),
              child: Icon(icon, color: colors.primary),
            ),
            UIHelper.hMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  UIHelper.vXS,
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            ...?actions,
          ],
        ),
      ),
    );
  }
}

/// Circular icon action used in polished library app bars / headers.
class LibraryHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const LibraryHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              colors.surfaceContainerHighest.withValues(alpha: 0.55),
          foregroundColor: colors.onSurface,
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}
