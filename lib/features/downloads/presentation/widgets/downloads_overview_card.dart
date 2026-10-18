import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/network_status.dart';

/// Live summary of the download manager: active / completed counts, bytes
/// stored, current network type and the concurrency limit.
class DownloadsOverviewCard extends ConsumerWidget {
  final DownloadManagerState state;

  const DownloadsOverviewCard({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final network = ref.watch(networkTypeProvider).value;

    final active = state.activeCount;
    final completed = state.completedItems.length;
    final totalBytes = state.totalBytesDownloaded;

    return UIHelper.card(
      padding: const EdgeInsets.all(UIHelper.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  active > 0
                      ? Icons.cloud_download
                      : Icons.cloud_download_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              UIHelper.hMD,
              Expanded(
                child: Text(
                  'Downloads overview',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          UIHelper.vMD,
          Row(
            children: [
              _StatTile(
                icon: Icons.downloading,
                value: '$active',
                label: 'Active',
              ),
              _StatTile(
                icon: Icons.check_circle_outline,
                value: '$completed',
                label: 'Completed',
              ),
              _StatTile(
                icon: Icons.storage,
                value: _formatBytes(totalBytes),
                label: 'Stored',
              ),
            ],
          ),
          UIHelper.vMD,
          const Divider(height: 1),
          UIHelper.vSM,
          Row(
            children: [
              Icon(
                (network ?? NetworkType.other).icon,
                size: UIHelper.iconMD,
                color: network == NetworkType.none
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              UIHelper.hSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      (network ?? NetworkType.other).label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.speed,
                size: UIHelper.iconMD,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              UIHelper.hSM,
              Text(
                '${state.maxConcurrent} at once',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: UIHelper.iconMD, color: theme.colorScheme.primary),
          UIHelper.vXS,
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picker for how many downloads may run at the same time (1–5).
class DownloadConcurrencyCard extends StatelessWidget {
  final int maxConcurrent;
  final ValueChanged<int> onChanged;

  const DownloadConcurrencyCard({
    super.key,
    required this.maxConcurrent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return UIHelper.card(
      padding: const EdgeInsets.all(UIHelper.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_component,
                  size: UIHelper.iconMD, color: theme.colorScheme.primary),
              UIHelper.hSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simultaneous downloads',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'How many downloads run at the same time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          UIHelper.vSM,
          Row(
            children: [
              for (var n = 1; n <= 5; n++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: UIHelper.spaceXS),
                    child: InkWell(
                      onTap: () {
                        onChanged(n);
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: maxConcurrent == n
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(UIHelper.radiusSM),
                        ),
                        child: Text(
                          '$n',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: maxConcurrent == n
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
