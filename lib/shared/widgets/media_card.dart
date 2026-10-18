import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/media_item.dart';
import 'media_more_menu.dart';
import 'poster_image.dart';

/// Grid card used on Home / Videos / Music screens.
/// Tapping opens the player. Builds its look entirely from [UIHelper].
class MediaCard extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onChanged;
  final bool isSelecting;
  final bool selected;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.onChanged,
    this.isSelecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showAudio = item.isAudio;
    return UIHelper.card(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      color: isSelecting
          ? (selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : null)
          : null,
      radius: UIHelper.radiusMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaArtwork(
                  item: item,
                  width: double.infinity,
                  height: double.infinity,
                ),
                if (isSelecting)
                  Container(color: Colors.black.withValues(alpha: 0.25)),
                if (item.durationMs > 0 && !isSelecting)
                  Positioned(
                    right: UIHelper.spaceXS,
                    bottom: UIHelper.spaceXS,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(UIHelper.radiusXS),
                      ),
                      child: Text(
                        Duration(milliseconds: item.durationMs).formatted,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (item.isFavorite && !isSelecting)
                  const Positioned(
                    left: UIHelper.spaceXS,
                    top: UIHelper.spaceXS,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: UIHelper.iconSM,
                    ),
                  ),
                if (isSelecting)
                  Positioned(
                    left: UIHelper.spaceXS,
                    top: UIHelper.spaceXS,
                    child: _SelectionCheck(checked: selected),
                  )
                else
                  Positioned(
                    right: UIHelper.spaceXS,
                    top: UIHelper.spaceXS,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openMore(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.more_vert,
                            size: UIHelper.iconSM,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: UIHelper.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showAudio && item.artist != null) ...[
                  UIHelper.vXS,
                  Text(
                    item.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openMore(BuildContext context, WidgetRef ref) {
    MediaMoreMenu.show(context, item: item, onChanged: onChanged);
  }
}

/// Small circular selection check shown on cards/lists during selection mode.
class _SelectionCheck extends StatelessWidget {
  final bool checked;
  const _SelectionCheck({required this.checked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? theme.colorScheme.primary : Colors.black45,
        border: Border.all(
          color: checked ? theme.colorScheme.primary : Colors.white,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
          : null,
    );
  }
}

/// List row used in search / history / playlist details.
class MediaListTile extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final VoidCallback? onChanged;
  final bool isSelecting;
  final bool selected;

  const MediaListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.onChanged,
    this.isSelecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Stack(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: MediaArtwork(
              item: item,
              width: 56,
              height: 56,
            ),
          ),
          if (isSelecting)
            Positioned(
              left: 0,
              top: 0,
              child: _SelectionCheck(checked: selected),
            ),
        ],
      ),
      title: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: item.isAudio
          ? Text(
              item.artist ?? item.extension.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              [
                if (item.extension.isNotEmpty) item.extension.toUpperCase(),
                if (item.durationMs > 0)
                  Duration(milliseconds: item.durationMs).formatted,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      selected: isSelecting && selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      trailing: isSelecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) trailing!,
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'More',
                  onPressed: () => MediaMoreMenu.show(
                    context,
                    item: item,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
