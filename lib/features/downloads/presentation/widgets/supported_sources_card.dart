import 'package:flutter/material.dart';

import 'fade_slide_in.dart';

/// Supported-source information plus the authorized-use notice
/// (prompt §1 "Supported-source information" and §18 legal notice).
class SupportedSourcesCard extends StatelessWidget {
  const SupportedSourcesCard({super.key, this.compact = false});

  /// Compact variant used next to the format selector.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeSlideIn(
      delay: const Duration(milliseconds: 120),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.public,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Supported sources: public HTTPS media files and pages '
                          'that expose an openly embeddable media URL, handled '
                          'by the built-in generic provider. Additional '
                          'providers can be registered without changing this '
                          'screen.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gavel_outlined,
                    color: theme.colorScheme.outline,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only download content you have permission to save and '
                          'use. Respect the terms and copyright rules of the '
                          'source.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
