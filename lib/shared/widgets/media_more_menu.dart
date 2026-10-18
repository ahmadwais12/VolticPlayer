import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/media_item.dart';
import '../media_navigation.dart';
import 'confirm_dialog.dart';
import 'playlist_add_sheet.dart';

/// A "more" (⋯) bottom-sheet menu for a media item (video/audio).
///
/// Offers: Play, Favorite, Add to Playlist, Rename, Share and Delete.
/// After any mutation the [onChanged] callback fires so the owning screen
/// can reload its data.
class MediaMoreMenu extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback? onChanged;

  const MediaMoreMenu({super.key, required this.item, this.onChanged});

  /// Convenience method to open the menu.
  static Future<void> show(
    BuildContext context, {
    required MediaItem item,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIHelper.radiusLG),
        ),
      ),
      builder: (_) => MediaMoreMenu(item: item, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final media = ref.watch(mediaRepositoryProvider);
    final library = ref.watch(libraryRepositoryProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UIHelper.vSM,
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          UIHelper.vSM,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceMD),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        item.isAudio
                            ? Icons.music_note_rounded
                            : Icons.movie_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                UIHelper.hMD,
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          UIHelper.vSM,
          const Divider(height: 1),
          _ActionTile(
            icon: Icons.play_arrow_rounded,
            label: 'Play',
            onTap: () {
              Navigator.pop(context);
              openMedia(context, item);
            },
          ),
          _ActionTile(
            icon: item.isFavorite ? Icons.favorite : Icons.favorite_border,
            label: item.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onTap: () async {
              await library.toggleFavorite(item.id!, !item.isFavorite);
              if (context.mounted) Navigator.pop(context);
              onChanged?.call();
            },
          ),
          _ActionTile(
            icon: Icons.playlist_add,
            label: 'Add to Playlist',
            onTap: () {
              Navigator.pop(context);
              PlaylistAddSheet.show(
                context,
                mediaId: item.id!,
                onAdded: onChanged,
              );
            },
          ),
          _ActionTile(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
            onTap: () async {
              final newName = await _promptRename(context, item.displayName);
              if (context.mounted && newName != null) {
                Navigator.pop(context);
                await media.renameMedia(item.id!, newName);
                onChanged?.call();
              }
            },
          ),
          _ActionTile(
            icon: Icons.share,
            label: 'Share',
            onTap: () {
              Navigator.pop(context);
              _share(item);
            },
          ),
          _ActionTile(
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: true,
            onTap: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Delete "${item.displayName}"?',
                message: 'This will permanently delete the file from your '
                    'device. This cannot be undone.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (context.mounted && confirmed) {
                Navigator.pop(context);
                await media.deleteMedia(item.id!);
                HapticFeedback.mediumImpact();
                onChanged?.call();
              }
            },
          ),
          UIHelper.vSM,
        ],
      ),
    );
  }

  Future<String?> _promptRename(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
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

  Future<void> _share(MediaItem item) async {
    final text = item.uri.isNotEmpty && item.uri.startsWith('http')
        ? item.uri
        : item.path.isNotEmpty
            ? item.path
            : item.displayName;
    await Share.share(text);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
