import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/bookmarks_controller.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksState = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: bookmarksState.when(
        loading: () => UIHelper.loadingState(),
        error: (e, _) => UIHelper.errorState(
          context: context,
          message: e.toString(),
        ),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return UIHelper.emptyState(
              context: context,
              icon: Icons.bookmark_border,
              message:
                  'No bookmarks yet.\nSave your favorite moments while watching.',
              actionLabel: 'Browse Media',
              onAction: () => context.go(AppRouter.home),
            );
          }
          return ListView.builder(
            padding: UIHelper.screenPadding,
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bm = bookmarks[index];
              return _BookmarkTile(
                title: bm['title'] as String? ?? 'Bookmark',
                positionMs: bm['positionMs'] as int? ?? 0,
                onTap: () {
                  context.push(AppRouter.videoPlayer, extra: {
                    'uri': '',
                    'title': bm['title'] as String? ?? 'Video',
                    'positionMs': bm['positionMs'] as int? ?? 0,
                  });
                },
                onDelete: () {
                  ref
                      .read(bookmarksProvider.notifier)
                      .remove(bm['id'] as int);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final String title;
  final int positionMs;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkTile({
    required this.title,
    required this.positionMs,
    required this.onTap,
    required this.onDelete,
  });

  String get _positionFormatted {
    final h = positionMs ~/ 3600000;
    final m = (positionMs % 3600000) ~/ 60000;
    final s = (positionMs % 60000) ~/ 1000;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: UIHelper.spaceSM),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(UIHelper.radiusSM),
          ),
          child: Center(
            child: Text(
              _positionFormatted,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'at $_positionFormatted',
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
