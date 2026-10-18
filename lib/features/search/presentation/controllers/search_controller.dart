import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../domain/entities/media_item.dart';

class SearchState {
  final String query;
  final List<MediaItem> results;
  final bool loading;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
  });

  SearchState copyWith({
    String? query,
    List<MediaItem>? results,
    bool? loading,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    loading: loading ?? this.loading,
  );
}

/// MVVM ViewModel for search with 300ms debounce.
class SearchController extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void search(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }
    // Set query immediately for UI feedback, but debounce the actual search
    state = state.copyWith(query: query, loading: true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final repo = ref.read(mediaRepositoryProvider);
      final results = await repo.search(query);
      // Only update if query hasn't changed while we were searching
      if (state.query == query) {
        state = state.copyWith(results: results, loading: false);
      }
    });
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(() => SearchController());
