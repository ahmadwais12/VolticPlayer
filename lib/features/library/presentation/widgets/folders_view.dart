import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../shared/media_folders.dart';
import '../../../../shared/widgets/folder_tile.dart';

/// Media grouped by device folder — one row per folder showing its name
/// and item count ("150 songs"). Tapping a folder opens its contents.
class FoldersView extends StatelessWidget {
  final List<MediaItem> items;
  final bool isAudio;
  final Future<void> Function()? onRefresh;

  const FoldersView({
    super.key,
    required this.items,
    required this.isAudio,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final folders = groupMediaByFolder(items);
    final content = ListView(
      padding: UIHelper.listPadding,
      children: [
        for (final folder in folders)
          Padding(
            padding: const EdgeInsets.only(bottom: UIHelper.spaceSM),
            child: FolderTile(
              folder: folder,
              isAudio: isAudio,
              onTap: () => context.push(
                AppRouter.mediaFolder,
                extra: {
                  'path': folder.path,
                  'name': folder.name,
                  'isAudio': isAudio,
                },
              ),
            ),
          ),
      ],
    );
    if (onRefresh == null) return content;
    return RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}
