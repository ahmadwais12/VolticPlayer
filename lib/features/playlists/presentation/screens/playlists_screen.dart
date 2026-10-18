import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../features/library/presentation/controllers/selection_controller.dart';
import '../../../../features/library/presentation/widgets/library_selection_actions.dart';
import '../../../../features/library/presentation/widgets/selection_app_bar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/library_page_header.dart';
import '../../../../shared/widgets/library_scan_progress_bar.dart';
import '../../../../shared/widgets/shell_fab.dart';
import '../controllers/playlists_controller.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _isGrid = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistsControllerProvider);
    final controller = ref.read(playlistsControllerProvider.notifier);
    final selection = ref.watch(playlistSelectionControllerProvider);
    final selectionNotifier = ref.read(
      playlistSelectionControllerProvider.notifier,
    );
    final theme = Theme.of(context);
    final isSelecting = selection.isSelecting;

    return Scaffold(
      appBar: isSelecting
          ? SelectionAppBar(
              count: selection.count,
              onCancel: selectionNotifier.clear,
              onSelectAll: () {
                final summaries = state.asData?.value ?? const [];
                final ids = _filter(
                  summaries,
                ).map((s) => s.playlist.id).whereType<int>();
                selectionNotifier.selectAll(ids);
              },
              onDelete: () => _deleteSelected(controller),
              onRename: () => _renameSelected(controller),
            )
          : AppBar(
              title: const Text('Playlists'),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: _isGrid ? 'List view' : 'Grid view',
                  icon: Icon(
                    _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  ),
                  onPressed: () => setState(() => _isGrid = !_isGrid),
                ),
              ],
            ),
      floatingActionButton: isSelecting
          ? null
          : ShellFab(
              child: FloatingActionButton.extended(
                onPressed: () => _create(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ),
      body: Column(
        children: [
          const LibraryScanProgressBar(title: 'Scanning library'),
          Expanded(
            child: state.when(
              loading: () => const LibraryLoadingState(
                title: 'Playlists',
                icon: Icons.queue_music_rounded,
              ),
              error: (e, _) => UIHelper.errorState(
                context: context,
                message: e.toString(),
                actionLabel: 'Retry',
                onAction: controller.reload,
              ),
              data: (summaries) {
                final filtered = _filter(summaries);
                return Column(
                  children: [
                    if (!isSelecting)
                      LibraryPageHeader(
                        title: 'Playlists',
                        subtitle:
                            '${summaries.length} playlist${summaries.length == 1 ? '' : 's'} saved locally',
                        icon: Icons.queue_music_rounded,
                      ),
                    if (!isSelecting) _buildSearchBar(theme),
                    Expanded(
                      child: summaries.isEmpty
                          ? UIHelper.emptyState(
                              context: context,
                              icon: Icons.playlist_play,
                              message:
                                  'No playlists yet.\nTap "New" to create your first playlist.',
                            )
                          : filtered.isEmpty
                          ? UIHelper.emptyState(
                              context: context,
                              icon: Icons.search_off,
                              message: 'No playlists match "$_query".',
                            )
                          : _isGrid
                          ? _buildGrid(
                              context,
                              controller,
                              filtered,
                              theme,
                              isSelecting,
                              selection.selected,
                              selectionNotifier,
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
          ),
        ],
      ),
    );
  }

  List<PlaylistSummary> _filter(List<PlaylistSummary> summaries) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return summaries;
    return summaries
        .where((s) => s.playlist.name.toLowerCase().contains(q))
        .toList();
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
          hintText: 'Search playlists…',
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

  Widget _buildGrid(
    BuildContext context,
    PlaylistsController controller,
    List<PlaylistSummary> summaries,
    ThemeData theme,
    bool isSelecting,
    Set<int> selectedIds,
    SelectionController selectionNotifier,
  ) {
    final columns = UIHelper.responsiveColumns(context);
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          UIHelper.spaceXS,
          UIHelper.spaceMD,
          UIHelper.spaceXL * 1.5,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: UIHelper.spaceMD,
          crossAxisSpacing: UIHelper.spaceMD,
          childAspectRatio: columns >= 4 ? 0.9 : 0.82,
        ),
        itemCount: summaries.length,
        itemBuilder: (context, i) {
          final summary = summaries[i];
          final id = summary.playlist.id;
          final selected = id != null && selectedIds.contains(id);
          return _PlaylistCard(
            summary: summary,
            isSelecting: isSelecting,
            isSelected: selected,
            onTap: () {
              if (isSelecting) {
                if (id != null) selectionNotifier.toggle(id);
              } else {
                context.push('${AppRouter.playlists}/${summary.playlist.id}');
              }
            },
            onLongPress: () {
              if (id == null) return;
              selectionNotifier.toggle(id);
              HapticFeedback.mediumImpact();
            },
            onPlay: () => _play(context, summary),
            onRename: () =>
                _confirmRename(context, controller, summary.playlist),
            onShare: () => _share(context, summary),
            onDelete: () =>
                _confirmDelete(context, controller, summary.playlist),
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    PlaylistsController controller,
    List<PlaylistSummary> summaries,
    bool isSelecting,
    Set<int> selectedIds,
    SelectionController selectionNotifier,
  ) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          UIHelper.spaceXS,
          UIHelper.spaceMD,
          UIHelper.spaceXL * 1.5,
        ),
        itemCount: summaries.length,
        separatorBuilder: (_, __) => UIHelper.vSM,
        itemBuilder: (context, i) {
          final summary = summaries[i];
          final playlist = summary.playlist;
          final id = playlist.id;
          final selected = id != null && selectedIds.contains(id);
          return _PlaylistListTile(
            summary: summary,
            isSelecting: isSelecting,
            isSelected: selected,
            onTap: () {
              if (isSelecting) {
                if (id != null) selectionNotifier.toggle(id);
              } else {
                context.push('${AppRouter.playlists}/$id');
              }
            },
            onLongPress: () {
              if (id == null) return;
              selectionNotifier.toggle(id);
              HapticFeedback.mediumImpact();
            },
            onPlay: () => _play(context, summary),
            onRename: () => _confirmRename(context, controller, playlist),
            onShare: () => _share(context, summary),
            onDelete: () => _confirmDelete(context, controller, playlist),
          );
        },
      ),
    );
  }

  Future<void> _deleteSelected(PlaylistsController controller) async {
    final selection = ref.read(playlistSelectionControllerProvider);
    final count = selection.count;
    if (count == 0) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete $count playlist${count == 1 ? '' : 's'}?',
      message:
          'Selected playlists will be removed. Media files on your device '
          'are not deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    for (final id in selection.selected) {
      await controller.delete(id);
    }
    ref.read(playlistSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $count playlist${count == 1 ? '' : 's'}'),
        ),
      );
    }
  }

  Future<void> _renameSelected(PlaylistsController controller) async {
    final selection = ref.read(playlistSelectionControllerProvider);
    final ids = selection.selected.toList();
    if (ids.isEmpty) return;

    final summaries = ref.read(playlistsControllerProvider).asData?.value ?? [];
    final byId = {
      for (final s in summaries)
        if (s.playlist.id != null) s.playlist.id!: s.playlist,
    };

    if (ids.length == 1) {
      final playlist = byId[ids.first];
      if (playlist == null) return;
      final name = await promptRename(context, playlist.name);
      if (name == null || name.isEmpty || name == playlist.name) return;
      await controller.rename(playlist.id!, name);
    } else {
      final base = await promptRename(
        context,
        'Playlist',
        title: 'Rename ${ids.length} playlists',
        hint: 'Base name (numbers will be added)',
      );
      if (base == null || base.isEmpty) return;
      var index = 1;
      for (final id in ids) {
        final name = index == 1 ? base : '$base ($index)';
        await controller.rename(id, name);
        index++;
      }
    }

    ref.read(playlistSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1 ? 'Renamed' : 'Renamed ${ids.length} playlists',
          ),
        ),
      );
    }
  }

  void _play(BuildContext context, PlaylistSummary summary) {
    context.push('${AppRouter.playlists}/${summary.playlist.id}');
  }

  Future<void> _confirmRename(
    BuildContext context,
    PlaylistsController controller,
    Playlist playlist,
  ) async {
    final name = await promptRename(context, playlist.name);
    if (name != null && name.isNotEmpty && name != playlist.name) {
      await controller.rename(playlist.id!, name);
      if (mounted) {
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(const SnackBar(content: Text('Playlist renamed')));
      }
    }
  }

  Future<void> _share(BuildContext context, PlaylistSummary summary) async {
    await Share.share(
      'Playlist: ${summary.playlist.name} (${summary.itemCount} items)',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlaylistsController controller,
    Playlist playlist,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Playlist',
      message: 'Are you sure you want to delete "${playlist.name}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await controller.delete(playlist.id!);
      if (mounted) {
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
      }
    }
  }

  void _create(BuildContext context, PlaylistsController controller) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          autofocus: true,
          onSubmitted: (_) {
            final name = ctrl.text.trim();
            if (name.isNotEmpty) controller.create(name);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) controller.create(name);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistSummary summary;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.summary,
    required this.isSelecting,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onPlay,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = summary.playlist;
    final isVideo = playlist.type == 'video';
    final isAudio = playlist.type == 'audio';
    final icon = isVideo
        ? Icons.movie_rounded
        : isAudio
        ? Icons.music_note_rounded
        : Icons.queue_music_rounded;
    final label = isVideo
        ? 'Videos'
        : isAudio
        ? 'Music'
        : 'Mixed';

    return Stack(
      children: [
        UIHelper.card(
          radius: UIHelper.radiusMD,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CoverArt(icon: icon, name: playlist.name),
              ),
              UIHelper.vSM,
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              UIHelper.vXS,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message:
                        '${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'}',
                    child: Text(
                      '${summary.itemCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isSelecting)
          Positioned(
            top: UIHelper.spaceSM,
            right: UIHelper.spaceSM,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface.withValues(alpha: 0.9),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
          ),
        if (!isSelecting)
          Positioned(
            top: UIHelper.spaceXS,
            right: UIHelper.spaceXS,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              shape: const CircleBorder(),
              child: PopupMenuButton<String>(
                tooltip: 'Options',
                padding: EdgeInsets.zero,
                iconSize: UIHelper.iconSM,
                onSelected: (value) {
                  switch (value) {
                    case 'play':
                      onPlay();
                    case 'rename':
                      onRename();
                    case 'share':
                      onShare();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'play', child: Text('Play all')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'share', child: Text('Share')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  const _PlaylistListTile({
    required this.summary,
    required this.isSelecting,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onPlay,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  final PlaylistSummary summary;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = summary.playlist;
    final type = playlist.type == 'video'
        ? 'Videos'
        : playlist.type == 'audio'
        ? 'Music'
        : 'Mixed';
    final icon = playlist.type == 'video'
        ? Icons.movie_rounded
        : playlist.type == 'audio'
        ? Icons.music_note_rounded
        : Icons.queue_music_rounded;

    return UIHelper.card(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(UIHelper.spaceSM),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: _CoverArt(icon: icon, name: playlist.name),
          ),
          UIHelper.hSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                UIHelper.vXS,
                Text(
                  '$type · ${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isSelecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceSM),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Options',
              padding: EdgeInsets.zero,
              child: const Padding(
                padding: EdgeInsets.all(UIHelper.spaceSM),
                child: Icon(Icons.more_vert_rounded),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'play':
                    onPlay();
                  case 'rename':
                    onRename();
                  case 'share':
                    onShare();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'play', child: Text('Open playlist')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  final IconData icon;
  final String name;

  const _CoverArt({required this.icon, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.primary.withValues(alpha: 0.75),
    ];

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UIHelper.radiusMD - 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.9,
              ),
            ),
          ),
          Positioned(
            top: UIHelper.spaceSM,
            left: UIHelper.spaceSM,
            child: _TypeChip(typeIcon: icon, useDark: useDark),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData typeIcon;
  final bool useDark;

  const _TypeChip({required this.typeIcon, required this.useDark});

  @override
  Widget build(BuildContext context) {
    final color = useDark ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIHelper.spaceSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
      ),
      child: Icon(typeIcon, size: UIHelper.iconSM, color: color),
    );
  }
}
