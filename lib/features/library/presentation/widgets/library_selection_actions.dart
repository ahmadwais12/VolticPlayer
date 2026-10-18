import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../controllers/selection_controller.dart';

/// Deletes every selected item after a confirmation dialog, then invokes
/// [reload] so the host screen reflects the removal.
Future<void> deleteSelected(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() reload,
) async {
  final selection = ref.read(selectionControllerProvider);
  final count = selection.selected.length;
  if (count == 0) return;
  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Delete $count item${count == 1 ? '' : 's'}?',
    message:
        'This will permanently delete the selected file(s) from your '
        'device. This cannot be undone.',
    confirmLabel: 'Delete',
    isDestructive: true,
  );
  if (!confirmed) return;
  final media = ref.read(mediaRepositoryProvider);
  for (final id in selection.selected) {
    await media.deleteMedia(id);
  }
  ref.read(selectionControllerProvider.notifier).clear();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $count item${count == 1 ? '' : 's'}')),
    );
  }
  await reload();
}

/// Renames one selected item, or applies a base name + number pattern when
/// multiple items are selected (e.g. Song, Song (2), Song (3)).
Future<void> renameSelected(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() reload,
) async {
  final selection = ref.read(selectionControllerProvider);
  final ids = selection.selected.toList();
  if (ids.isEmpty) return;

  final media = ref.read(mediaRepositoryProvider);

  if (ids.length == 1) {
    final item = await media.getById(ids.first);
    if (item == null || !context.mounted) return;
    final name = await promptRename(context, item.displayName);
    if (name == null || name.isEmpty) return;
    await media.renameMedia(item.id!, name);
  } else {
    if (!context.mounted) return;
    final base = await promptRename(
      context,
      'Item',
      title: 'Rename ${ids.length} items',
      hint: 'Base name (numbers will be added)',
    );
    if (base == null || base.isEmpty) return;
    var index = 1;
    for (final id in ids) {
      final name = index == 1 ? base : '$base ($index)';
      await media.renameMedia(id, name);
      index++;
    }
  }

  ref.read(selectionControllerProvider.notifier).clear();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ids.length == 1
              ? 'Renamed'
              : 'Renamed ${ids.length} items',
        ),
      ),
    );
  }
  await reload();
}

/// Text-input dialog for renaming; returns null when cancelled.
Future<String?> promptRename(
  BuildContext context,
  String current, {
  String title = 'Rename',
  String? hint,
}) async {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: hint == null ? null : InputDecoration(hintText: hint),
        onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
