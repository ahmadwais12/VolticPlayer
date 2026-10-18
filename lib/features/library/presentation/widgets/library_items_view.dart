import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_grid.dart';
import '../controllers/library_prefs_controller.dart';
import '../controllers/selection_controller.dart';

/// Grid / list content area shared by the Videos, Music and folder screens.
///
/// The layout comes from the persisted [libraryPrefsValueProvider] so the
/// user's grid/list choice applies everywhere at once. Tap opens (or
/// toggles selection), long-press enters selection mode.
class LibraryItemsView extends ConsumerWidget {
  final List<MediaItem> items;

  /// When non-null, wraps the view in a pull-to-refresh indicator.
  final Future<void> Function()? onRefresh;

  /// Called after more-menu actions (rename/delete) so the host can reload.
  final Future<void> Function()? onItemsChanged;

  /// Overrides the default player navigation (used by tests / previews).
  final void Function(MediaItem item)? onOpen;

  const LibraryItemsView({
    super.key,
    required this.items,
    this.onRefresh,
    this.onItemsChanged,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(libraryPrefsValueProvider);
    final selection = ref.watch(selectionControllerProvider);
    final selectionNotifier = ref.read(selectionControllerProvider.notifier);
    final isSelecting = selection.isSelecting;

    void handleTap(MediaItem item) {
      if (isSelecting) {
        selectionNotifier.toggle(item.id!);
      } else if (onOpen != null) {
        onOpen!(item);
      } else {
        openMedia(context, item);
      }
    }

    void handleLongPress(MediaItem item) {
      selectionNotifier.toggle(item.id!);
      HapticFeedback.mediumImpact();
    }

    final Widget content = prefs.isGrid
        ? MediaGridView(
            items: items,
            isSelecting: isSelecting,
            selectedIds: selection.selected,
            onChanged: onItemsChanged,
            onTap: handleTap,
            onLongPress: handleLongPress,
          )
        : MediaListView(
            items: items,
            isSelecting: isSelecting,
            selectedIds: selection.selected,
            onChanged: onItemsChanged,
            onTap: handleTap,
            onLongPress: handleLongPress,
          );

    if (onRefresh == null) return content;
    return RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}

/// Folders ⇄ All switcher above library content; hidden during selection.
/// [child] is the current view (folders or items).
class LibraryBody extends StatelessWidget {
  final List<MediaItem> items;
  final LibraryPrefs prefs;
  final bool isSelecting;
  final bool isAudio;
  final ValueChanged<String> onViewChanged;
  final Widget child;

  const LibraryBody({
    super.key,
    required this.items,
    required this.prefs,
    required this.isSelecting,
    required this.isAudio,
    required this.onViewChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAudio ? 'music tracks' : 'videos';
    return Semantics(
      label: '${items.length} $label',
      child: Column(
        children: [
          if (!isSelecting)
            LibraryViewSwitcher(
              value: prefs.view,
              allIcon: isAudio
                  ? Icons.library_music_outlined
                  : Icons.video_library_outlined,
              onChanged: onViewChanged,
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Folders ⇄ All segmented switcher shown above library content.
class LibraryViewSwitcher extends StatelessWidget {
  final String value; // 'folders' | 'all'
  final ValueChanged<String> onChanged;
  final IconData allIcon;

  const LibraryViewSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.allIcon = Icons.video_library_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIHelper.spaceMD,
        UIHelper.spaceSM,
        UIHelper.spaceMD,
        0,
      ),
      child: SegmentedButton<String>(
        segments: [
          const ButtonSegment(
            value: 'folders',
            label: Text('Folders'),
            icon: Icon(Icons.folder_outlined),
          ),
          ButtonSegment(
            value: 'all',
            label: const Text('All'),
            icon: Icon(allIcon),
          ),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
