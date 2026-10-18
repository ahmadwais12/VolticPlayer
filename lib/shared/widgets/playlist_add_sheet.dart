import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/library_entities.dart';

/// A bottom sheet that lets the user pick a playlist to add media to.
///
/// Can be used from any screen that needs "add to playlist" functionality.
class PlaylistAddSheet extends ConsumerWidget {
  final int mediaId;
  final VoidCallback? onAdded;

  const PlaylistAddSheet({
    super.key,
    required this.mediaId,
    this.onAdded,
  });

  /// Convenience method to show the sheet.
  static Future<void> show(
    BuildContext context, {
    required int mediaId,
    VoidCallback? onAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIHelper.radiusLG),
        ),
      ),
      builder: (_) => PlaylistAddSheet(
        mediaId: mediaId,
        onAdded: onAdded,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepositoryProvider);
    final theme = Theme.of(context);

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
                Expanded(
                  child: Text(
                    'Add to Playlist',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createPlaylist(context, ref),
                ),
              ],
            ),
          ),
          UIHelper.vSM,
          const Divider(height: 1),
          FutureBuilder<List<Playlist>>(
            future: repo.getAll(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return UIHelper.loadingState();
              }
              final playlists = snapshot.data!;
              if (playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(UIHelper.spaceXL),
                  child: Column(
                    children: [
                      Text(
                        'No playlists yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      UIHelper.vSM,
                      FilledButton.tonal(
                        onPressed: () => _createPlaylist(context, ref),
                        child: const Text('Create Playlist'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, i) {
                  final p = playlists[i];
                  return ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(p.name),
                    subtitle: Text(p.type),
                    onTap: () async {
                      await ref
                          .read(playlistRepositoryProvider)
                          .addItem(p.id!, mediaId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${p.name}"'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        onAdded?.call();
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _createPlaylist(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(playlistRepositoryProvider).create(name);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
