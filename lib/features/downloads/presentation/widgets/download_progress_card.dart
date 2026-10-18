import 'package:flutter/material.dart';

/// Live download progress (prompt §7). Only shows a percentage when the
/// server reported a real total size — progress is never faked.
class DownloadProgressCard extends StatelessWidget {
  const DownloadProgressCard({
    super.key,
    required this.stage,
    required this.progress,
    required this.bytesReceived,
    required this.totalBytes,
    required this.speed,
    required this.onCancel,
    this.paused = false,
    this.onResume,
  });

  /// 'Preparing...', 'Downloading...' or 'Processing...'.
  final String stage;
  final double progress;
  final int bytesReceived;
  final int totalBytes;
  final double speed;
  final VoidCallback onCancel;
  final bool paused;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTotal = totalBytes > 0;
    final percent = hasTotal ? (progress * 100).round() : null;
    final etaSeconds =
        hasTotal && speed > 0 && totalBytes > bytesReceived
            ? (totalBytes - bytesReceived) / speed
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (stage == 'Downloading...' && !paused)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    paused
                        ? Icons.pause_circle_outline
                        : Icons.hourglass_top_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paused ? 'Paused' : stage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (paused && onResume != null)
                  TextButton(onPressed: onResume, child: const Text('Resume')),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: hasTotal
                  ? 'Download progress, $percent percent'
                  : 'Download in progress',
              value: hasTotal ? '$percent%' : null,
              child: LinearProgressIndicator(
                value: hasTotal
                    ? (progress > 0 ? progress : null)
                    : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (percent != null)
                  Text('$percent%', style: theme.textTheme.bodySmall)
                else
                  Text('Preparing...', style: theme.textTheme.bodySmall),
                if (hasTotal)
                  Text(
                    '${formatBytes(bytesReceived)} / ${formatBytes(totalBytes)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (speed > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Speed: ${formatBytes(speed.round())}/s'
                '${etaSeconds != null ? '  •  ETA: ${formatEta(etaSeconds)}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatEta(double seconds) {
    final duration = Duration(seconds: seconds.ceil());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final remainingSeconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }
}
