import 'package:flutter/material.dart';

import '../../../../core/services/video_downloader_service.dart';
import 'fade_slide_in.dart';

/// Media preview card: thumbnail, title, creator, source, duration,
/// media type and available format counts (prompt §6).
class MediaPreviewCard extends StatelessWidget {
  const MediaPreviewCard({super.key, required this.metadata});

  final MediaMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceHost = Uri.tryParse(metadata.sourceUrl ?? '')?.host ?? 'Unknown';
    final videoFormats = metadata.formats.where((f) => !f.isAudioOnly).length;
    final audioFormats = metadata.formats.where((f) => f.isAudioOnly).length;
    final mediaType = videoFormats > 0 && audioFormats > 0
        ? 'Video & Audio'
        : audioFormats > 0
        ? 'Audio'
        : 'Video';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 200,
            child: metadata.thumbnailUrl != null
                ? Image.network(
                    metadata.thumbnailUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                    errorBuilder: (_, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 48),
                      ),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.play_circle_outline, size: 48),
                    ),
                  ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            offset: const Offset(0, 0.04),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metadata.author != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata.author!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.language, label: sourceHost),
                      if (metadata.duration != null)
                        _MetaChip(
                          icon: Icons.schedule,
                          label: _formatDuration(metadata.duration!),
                        ),
                      _MetaChip(icon: Icons.movie_outlined, label: mediaType),
                      _MetaChip(
                        icon: Icons.tune,
                        label:
                            '${metadata.formats.length} format${metadata.formats.length == 1 ? '' : 's'} available',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
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
