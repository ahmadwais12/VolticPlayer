import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../../domain/entities/media_item.dart';
import 'poster_image.dart';

/// A compact mini player bar shown at the bottom of the screen
/// when navigating away from the player.
///
/// Tap to expand back to the full player. Shows play/pause and next controls.
class MiniPlayer extends StatelessWidget {
  final MediaItem item;
  final Duration position;
  final Duration duration;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onClose;

  const MiniPlayer({
    super.key,
    required this.item,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    required this.onTap,
    required this.onPlayPause,
    this.onNext,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: UIHelper.miniPlayerHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UIHelper.spaceSM,
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: PosterImage(
                        path: item.thumbnailPath,
                        placeholder: item.isAudio
                            ? Icons.music_note_rounded
                            : Icons.movie_rounded,
                      ),
                    ),
                    UIHelper.hSM,
                    // Title & artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UIHelper.ellipsisText(
                            item.displayName,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (item.artist != null)
                            UIHelper.ellipsisText(
                              item.artist!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Play/Pause
                    IconButton(
                      iconSize: UIHelper.iconMD,
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                      onPressed: onPlayPause,
                    ),
                    // Next
                    if (onNext != null)
                      IconButton(
                        iconSize: UIHelper.iconSM,
                        icon: const Icon(Icons.skip_next),
                        onPressed: onNext,
                      ),
                    // Close
                    if (onClose != null)
                      IconButton(
                        iconSize: UIHelper.iconSM,
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
