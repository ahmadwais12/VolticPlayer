import 'package:flutter/material.dart';

/// User-friendly error display for the downloader (prompt §17).
/// Never shows stack traces, server paths or internal details — only the
/// sanitized message produced by the domain layer.
class DownloaderErrorCard extends StatelessWidget {
  const DownloaderErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Messages follow the "Title — detail" convention where possible.
    final parts = message.split(' — ');
    final title = parts.first;
    final detail = parts.length > 1
        ? parts.sublist(1).join(' — ')
        : null;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
