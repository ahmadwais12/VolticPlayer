import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/poster_image.dart';
import '../controllers/history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Clear History',
                message: 'This will remove all playback history. Continue?',
                confirmLabel: 'Clear',
                isDestructive: true,
              );
              if (confirmed) controller.clear();
            },
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
        data: (items) {
          if (items.isEmpty) {
            return UIHelper.emptyState(
              context: context,
              icon: Icons.history,
              message: 'No playback history yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView.separated(
              padding: UIHelper.listPadding,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final h = items[i];
                final item = h.item;
                return ListTile(
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PosterImage(
                            path: item.thumbnailPath, width: 56, height: 56),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child:
                              LinearProgressIndicator(value: h.entry.progress),
                        ),
                      ],
                    ),
                  ),
                  title: UIHelper.ellipsisText(item.displayName),
                  subtitle: Text(
                    '${Duration(milliseconds: h.entry.lastPositionMs).formatted} / '
                    '${Duration(milliseconds: h.entry.durationMs).formatted}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => context.push(
                    item.isAudio
                        ? AppRouter.audioPlayer
                        : AppRouter.videoPlayer,
                    extra: {
                      'uri': item.uri,
                      'title': item.displayName,
                      'artist': item.artist,
                      'positionMs': h.entry.lastPositionMs,
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
