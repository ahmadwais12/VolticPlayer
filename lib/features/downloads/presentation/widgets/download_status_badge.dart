import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';

/// Shared presentation for [DownloadStatus] values (prompt §9 / §20):
/// one badge widget plus label/icon/color helpers reused by the download
/// manager list, the queue overview and the history rows.
class DownloadStatusBadge extends StatelessWidget {
  const DownloadStatusBadge({super.key, required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Short, user-facing name for each status.
  static String statusLabel(DownloadStatus status) => switch (status) {
    DownloadStatus.pending => 'Queued',
    DownloadStatus.downloading => 'Downloading',
    DownloadStatus.processing => 'Processing',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.completed => 'Completed',
    DownloadStatus.failed => 'Failed',
    DownloadStatus.cancelled => 'Cancelled',
  };

  static IconData statusIcon(DownloadStatus status) => switch (status) {
    DownloadStatus.pending => Icons.hourglass_empty,
    DownloadStatus.downloading => Icons.downloading,
    DownloadStatus.processing => Icons.sync,
    DownloadStatus.paused => Icons.pause_circle,
    DownloadStatus.completed => Icons.check_circle,
    DownloadStatus.failed => Icons.error_outline,
    DownloadStatus.cancelled => Icons.cancel_outlined,
  };

  static Color statusColor(ThemeData theme, DownloadStatus status) =>
      switch (status) {
        DownloadStatus.pending => theme.colorScheme.outline,
        DownloadStatus.downloading => theme.colorScheme.primary,
        DownloadStatus.processing => theme.colorScheme.tertiary,
        DownloadStatus.paused => theme.colorScheme.tertiary,
        DownloadStatus.completed => Colors.green,
        DownloadStatus.failed => theme.colorScheme.error,
        DownloadStatus.cancelled => theme.colorScheme.outline,
      };
}
