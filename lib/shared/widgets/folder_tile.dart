import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../media_folders.dart';
import 'poster_image.dart';

/// One row in the folders view: folder icon (or a preview from the first
/// item), name and item count (e.g. "150 songs").
/// Tapping opens the folder's contents.
class FolderTile extends StatelessWidget {
  final MediaFolderGroup folder;
  final bool isAudio;
  final VoidCallback? onTap;

  const FolderTile({
    super.key,
    required this.folder,
    required this.isAudio,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = folder.items.isNotEmpty ? folder.items.first : null;
    return UIHelper.card(
      onTap: onTap,
      padding: UIHelper.cardPadding,
      radius: UIHelper.radiusMD,
      child: Row(
        children: [
          // 48×48 preview: first item's thumbnail when available,
          // otherwise the classic folder glyph.
          ClipRRect(
            borderRadius: BorderRadius.circular(UIHelper.radiusSM),
            child: SizedBox(
              width: UIHelper.avatarMD,
              height: UIHelper.avatarMD,
              child: preview != null && preview.thumbnailPath != null
                  ? PosterImage(
                      path: preview.thumbnailPath,
                      width: UIHelper.avatarMD,
                      height: UIHelper.avatarMD,
                      placeholder: isAudio
                          ? Icons.music_note_rounded
                          : Icons.movie_rounded,
                    )
                  : ColoredBox(
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.folder_rounded,
                        size: UIHelper.iconMD,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
          ),
          UIHelper.hMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                UIHelper.vXS,
                Text(
                  folder.countLabel(isAudio: isAudio),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          UIHelper.hSM,
          UIHelper.badge(context: context, label: '${folder.count}'),
          UIHelper.hXS,
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
