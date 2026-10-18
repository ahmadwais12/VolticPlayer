import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../../domain/entities/media_item.dart';
import 'media_card.dart';

/// Responsive grid of [MediaCard]s used by Home / Videos / Music.
class MediaGridView extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onTap;
  final void Function(MediaItem item)? onLongPress;
  final Set<int>? selectedIds;
  final bool isSelecting;
  final VoidCallback? onChanged;

  const MediaGridView({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.selectedIds,
    this.isSelecting = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = switch (width) {
      >= 1200 => 6,
      >= 900 => 5,
      >= 600 => 4,
      >= 400 => 3,
      _ => 2,
    };
    final selectable = isSelecting || (selectedIds?.isNotEmpty ?? false);
    return GridView.builder(
      padding: UIHelper.listPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: UIHelper.spaceMD,
        crossAxisSpacing: UIHelper.spaceMD,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaCard(
          item: item,
          isSelecting: selectable,
          selected: selectedIds?.contains(item.id) ?? false,
          onTap: () => onTap(item),
          onLongPress: onLongPress == null ? null : () => onLongPress!(item),
          onChanged: onChanged,
        );
      },
    );
  }
}

/// Simple vertical list of [MediaListTile]s.
class MediaListView extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onTap;
  final void Function(MediaItem item)? onLongPress;
  final Widget? Function(MediaItem item)? trailingBuilder;
  final Set<int>? selectedIds;
  final bool isSelecting;
  final VoidCallback? onChanged;

  const MediaListView({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.trailingBuilder,
    this.selectedIds,
    this.isSelecting = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectable = isSelecting || (selectedIds?.isNotEmpty ?? false);
    return ListView.separated(
      padding: UIHelper.listPadding,
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaListTile(
          item: item,
          isSelecting: selectable,
          selected: selectedIds?.contains(item.id) ?? false,
          onTap: () => onTap(item),
          onLongPress: onLongPress == null ? null : () => onLongPress!(item),
          trailing: trailingBuilder?.call(item),
          onChanged: onChanged,
        );
      },
    );
  }
}
