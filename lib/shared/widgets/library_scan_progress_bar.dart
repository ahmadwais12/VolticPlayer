import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/library_scan_progress.dart';

/// In-page scan progress for Videos / Music / Playlists.
///
/// Shows a single percent bar (e.g. 20% → 100%) while
/// [libraryScanProgressProvider] is active; otherwise renders nothing.
class LibraryScanProgressBar extends ConsumerWidget {
  const LibraryScanProgressBar({
    super.key,
    this.title = 'Scanning library',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(libraryScanProgressProvider);
    if (!progress.isScanning) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final countLabel = progress.total > 0
        ? '${progress.scanned} / ${progress.total} files'
        : progress.scanned > 0
        ? '${progress.scanned} files found'
        : 'Looking for videos & music…';

    return Padding(
      padding: padding,
      child: Material(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${progress.percent}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                countLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.value.clamp(0.02, 1.0),
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: 0.7,
                  ),
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
