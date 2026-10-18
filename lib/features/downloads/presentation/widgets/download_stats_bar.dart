import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';

/// Aggregated downloader statistics (prompt §24, compact form for a
/// consumer app — there is no admin dashboard in this project).
///
/// Shows totals, active/completed/failed counts, transferred data and the
/// video/audio split. No individual user URLs are exposed.
class DownloadStatsBar extends StatelessWidget {
  const DownloadStatsBar({super.key, required this.items});

  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final active = items.where((i) => i.isActive || i.isPaused).length;
    final completed = items.where((i) => i.isCompleted).length;
    final failed = items.where((i) => i.status == DownloadStatus.failed).length;
    final video = items.where((i) => i.mediaType == 'video').length;
    final audio = items.where((i) => i.mediaType == 'audio').length;
    final bytes = items
        .where((i) => i.isCompleted)
        .fold<int>(0, (sum, i) => sum + i.bytesReceived);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Stat(label: 'Total', value: '$total'),
          _Stat(label: 'Active', value: '$active'),
          _Stat(label: 'Completed', value: '$completed'),
          _Stat(label: 'Failed', value: '$failed'),
          _Stat(label: 'Video', value: '$video'),
          _Stat(label: 'Audio', value: '$audio'),
          _Stat(label: 'Data', value: _formatBytes(bytes)),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
