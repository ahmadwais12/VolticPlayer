import 'package:flutter/material.dart';

/// Replaces the normal AppBar while multi-select mode is active.
/// Shared by the Videos / Music / folder / playlist screens.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  /// When set, shows a "remove from playlist" action (playlist detail only).
  final VoidCallback? onRemoveFromList;

  const SelectionAppBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDelete,
    required this.onRename,
    this.onRemoveFromList,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onCancel,
        tooltip: 'Cancel selection',
      ),
      title: Text(
        '$count selected',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: onSelectAll,
          tooltip: 'Select all',
        ),
        if (onRemoveFromList != null)
          IconButton(
            icon: const Icon(Icons.playlist_remove_rounded),
            onPressed: onRemoveFromList,
            tooltip: 'Remove from playlist',
          ),
        IconButton(
          icon: Icon(Icons.drive_file_rename_outline,
              color: theme.colorScheme.onSurface),
          onPressed: onRename,
          tooltip: count > 1 ? 'Rename all' : 'Rename',
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}
