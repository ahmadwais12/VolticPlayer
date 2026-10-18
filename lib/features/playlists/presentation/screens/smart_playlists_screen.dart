import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_card.dart';

/// Smart playlist definitions matching the requirements doc §179.
enum SmartPlaylistType {
  mostPlayed,
  recentlyAdded,
  unfinished,
  longVideos,
  shortVideos,
  recentlyPlayed,
  favorites,
}

extension SmartPlaylistTypeExtension on SmartPlaylistType {
  String get label {
    switch (this) {
      case SmartPlaylistType.mostPlayed:
        return 'Most Played';
      case SmartPlaylistType.recentlyAdded:
        return 'Recently Added';
      case SmartPlaylistType.unfinished:
        return 'Unfinished';
      case SmartPlaylistType.longVideos:
        return 'Long Videos (>30min)';
      case SmartPlaylistType.shortVideos:
        return 'Short Videos (<5min)';
      case SmartPlaylistType.recentlyPlayed:
        return 'Recently Played';
      case SmartPlaylistType.favorites:
        return 'Favorites';
    }
  }

  IconData get icon {
    switch (this) {
      case SmartPlaylistType.mostPlayed:
        return Icons.trending_up;
      case SmartPlaylistType.recentlyAdded:
        return Icons.new_releases_outlined;
      case SmartPlaylistType.unfinished:
        return Icons.play_circle_outline;
      case SmartPlaylistType.longVideos:
        return Icons.hourglass_top;
      case SmartPlaylistType.shortVideos:
        return Icons.bolt;
      case SmartPlaylistType.recentlyPlayed:
        return Icons.history;
      case SmartPlaylistType.favorites:
        return Icons.favorite;
    }
  }

  Color get color {
    switch (this) {
      case SmartPlaylistType.mostPlayed:
        return Colors.orange;
      case SmartPlaylistType.recentlyAdded:
        return Colors.blue;
      case SmartPlaylistType.unfinished:
        return Colors.purple;
      case SmartPlaylistType.longVideos:
        return Colors.teal;
      case SmartPlaylistType.shortVideos:
        return Colors.amber;
      case SmartPlaylistType.recentlyPlayed:
        return Colors.indigo;
      case SmartPlaylistType.favorites:
        return Colors.red;
    }
  }

  String get description {
    switch (this) {
      case SmartPlaylistType.mostPlayed:
        return 'Your most frequently played media';
      case SmartPlaylistType.recentlyAdded:
        return 'Media files added recently';
      case SmartPlaylistType.unfinished:
        return 'Continue where you left off';
      case SmartPlaylistType.longVideos:
        return 'Videos longer than 30 minutes';
      case SmartPlaylistType.shortVideos:
        return 'Quick clips under 5 minutes';
      case SmartPlaylistType.recentlyPlayed:
        return 'Play history from the last 7 days';
      case SmartPlaylistType.favorites:
        return 'All your favorited media';
    }
  }
}

class SmartPlaylistsScreen extends ConsumerWidget {
  const SmartPlaylistsScreen({super.key});

  void _openSmartPlaylist(BuildContext context, WidgetRef ref, SmartPlaylistType type) async {
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final libRepo = ref.read(libraryRepositoryProvider);

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loading ${type.label}...'), duration: const Duration(seconds: 1)),
    );

    try {
      List<dynamic> items = [];
      switch (type) {
        case SmartPlaylistType.favorites:
          items = await libRepo.getFavorites();
          break;
        case SmartPlaylistType.recentlyAdded:
          items = await mediaRepo.getVideos(limit: 50);
          break;
        case SmartPlaylistType.mostPlayed:
        case SmartPlaylistType.recentlyPlayed:
        case SmartPlaylistType.unfinished:
          final history = await libRepo.getHistory();
          final ids = history.map((h) => h.mediaId).toList();
          items = ids.isNotEmpty ? await mediaRepo.getByIds(ids) : <dynamic>[];
          break;
        case SmartPlaylistType.longVideos:
          final allVideos = await mediaRepo.getVideos(limit: 200);
          items = allVideos.where((m) => m.durationMs > 30 * 60 * 1000).toList();
          break;
        case SmartPlaylistType.shortVideos:
          final allVideos = await mediaRepo.getVideos(limit: 200);
          items = allVideos.where((m) => m.durationMs > 0 && m.durationMs < 5 * 60 * 1000).toList();
          break;
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(type.icon, color: type.color),
                    const SizedBox(width: 12),
                    Text(type.label, style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text('${items.length} items', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No items found'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return MediaCard(
                            item: item,
                            onTap: () => openMedia(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Playlists')),
      body: ListView.builder(
        padding: UIHelper.screenPadding,
        itemCount: SmartPlaylistType.values.length,
        itemBuilder: (context, index) {
          final type = SmartPlaylistType.values[index];
          return Card(
            margin: const EdgeInsets.only(bottom: UIHelper.spaceSM),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                ),
                child: Icon(type.icon, color: type.color),
              ),
              title: Text(type.label),
              subtitle: Text(
                type.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSmartPlaylist(context, ref, type),
            ),
          );
        },
      ),
    );
  }
}
