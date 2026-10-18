import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

/// ViewModel for bookmarks management.
class BookmarksController extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    // Trigger initial load
    Future.microtask(() => load());
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.watch(appDatabaseProvider);
      final rows = await db.bookmarksDao.all();
      final bookmarks = rows
          .map((r) => <String, dynamic>{
                'id': r.id,
                'mediaId': r.mediaId,
                'positionMs': r.positionMs,
                'title': r.title,
                'note': r.note,
                'createdAt': r.createdAt,
              })
          .toList();
      state = AsyncValue.data(bookmarks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add({
    required int mediaId,
    required int positionMs,
    String? title,
  }) async {
    final db = ref.read(appDatabaseProvider);
    await db.bookmarksDao.insertBookmark(
      mediaId: mediaId,
      positionMs: positionMs,
      title: title,
    );
    await load();
  }

  Future<void> remove(int id) async {
    final db = ref.read(appDatabaseProvider);
    await db.bookmarksDao.deleteBookmark(id);
    await load();
  }

  /// Get bookmarks for a specific media item.
  Future<List<Map<String, dynamic>>> byMediaId(int mediaId) async {
    final db = ref.read(appDatabaseProvider);
    final rows = await db.bookmarksDao.byMediaId(mediaId);
    return rows
        .map((r) => <String, dynamic>{
              'id': r.id,
              'mediaId': r.mediaId,
              'positionMs': r.positionMs,
              'title': r.title,
              'note': r.note,
              'createdAt': r.createdAt,
            })
        .toList();
  }
}

final bookmarksProvider = NotifierProvider<BookmarksController,
    AsyncValue<List<Map<String, dynamic>>>>(
  () => BookmarksController(),
);
