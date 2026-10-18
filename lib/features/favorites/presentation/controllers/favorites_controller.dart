import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

/// MVVM ViewModel for the Favorites list.
class FavoritesController extends AsyncNotifier<List<MediaItem>> {
  late final LibraryRepository _library;

  @override
  Future<List<MediaItem>> build() async {
    _library = ref.watch(libraryRepositoryProvider);
    return _library.getFavorites();
  }

  Future<void> reload() async =>
      state = await AsyncValue.guard(() => _library.getFavorites());

  Future<void> remove(int mediaId) async {
    await _library.toggleFavorite(mediaId, false);
    await reload();
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<MediaItem>>(
        FavoritesController.new);
