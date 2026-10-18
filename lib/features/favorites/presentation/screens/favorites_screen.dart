import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_list_tile.dart';
import '../controllers/favorites_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesControllerProvider);
    final controller = ref.read(favoritesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: state.when(
        loading: () => UIHelper.loadingState(),
        error: (e, _) => UIHelper.errorState(
          context: context,
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: controller.reload,
        ),
        data: (items) {
          if (items.isEmpty) {
            return UIHelper.emptyState(
              context: context,
              icon: Icons.favorite_outline,
              message: 'No favorites yet. Tap the heart on any media.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView.separated(
              padding: UIHelper.listPadding,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => MediaListTile(
                item: items[i],
                onTap: () => openMedia(context, items[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: () => controller.remove(items[i].id!),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
