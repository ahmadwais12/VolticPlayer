import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_list_tile.dart';
import '../controllers/folders_controller.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foldersControllerProvider);
    final controller = ref.read(foldersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Pick folder',
            onPressed: controller.pickAndScan,
          ),
        ],
      ),
      body: state.when(
        loading: () => UIHelper.loadingState(),
        error: (e, _) => UIHelper.errorState(
          context: context,
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: controller.reload,
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return UIHelper.emptyState(
              context: context,
              icon: Icons.folder_open_outlined,
              message: 'No folders scanned yet.',
              actionLabel: 'Pick a folder',
              onAction: controller.pickAndScan,
            );
          }
          return ListView.separated(
            padding: UIHelper.listPadding,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = groups[i];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(g.name),
                subtitle: Text('${g.items.length} items'),
                onTap: () => _showContents(context, g),
              );
            },
          );
        },
      ),
    );
  }

  void _showContents(BuildContext context, FolderGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIHelper.radiusLG),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (ctx, scroll) => Column(
          children: [
            UIHelper.vSM,
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            UIHelper.vSM,
            Padding(
              padding: UIHelper.cardPadding,
              child: Text(
                group.name,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  for (final item in group.items)
                    MediaListTile(
                      item: item,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        openMedia(context, item);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
