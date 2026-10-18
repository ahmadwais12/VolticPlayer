import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/media_folders.dart';
import '../../../../shared/widgets/app_states.dart';
import '../controllers/library_prefs_controller.dart';
import '../controllers/music_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/videos_controller.dart';
import '../widgets/library_items_view.dart';
import '../widgets/library_selection_actions.dart';
import '../widgets/selection_app_bar.dart';

/// Contents of a single device folder, opened by tapping a row in the
/// folders view. Shows the folder's videos (or songs) in the currently
/// chosen grid/list layout.
class MediaFolderScreen extends ConsumerWidget {
  final String folderPath;
  final String folderName;
  final bool isAudio;

  const MediaFolderScreen({
    super.key,
    required this.folderPath,
    required this.folderName,
    this.isAudio = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = isAudio
        ? ref.watch(musicControllerProvider)
        : ref.watch(videosControllerProvider);
    final selection = ref.watch(selectionControllerProvider);
    final selectionNotifier = ref.read(selectionControllerProvider.notifier);
    final prefs = ref.watch(libraryPrefsValueProvider);
    final isSelecting = selection.isSelecting;

    Future<void> reload() async {
      if (isAudio) {
        await ref.read(musicControllerProvider.notifier).reload();
      } else {
        await ref.read(videosControllerProvider.notifier).reload();
      }
    }

    return Scaffold(
      appBar: isSelecting
          ? SelectionAppBar(
              count: selection.selected.length,
              onCancel: () {
                selectionNotifier.clear();
                HapticFeedback.lightImpact();
              },
              onSelectAll: () {
                state.maybeWhen(
                  data: (items) {
                    final inFolder = items
                        .where((i) => folderPathOf(i) == folderPath)
                        .map((e) => e.id!);
                    selectionNotifier.replaceAll(inFolder);
                  },
                  orElse: () {},
                );
              },
              onDelete: () => deleteSelected(context, ref, reload),
              onRename: () => renameSelected(context, ref, reload),
            )
          : AppBar(
              title: Text(folderName),
              actions: [
                IconButton(
                  icon: Icon(prefs.isGrid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded),
                  onPressed: () =>
                      ref.read(libraryPrefsProvider.notifier).toggleLayout(),
                  tooltip: prefs.isGrid ? 'List view' : 'Grid view',
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push(AppRouter.search),
                  tooltip: 'Search',
                ),
              ],
            ),
      body: state.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: reload,
        ),
        data: (items) {
          final inFolder = items
              .where((i) => folderPathOf(i) == folderPath)
              .toList();
          if (inFolder.isEmpty) {
            return const EmptyState(
              message: 'This folder has no media left.',
            );
          }
          return LibraryItemsView(
            items: inFolder,
            onRefresh: reload,
            onItemsChanged: reload,
          );
        },
      ),
    );
  }
}
