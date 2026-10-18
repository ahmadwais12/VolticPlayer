import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../features/library/presentation/controllers/selection_controller.dart';
import '../../../../features/library/presentation/widgets/library_selection_actions.dart';
import '../../../../features/library/presentation/widgets/selection_app_bar.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/poster_image.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/shell_fab.dart';
import '../controllers/playlist_detail_controller.dart';

final _playlistMetaProvider = FutureProvider.family<Playlist?, int>((
  ref,
  id,
) async {
  return ref.watch(playlistRepositoryProvider).getById(id);
});

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final int playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _shuffleEnabled = false;
  bool _repeatEnabled = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = playlistDetailControllerProvider(widget.playlistId);
    final asyncState = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final selection = ref.watch(playlistDetailSelectionControllerProvider);
    final selectionNotifier = ref.read(
      playlistDetailSelectionControllerProvider.notifier,
    );
    final theme = Theme.of(context);
    final isSelecting = selection.isSelecting;

    return Scaffold(
      appBar: isSelecting
          ? SelectionAppBar(
              count: selection.count,
              onCancel: selectionNotifier.clear,
              onSelectAll: () {
                final items = asyncState.asData?.value ?? const <MediaItem>[];
                final ids = _filter(items).map((e) => e.id).whereType<int>();
                selectionNotifier.selectAll(ids);
              },
              onRemoveFromList: () => _removeSelected(controller),
              onRename: () => _renameSelected(controller),
              onDelete: () => _deleteSelected(controller),
            )
          : AppBar(
              title: const Text('Playlist'),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: _shuffleEnabled ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () {
                    setState(() => _shuffleEnabled = !_shuffleEnabled);
                    HapticFeedback.lightImpact();
                  },
                  tooltip: 'Shuffle',
                ),
                IconButton(
                  icon: Icon(
                    Icons.repeat,
                    color: _repeatEnabled ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () {
                    setState(() => _repeatEnabled = !_repeatEnabled);
                    HapticFeedback.lightImpact();
                  },
                  tooltip: 'Repeat',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'play_all') _playAll();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'play_all', child: Text('Play all')),
                    PopupMenuItem(
                      value: 'share',
                      child: Text('Share playlist'),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: isSelecting
          ? null
          : ShellFab(
              child: FloatingActionButton.extended(
                onPressed: () => _addMedia(
                  asyncState.asData?.value ?? const <MediaItem>[],
                  controller,
                ),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Add media'),
              ),
            ),
      body: asyncState.when(
        loading: () => UIHelper.loadingState(),
        error: (e, _) => UIHelper.errorState(
          context: context,
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: controller.reload,
        ),
        data: (items) {
          final filtered = _filter(items);
          return Column(
            children: [
              if (!isSelecting) _buildHeader(theme, items),
              if (!isSelecting) _buildSearchBar(theme),
              Expanded(
                child: items.isEmpty
                    ? _buildEmpty(theme)
                    : filtered.isEmpty
                    ? UIHelper.emptyState(
                        context: context,
                        icon: Icons.search_off,
                        message: 'No items match "$_query".',
                      )
                    : _buildList(
                        context,
                        controller,
                        filtered,
                        isSelecting,
                        selection.selected,
                        selectionNotifier,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<MediaItem> _filter(List<MediaItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return item.displayName.toLowerCase().contains(q) ||
          (item.artist?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _removeSelected(PlaylistDetailController controller) async {
    final selection = ref.read(playlistDetailSelectionControllerProvider);
    final count = selection.count;
    if (count == 0) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove $count item${count == 1 ? '' : 's'}?',
      message:
          'Items will be removed from this playlist only. '
          'Files on your device are kept.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    for (final id in selection.selected) {
      await controller.removeItem(id);
    }
    ref.read(playlistDetailSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $count item${count == 1 ? '' : 's'}')),
      );
    }
  }

  Future<void> _deleteSelected(PlaylistDetailController controller) async {
    final selection = ref.read(playlistDetailSelectionControllerProvider);
    final count = selection.count;
    if (count == 0) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete $count item${count == 1 ? '' : 's'}?',
      message:
          'This will permanently delete the selected file(s) from your '
          'device and remove them from this playlist.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final media = ref.read(mediaRepositoryProvider);
    for (final id in selection.selected) {
      await media.deleteMedia(id);
    }
    ref.read(playlistDetailSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $count item${count == 1 ? '' : 's'}')),
      );
    }
    await controller.reload();
  }

  Future<void> _renameSelected(PlaylistDetailController controller) async {
    final selection = ref.read(playlistDetailSelectionControllerProvider);
    final ids = selection.selected.toList();
    if (ids.isEmpty) return;
    final media = ref.read(mediaRepositoryProvider);

    if (ids.length == 1) {
      final item = await media.getById(ids.first);
      if (item == null || !mounted) return;
      final name = await promptRename(context, item.displayName);
      if (name == null || name.isEmpty) return;
      await media.renameMedia(item.id!, name);
    } else {
      if (!mounted) return;
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

    ref.read(playlistDetailSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1 ? 'Renamed' : 'Renamed ${ids.length} items',
          ),
        ),
      );
    }
    await controller.reload();
  }

  Widget _buildHeader(ThemeData theme, List<MediaItem> items) {
    final metaAsync = ref.watch(_playlistMetaProvider(widget.playlistId));
    final playlist = metaAsync.value;
    final name = playlist?.name ?? 'Playlist';
    final isVideo = playlist?.type == 'video';
    final isAudio = playlist?.type == 'audio';
    final icon = isVideo
        ? Icons.movie_rounded
        : isAudio
        ? Icons.music_note_rounded
        : Icons.queue_music_rounded;

    final totalDuration = items.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + Duration(milliseconds: item.durationMs),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        UIHelper.spaceMD,
        UIHelper.spaceSM,
        UIHelper.spaceMD,
        UIHelper.spaceMD,
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UIHelper.radiusMD),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primary.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.9,
              ),
            ),
          ),
          UIHelper.hMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                UIHelper.vXS,
                Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}  ·  ${_formatDuration(totalDuration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIHelper.spaceMD,
        UIHelper.spaceXS,
        UIHelper.spaceMD,
        UIHelper.spaceSM,
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search in playlist…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                    HapticFeedback.lightImpact();
                  },
                ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: UIHelper.spaceMD,
            vertical: UIHelper.spaceSM,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return UIHelper.emptyState(
      context: context,
      icon: Icons.playlist_play,
      message: 'This playlist is empty.\nBrowse media to add items.',
    );
  }

  Widget _buildList(
    BuildContext context,
    PlaylistDetailController controller,
    List<MediaItem> items,
    bool isSelecting,
    Set<int> selectedIds,
    SelectionController selectionNotifier,
  ) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          UIHelper.spaceXS,
          UIHelper.spaceMD,
          UIHelper.spaceXL,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = item.id;
          final selected = id != null && selectedIds.contains(id);
          return Card(
            key: ValueKey('playlist_item_$id'),
            margin: const EdgeInsets.only(bottom: UIHelper.spaceSM),
            elevation: 0,
            color: selected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIHelper.radiusMD),
              side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: UIHelper.spaceMD,
                vertical: UIHelper.spaceXS,
              ),
              leading: isSelecting
                  ? Checkbox(
                      value: selected,
                      onChanged: id == null
                          ? null
                          : (_) => selectionNotifier.toggle(id),
                    )
                  : _ItemThumb(item: item, index: index),
              title: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.artist ?? item.extension.toUpperCase()}'
                  '${item.durationMs > 0 ? '  ·  ${_formatDuration(Duration(milliseconds: item.durationMs))}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              trailing: isSelecting
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: 'Options',
                      onSelected: (value) async {
                        switch (value) {
                          case 'play':
                            openMedia(context, item);
                          case 'rename':
                            await _renameSingle(item, controller);
                          case 'remove':
                            await _removeSingle(item, controller);
                          case 'delete':
                            await _deleteSingle(item, controller);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'play', child: Text('Play')),
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from playlist'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete file'),
                        ),
                      ],
                    ),
              onTap: () {
                if (isSelecting) {
                  if (id != null) selectionNotifier.toggle(id);
                } else {
                  openMedia(context, item);
                }
              },
              onLongPress: () {
                if (id == null) return;
                selectionNotifier.toggle(id);
                HapticFeedback.mediumImpact();
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameSingle(
    MediaItem item,
    PlaylistDetailController controller,
  ) async {
    final id = item.id;
    if (id == null) return;
    final name = await promptRename(context, item.displayName);
    if (name == null || name.isEmpty || name == item.displayName) return;
    await ref.read(mediaRepositoryProvider).renameMedia(id, name);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Renamed')));
    }
    await controller.reload();
  }

  Future<void> _removeSingle(
    MediaItem item,
    PlaylistDetailController controller,
  ) async {
    final id = item.id;
    if (id == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove from playlist?',
      message: '"${item.displayName}" will be removed from this playlist only.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    await controller.removeItem(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from playlist')));
    }
  }

  Future<void> _deleteSingle(
    MediaItem item,
    PlaylistDetailController controller,
  ) async {
    final id = item.id;
    if (id == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete file?',
      message:
          'This will permanently delete "${item.displayName}" from your device.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(mediaRepositoryProvider).deleteMedia(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File deleted')));
    }
    await controller.reload();
  }

  void _playAll() {
    final asyncState = ref.read(
      playlistDetailControllerProvider(widget.playlistId),
    );
    asyncState.whenData((items) {
      if (items.isNotEmpty) {
        final first = items.first;
        if (first.isVideo) {
          context.push(
            AppRouter.videoPlayer,
            extra: {
              'uri': first.uri,
              'title': first.displayName,
              'thumbnailPath': first.thumbnailPath,
            },
          );
        } else {
          context.push(
            AppRouter.audioPlayer,
            extra: {
              'uri': first.uri,
              'title': first.displayName,
              'artist': first.artist,
            },
          );
        }
      }
    });
  }

  Future<void> _addMedia(
    List<MediaItem> currentItems,
    PlaylistDetailController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PlaylistMediaPicker(
        playlistId: widget.playlistId,
        existingIds: currentItems
            .map((item) => item.id)
            .whereType<int>()
            .toSet(),
        onAdded: controller.reload,
      ),
    );
  }
}

