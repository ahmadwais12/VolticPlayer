import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/web_search_models.dart';

/// Persists online-search results so the Downloads tab can show the last
/// fetched feed offline until the user refreshes or connectivity returns.
class WebSearchCache {
  WebSearchCache._();

  static const _prefix = 'web_search_cache_v1:';

  static String keyFor(WebSearchRequest request) {
    final f = request.filters;
    return '$_prefix${request.tab.name}|${request.query.trim().toLowerCase()}|'
        '${f.duration.name}|${f.uploadDate.name}|${f.order.name}';
  }

  static Future<void> save(WebSearchRequest request, List<WebResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'items': results.map((r) => r.toJson()).toList(),
    });
    await prefs.setString(keyFor(request), payload);
  }

  static Future<List<WebResult>?> load(WebSearchRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(request));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items = (map['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => WebResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return items.isEmpty ? null : items;
    } catch (_) {
      return null;
    }
  }
}
