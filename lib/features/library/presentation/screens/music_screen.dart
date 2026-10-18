import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/permissions/media_access_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/library_page_header.dart';
import '../../../../shared/widgets/library_scan_progress_bar.dart';
import '../controllers/library_prefs_controller.dart';
import '../controllers/music_controller.dart';
import '../controllers/selection_controller.dart';
import '../widgets/folders_view.dart';
import '../widgets/library_access.dart';
import '../widgets/library_items_view.dart';
import '../widgets/library_selection_actions.dart';
import '../widgets/selection_app_bar.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicControllerProvider);
    final controller = ref.read(musicControllerProvider.notifier);
    final selection = ref.watch(selectionControllerProvider);
    final selectionNotifier = ref.read(selectionControllerProvider.notifier);
    final prefs = ref.watch(libraryPrefsValueProvider);
    final isSelecting = selection.isSelecting;
    final count =
        ref.watch(musicLibraryCountProvider).value ??
        state.asData?.value.length ??
        0;
    final isScanning = ref.watch(libraryScanProgressProvider).isScanning;
    final hasAccess = ref.watch(mediaAccessProvider);

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
                  data: (items) =>
                      selectionNotifier.replaceAll(items.map((e) => e.id!)),
                  orElse: () {},
                );
              },
              onDelete: () => deleteSelected(context, ref, controller.reload),
              onRename: () => renameSelected(context, ref, controller.reload),
            )
          : AppBar(
              title: const Text('Music'),
              actions: [
                LibraryHeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: isScanning
                      ? 'Scanning…'
                      : 'Scan device music',
                  onPressed: isScanning ? null : controller.scan,
                ),
                if (!prefs.isFolders)
                  LibraryHeaderAction(
                    icon: prefs.isGrid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    tooltip: prefs.isGrid ? 'List view' : 'Grid view',
                    onPressed: () =>
                        ref.read(libraryPrefsProvider.notifier).toggleLayout(),
                  ),
                LibraryHeaderAction(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onPressed: () => context.push(AppRouter.search),
                ),
                UIHelper.hXS,
              ],
            ),
      body: Column(
        children: [
          const LibraryScanProgressBar(title: 'Scanning music'),
          Expanded(
            child: state.when(
              loading: () => const LibraryLoadingState(
                title: 'Music',
                icon: Icons.music_note_rounded,
              ),
              error: (e, _) => ErrorState(
                message:
                    'Could not load music. Pull to refresh or tap Retry.\n${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}',
                actionLabel: 'Retry',
                onAction: controller.reload,
              ),
              data: (items) {
                return Column(
                  children: [
                    if (!isSelecting)
                      LibraryPageHeader(
                        title: 'Your music',
                        subtitle:
                            '$count track${count == 1 ? '' : 's'} in your library',
                        icon: Icons.music_note_rounded,
                      ),
                    Expanded(
                      child: items.isEmpty
                          ? (hasAccess
                                ? EmptyState(
                                    message: 'No music in your library yet.',
                                    actionLabel: 'Scan device music',
                                    onAction: isScanning ? null : controller.scan,
                                    icon: Icons.library_music_outlined,
                                  )
                                : LibraryAccessEmptyState(
                                    isAudio: true,
                                    isScanning: isScanning,
                                  ))
                          : LibraryBody(
                              items: items,
                              prefs: prefs,
                              isSelecting: isSelecting,
                              isAudio: true,
                              onViewChanged: (v) => ref
                                  .read(libraryPrefsProvider.notifier)
                                  .setView(v),
                              child: prefs.isFolders
                                  ? FoldersView(
                                      items: items,
                                      isAudio: true,
                                      onRefresh: controller.reload,
                                    )
                                  : LibraryItemsView(
                                      items: items,
                                      onRefresh: controller.reload,
                                      onItemsChanged: controller.reload,
                                    ),
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
}