class _PlaylistMediaPicker extends ConsumerStatefulWidget {
  const _PlaylistMediaPicker({
    required this.playlistId,
    required this.existingIds,
    required this.onAdded,
  });

  final int playlistId;
  final Set<int> existingIds;
  final Future<void> Function() onAdded;

  @override
  ConsumerState<_PlaylistMediaPicker> createState() =>
      _PlaylistMediaPickerState();
}

class _PlaylistMediaPickerState extends ConsumerState<_PlaylistMediaPicker> {
  late final Future<List<MediaItem>> _media = _loadMedia();
  final _searchController = TextEditingController();
  String _query = '';
  late final Set<int> _addedIds = {...widget.existingIds};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<MediaItem>> _loadMedia() async {
    final repo = ref.read(mediaRepositoryProvider);
    var lists = await Future.wait([repo.getVideos(), repo.getAudio()]);
    if (lists.every((items) => items.isEmpty)) {
      final progress = ref.read(libraryScanProgressProvider.notifier);
      final scanClock = Stopwatch()..start();
      progress.begin(0);
      try {
        await repo.scan(onProgress: progress.update);
      } finally {
        final remaining = const Duration(seconds: 3) - scanClock.elapsed;
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        if (mounted) progress.complete();
      }
      if (!mounted) return const [];
      lists = await Future.wait([repo.getVideos(), repo.getAudio()]);
    }
    final items = lists.expand((list) => list).toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add videos and music', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search your library',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MediaItem>>(
              future: _media,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load media: ${snapshot.error}'),
                  );
                }
                final query = _query.trim().toLowerCase();
                final items = (snapshot.data ?? const <MediaItem>[])
                    .where(
                      (item) => item.displayName.toLowerCase().contains(query),
                    )
                    .toList();
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? 'No videos or music found.'
                          : 'No media matches “$_query”.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final added = _addedIds.contains(item.id);
                    return ListTile(
                      leading: Icon(
                        item.isAudio
                            ? Icons.music_note_rounded
                            : Icons.movie_rounded,
                      ),
                      title: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(item.isAudio ? 'Music' : 'Video'),
                      trailing: IconButton(
                        tooltip: added ? 'Already added' : 'Add to playlist',
                        onPressed: added ? null : () => _add(item),
                        icon: Icon(
                          added ? Icons.check_circle : Icons.add_circle_outline,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(MediaItem item) async {
    final id = item.id;
    if (id == null) return;
    await ref.read(playlistRepositoryProvider).addItem(widget.playlistId, id);
    if (!mounted) return;
    setState(() => _addedIds.add(id));
    await widget.onAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added “${item.displayName}” to playlist')),
      );
    }
  }
}

class _ItemThumb extends StatelessWidget {
  final MediaItem item;
  final int index;

  const _ItemThumb({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(UIHelper.radiusSM),
          child: SizedBox(
            width: 52,
            height: 52,
            child: item.thumbnailPath?.isNotEmpty == true
                ? PosterImage(
                    path: item.thumbnailPath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: item.isAudio
                        ? Icons.music_note_rounded
                        : Icons.movie_rounded,
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      item.isAudio ? Icons.music_note : Icons.movie,
                      color: theme.colorScheme.outline,
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
