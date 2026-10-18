import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

class HistoryView {
  final MediaItem item;
  final HistoryEntry entry;
  HistoryView(this.item, this.entry);
}

/// MVVM ViewModel for the playback History list.
class HistoryController extends AsyncNotifier<List<HistoryView>> {
  late final LibraryRepository _library;
  late final MediaRepository _media;

  @override
  Future<List<HistoryView>> build() async {
    _library = ref.watch(libraryRepositoryProvider);
    _media = ref.watch(mediaRepositoryProvider);
    return _load();
  }

  Future<List<HistoryView>> _load() async {
    final history = await _library.getHistory();
    if (history.isEmpty) return const [];
    final media = await _media.getByIds(history.map((h) => h.mediaId).toList());
    final byId = {for (final m in media) m.id!: m};
    return [
      for (final h in history)
        if (byId.containsKey(h.mediaId)) HistoryView(byId[h.mediaId]!, h),
    ];
  }

  Future<void> reload() async =>
      state = await AsyncValue.guard(_load);

  Future<void> clear() async {
    await _library.clearHistory();
    await reload();
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<HistoryView>>(
        HistoryController.new);
