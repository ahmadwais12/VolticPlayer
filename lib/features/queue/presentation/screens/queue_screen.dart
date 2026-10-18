import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';

/// A simulated queue state for the queue screen.
/// In production, wire this to a global queue provider.
class QueueItem {
  final int? mediaId;
  final String title;
  final String? artist;
  final Duration duration;
  final bool isPlaying;

  const QueueItem({
    this.mediaId,
    required this.title,
    this.artist,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });
}

class QueueNotifier extends Notifier<List<QueueItem>> {
  @override
  List<QueueItem> build() => [];

  void setQueue(List<QueueItem> items) => state = items;

  void addItem(QueueItem item) => state = [...state, item];

  void removeAt(int index) {
    final newList = List<QueueItem>.from(state);
    newList.removeAt(index);
    state = newList;
  }

  void move(int from, int to) {
    final newList = List<QueueItem>.from(state);
    final item = newList.removeAt(from);
    newList.insert(to, item);
    state = newList;
  }

  void clear() => state = [];

  /// Save current queue as a new playlist.
  Future<void> saveAsPlaylist(WidgetRef ref, String name) async {
    final playlistRepo = ref.read(playlistRepositoryProvider);
    final playlistId = await playlistRepo.create(name);
    // Add all queue items to the playlist if they have media IDs
    for (final item in state) {
      if (item.mediaId != null) {
        await playlistRepo.addItem(playlistId, item.mediaId!);
      }
    }
  }
}

final queueProvider =
    NotifierProvider<QueueNotifier, List<QueueItem>>(
  () => QueueNotifier(),
);

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Queue (${queue.length})'),
        actions: [
          if (queue.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Save as playlist',
              onPressed: () => _showSavePlaylistDialog(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear queue',
              onPressed: () {
                ref.read(queueProvider.notifier).clear();
              },
            ),
          ],
        ],
      ),
      body: queue.isEmpty
          ? UIHelper.emptyState(
              context: context,
              icon: Icons.queue_music,
              message: 'Queue is empty.\nAdd media to start building your queue.',
            )
          : ReorderableListView.builder(
              padding: UIHelper.screenPadding,
              itemCount: queue.length,
              onReorder: (from, to) {
                ref.read(queueProvider.notifier).move(from, to);
              },
              itemBuilder: (context, index) {
                final item = queue[index];
                return Card(
                  key: ValueKey('$index-${item.title}'),
                  margin: const EdgeInsets.only(bottom: UIHelper.spaceXS),
                  child: ListTile(
                    leading: item.isPlaying
                        ? Icon(Icons.play_circle_filled,
                            color: Theme.of(context).colorScheme.primary)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item.artist != null
                        ? Text(item.artist!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            ref.read(queueProvider.notifier).removeAt(index);
                          },
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSavePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Queue as Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            hintText: 'My Queue',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(queueProvider.notifier).saveAsPlaylist(ref, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
