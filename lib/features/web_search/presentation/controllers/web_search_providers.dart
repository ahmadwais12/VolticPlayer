import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/web_search_cache.dart';
import '../../data/web_search_service.dart';
import '../../domain/web_search_models.dart';

final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  final service = WebSearchService();
  ref.onDispose(service.dispose);
  return service;
});

/// Filters chosen from the search page's filter sheet.
class WebSearchFiltersNotifier extends Notifier<WebSearchFilters> {
  @override
  WebSearchFilters build() => const WebSearchFilters();

  void set(WebSearchFilters filters) => state = filters;
}

final webSearchFiltersProvider =
    NotifierProvider<WebSearchFiltersNotifier, WebSearchFilters>(
      WebSearchFiltersNotifier.new,
    );

final webSearchResultsProvider = FutureProvider.autoDispose
    .family<List<WebResult>, WebSearchRequest>((ref, request) async {
      // Keep results alive while the Downloads tab is in use so scrolling
      // does not refetch. Disk cache covers offline / cold start.
      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(const Duration(minutes: 30), link.close);
      });
      ref.onResume(() => disposeTimer?.cancel());
      ref.onDispose(() => disposeTimer?.cancel());

      final cached = await WebSearchCache.load(request);
      final online = await _hasNetwork();

      if (!online && cached != null) return cached;

      try {
        final fresh = await ref.read(webSearchServiceProvider).search(request);
        await WebSearchCache.save(request, fresh);
        return fresh;
      } catch (e) {
        if (cached != null) return cached;
        rethrow;
      }
    });

Future<bool> _hasNetwork() async {
  try {
    final results = await Connectivity().checkConnectivity();
    // Some Android devices briefly report an empty list — do not block search.
    if (results.isEmpty) return true;
    return results.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}

final youtubeChannelProvider = FutureProvider.autoDispose
    .family<YouTubeChannelDetails, String>((ref, channelId) {
      return ref.read(webSearchServiceProvider).channel(channelId);
    });
