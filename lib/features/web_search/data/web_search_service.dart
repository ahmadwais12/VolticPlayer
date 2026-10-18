import 'package:dio/dio.dart';

import '../../../core/config/app_env.dart';
import '../domain/web_search_models.dart';

/// Online search backed by official APIs only:
/// - YouTube Data API v3 for videos, playlists and channels.
/// - Google Programmable Search for web, image and site-restricted
///   (Instagram / Facebook) results.
///
/// Keys are read from `.env` via [AppEnv] (flutter_dotenv), with optional
/// `--dart-define` fallbacks for release/CI builds.
class WebSearchService {
  WebSearchService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  static const _youtubeBase = 'https://www.googleapis.com/youtube/v3';
  static const _cseBase = 'https://www.googleapis.com/customsearch/v1';

  /// Hard ceiling so the UI never sits on a spinner forever.
  static const _callTimeout = Duration(seconds: 10);

  String get _youtubeKey => AppEnv.youtubeApiKey;
  String get _cseKey => AppEnv.googleCseKey;
  String get _cseId => AppEnv.googleCseId;

  bool get hasYouTube => _youtubeKey.isNotEmpty;
  bool get hasGoogle => _cseKey.isNotEmpty && _cseId.isNotEmpty;

  Future<List<WebResult>> search(WebSearchRequest request) async {
    final q = request.query.trim();
    if (q.isEmpty) return const [];
    final f = request.filters;
    try {
      switch (request.tab) {
        case WebSearchTab.all:
          return await _searchAll(q, f);
        case WebSearchTab.playlist:
          return await youtube(q, type: 'playlist', filters: f);
        case WebSearchTab.instagram:
          return await google(q, site: 'instagram.com', filters: f);
        case WebSearchTab.facebook:
          return await google(q, site: 'facebook.com', filters: f);
        case WebSearchTab.pictures:
          return await google(q, images: true, filters: f);
        case WebSearchTab.google:
          return await google(q, filters: f);
      }
    } on WebSearchNotConfigured {
      rethrow;
    } on DioException catch (e) {
      throw StateError(_dioMessage(e));
    }
  }

  /// Aggregates every top filter into one feed.
  /// Songs / movies / music always come from YouTube first; other filters
  /// (Playlist, Instagram, Facebook, Pictures, Google) fill the remaining
  /// All sections without blocking the spinner.
  Future<List<WebResult>> _searchAll(String q, WebSearchFilters f) async {
    if (!hasYouTube && !hasGoogle) {
      throw const WebSearchNotConfigured(
        'Online search needs a YouTube or Google API key.',
      );
    }

    // Songs, movies, music, audio → YouTube is required for All.
    if (!hasYouTube) {
      throw const WebSearchNotConfigured(
        'Searching songs and movies needs YOUTUBE_API_KEY.',
      );
    }

    final ytQuery = _youtubeMediaQuery(q);

    // Primary YouTube video search must surface real API errors (quota / key).
    // Secondary sources stay best-effort so one failure does not blank the page.
    List<WebResult> videos;
    try {
      videos = await youtube(
        ytQuery,
        type: 'video',
        filters: f,
        max: 25,
        enrich: false,
      );
      if (videos.isEmpty && ytQuery != q) {
        videos = await youtube(
          q,
          type: 'video',
          filters: f,
          max: 25,
          enrich: false,
        );
      }
    } on DioException catch (e) {
      throw StateError(_dioMessage(e));
    }

    final playlistFuture = _safe(
      youtube(q, type: 'playlist', filters: f, max: 10, enrich: false),
    );
    final channelFuture = _safe(
      youtube(q, type: 'channel', filters: f, max: 5, enrich: false),
    );
    final googleFuture = hasGoogle
        ? _safe(google(q, filters: f, max: 6, enrich: false))
        : Future.value(const <WebResult>[]);
    final picturesFuture = hasGoogle
        ? _safe(google(q, images: true, filters: f, max: 8, enrich: false))
        : Future.value(const <WebResult>[]);
    final instagramFuture = hasGoogle
        ? _safe(
            google(q, site: 'instagram.com', filters: f, max: 5, enrich: false),
          )
        : Future.value(const <WebResult>[]);
    final facebookFuture = hasGoogle
        ? _safe(
            google(q, site: 'facebook.com', filters: f, max: 5, enrich: false),
          )
        : Future.value(const <WebResult>[]);

    final parts = await Future.wait([
      playlistFuture,
      channelFuture,
      googleFuture,
      picturesFuture,
      instagramFuture,
      facebookFuture,
    ]);

    final merged = <WebResult>[
      ...videos,
      ...parts[0],
      ...parts[1],
      ...parts[2],
      ...parts[3],
      ...parts[4],
      ...parts[5],
    ];
    var deduped = _dedupeByUrl(merged);

    if (deduped.any((r) => r.kind == WebResultKind.playlist)) {
      try {
        deduped = await _enrichPlaylistCounts(deduped).timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {}
    }

    if (deduped.isEmpty) {
      throw StateError(
        'No results for "$q". Try another search, or check the YouTube API key/quota.',
      );
    }
    return deduped;
  }

  /// Boost song/movie queries so YouTube returns media-focused hits.
  String _youtubeMediaQuery(String q) {
    final lower = q.toLowerCase().trim();
    if (RegExp(
      r'\b(songs?|musics?|audio|mp3|lyrics|album|ost|soundtrack)\b',
    ).hasMatch(lower)) {
      if (lower.contains('official') || lower.contains('video')) return q;
      return '$q official audio';
    }
    if (RegExp(r'\b(movies?|films?|cinema|full movie)\b').hasMatch(lower)) {
      if (lower.contains('full')) return q;
      return '$q full movie';
    }
    return q;
  }

  /// Prefer YouTube-typed hits when Google CSE returns the same watch/playlist
  /// URL as a generic web result.
  List<WebResult> _dedupeByUrl(List<WebResult> items) {
    final seen = <String>{};
    final out = <WebResult>[];
    // Videos first (songs/music), then playlists, then everything else.
    final ordered = [
      ...items.where((r) => r.kind == WebResultKind.video),
      ...items.where((r) => r.kind == WebResultKind.playlist),
      ...items.where(
        (r) =>
            r.kind != WebResultKind.video && r.kind != WebResultKind.playlist,
      ),
    ];
    for (final r in ordered) {
      final key = r.url.split('&').first.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(r);
    }
    return out;
  }

  Future<List<WebResult>> _safe(Future<List<WebResult>> f) => f
      .timeout(_callTimeout, onTimeout: () => const <WebResult>[])
      .catchError((_) => const <WebResult>[]);

  String _dioMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Search timed out. Check your internet connection and try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Connect and try again.';
    }
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final msg = '${err['message'] ?? ''}'.trim();
      final lower = msg.toLowerCase();
      if (lower.contains('quota')) {
        return 'YouTube API quota exceeded for today. Try again tomorrow or use another API key.';
      }
      if (lower.contains('api key') || lower.contains('keyinvalid')) {
        return 'YouTube API key is invalid. Update YOUTUBE_API_KEY in .env and restart the app.';
      }
      if (lower.contains('referer') || lower.contains('blocked')) {
        return 'YouTube API key is blocked for this app. Allow requests without HTTP referrer restriction.';
      }
      if (msg.isNotEmpty) return msg;
    }
    final code = e.response?.statusCode;
    if (code == 403 || code == 400) {
      return 'Search API rejected the request (HTTP $code). Check your API key and quota.';
    }
    return 'Search failed. Please try again.';
  }

  // ── YouTube Data API ─────────────────────────────────────────────────────

  Future<List<WebResult>> youtube(
    String q, {
    required String type,
    WebSearchFilters filters = const WebSearchFilters(),
    int max = 20,
    String? channelId,
    bool enrich = true,
  }) async {
    if (!hasYouTube) {
      throw const WebSearchNotConfigured(
        'YouTube search needs YOUTUBE_API_KEY.',
      );
    }
    final window = filters.uploadDate.window;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_youtubeBase/search',
        queryParameters: {
          'part': 'snippet',
          'q': q,
          'type': type,
          'maxResults': max,
          'order': filters.order.name,
          'safeSearch': 'moderate',
          'key': _youtubeKey,
          'channelId': ?channelId,
          if (window != null)
            'publishedAfter': DateTime.now()
                .toUtc()
                .subtract(window)
                .toIso8601String(),
          if (type == 'video' && filters.duration.apiValue != null)
            'videoDuration': filters.duration.apiValue,
        },
      );
      if (res.data?['error'] is Map) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      final items = (res.data?['items'] as List?) ?? const [];
      final results = [
        for (final raw in items) ?_youtubeItem(raw as Map<String, dynamic>),
      ];
      if (type == 'playlist' && results.isNotEmpty && enrich) {
        return _enrichPlaylistCounts(results);
      }
      return results;
    } on DioException {
      rethrow;
    }
  }

  WebResult? _youtubeItem(Map<String, dynamic> item) {
    final id = item['id'] as Map<String, dynamic>? ?? const {};
    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final thumb = _bestThumb(snippet['thumbnails']);
    final title = _decode(snippet['title'] as String? ?? '');
    final channel = _decode(snippet['channelTitle'] as String? ?? '');
    final published = DateTime.tryParse(
      snippet['publishedAt'] as String? ?? '',
    );

    if (id['videoId'] case final String v) {
      return WebResult(
        id: v,
        kind: WebResultKind.video,
        title: title,
        subtitle: channel,
        thumbnailUrl: thumb,
        url: 'https://www.youtube.com/watch?v=$v',
        source: 'YouTube',
        publishedAt: published,
      );
    }
    if (id['playlistId'] case final String pl) {
      return WebResult(
        id: pl,
        kind: WebResultKind.playlist,
        title: title,
        subtitle: channel,
        thumbnailUrl: thumb,
        url: 'https://www.youtube.com/playlist?list=$pl',
        source: 'YouTube',
        publishedAt: published,
      );
    }
    if (id['channelId'] case final String ch) {
      return WebResult(
        id: ch,
        kind: WebResultKind.channel,
        title: title,
        subtitle: _decode(snippet['description'] as String? ?? ''),
        thumbnailUrl: thumb,
        url: 'https://www.youtube.com/channel/$ch',
        source: 'YouTube',
      );
    }
    return null;
  }

  /// Fills [WebResult.itemCount] via `playlists.list` `contentDetails`.
  Future<List<WebResult>> _enrichPlaylistCounts(List<WebResult> playlists) async {
    final ids = playlists
        .where((r) => r.kind == WebResultKind.playlist)
        .map((r) => r.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty || !hasYouTube) return playlists;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_youtubeBase/playlists',
        queryParameters: {
          'part': 'contentDetails',
          'id': ids.take(50).join(','),
          'key': _youtubeKey,
        },
      );
      final counts = <String, int>{};
      for (final raw in (res.data?['items'] as List?) ?? const []) {
        final item = raw as Map<String, dynamic>;
        final id = item['id'] as String?;
        final details = item['contentDetails'] as Map<String, dynamic>?;
        final count = int.tryParse('${details?['itemCount'] ?? ''}');
        if (id != null && count != null) counts[id] = count;
      }
      return [
        for (final r in playlists)
          counts.containsKey(r.id)
              ? r.copyWith(itemCount: counts[r.id])
              : r,
      ];
    } catch (_) {
      return playlists;
    }
  }

  Future<YouTubeChannelDetails> channel(String channelId) async {
    if (!hasYouTube) {
      throw const WebSearchNotConfigured(
        'Channel details need YOUTUBE_API_KEY.',
      );
    }
    final res = await _dio.get<Map<String, dynamic>>(
      '$_youtubeBase/channels',
      queryParameters: {
        'part': 'snippet,statistics,brandingSettings',
        'id': channelId,
        'key': _youtubeKey,
      },
    );
    final items = (res.data?['items'] as List?) ?? const [];
    if (items.isEmpty) throw StateError('Channel not found');
    final item = items.first as Map<String, dynamic>;
    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final stats = item['statistics'] as Map<String, dynamic>? ?? const {};
    final branding = item['brandingSettings'] as Map<String, dynamic>?;
    final image = branding?['image'] as Map<String, dynamic>?;

    final videos = await youtube(
      '',
      type: 'video',
      channelId: channelId,
      filters: const WebSearchFilters(order: WebSortOrder.date),
    );

    return YouTubeChannelDetails(
      id: channelId,
      title: _decode(snippet['title'] as String? ?? ''),
      description: snippet['description'] as String?,
      avatarUrl: _bestThumb(snippet['thumbnails']),
      bannerUrl: image?['bannerExternalUrl'] as String?,
      subscriberCount: int.tryParse('${stats['subscriberCount'] ?? ''}'),
      videoCount: int.tryParse('${stats['videoCount'] ?? ''}'),
      viewCount: int.tryParse('${stats['viewCount'] ?? ''}'),
      latestVideos: videos,
    );
  }

  // ── Google Programmable Search ───────────────────────────────────────────

  Future<List<WebResult>> google(
    String q, {
    String? site,
    bool images = false,
    WebSearchFilters filters = const WebSearchFilters(),
    int max = 10,
    bool enrich = true,
  }) async {
    if (!hasGoogle) {
      throw const WebSearchNotConfigured(
        'Google search needs GOOGLE_CSE_KEY and GOOGLE_CSE_ID.',
      );
    }
    final res = await _dio.get<Map<String, dynamic>>(
      _cseBase,
      queryParameters: {
        'key': _cseKey,
        'cx': _cseId,
        'q': q,
        'num': max.clamp(1, 10),
        'safe': 'active',
        'siteSearch': ?site,
        if (site != null) 'siteSearchFilter': 'i',
        if (images) 'searchType': 'image',
        if (filters.order == WebSortOrder.date) 'sort': 'date',
        'dateRestrict': ?_dateRestrict(filters.uploadDate),
      },
    );
    final items = (res.data?['items'] as List?) ?? const [];
    final source = switch (site) {
      'instagram.com' => 'Instagram',
      'facebook.com' => 'Facebook',
      _ => images ? 'Pictures' : 'Google',
    };
    final results = [
      for (final raw in items.cast<Map<String, dynamic>>())
        _googleItem(raw, images: images, source: source),
    ];
    if (!enrich || !hasYouTube) return results;
    final playlists = results
        .where((r) => r.kind == WebResultKind.playlist)
        .toList();
    if (playlists.isEmpty) return results;
    final enriched = await _enrichPlaylistCounts(playlists);
    final byId = {for (final r in enriched) r.id: r};
    return [for (final r in results) byId[r.id] ?? r];
  }

  WebResult _googleItem(
    Map<String, dynamic> item, {
    required bool images,
    required String source,
  }) {
    final link = item['link'] as String? ?? '';
    final image = item['image'] as Map<String, dynamic>?;
    final pagemap = item['pagemap'] as Map<String, dynamic>?;
    final cseThumbs = pagemap?['cse_thumbnail'] as List?;
    String? thumb;
    if (images) {
      thumb = (image?['thumbnailLink'] as String?) ?? link;
    } else if (cseThumbs != null && cseThumbs.isNotEmpty) {
      thumb = (cseThumbs.first as Map<String, dynamic>)['src'] as String?;
    }

    // Google CSE often returns YouTube watch/playlist pages. Promote those to
    // proper YouTube media rows so the Downloads search list shows them.
    if (!images) {
      final yt = _youtubeResultFromUrl(
        link,
        title: item['title'] as String? ?? link,
        subtitle: item['snippet'] as String?,
        thumbnailUrl: thumb,
      );
      if (yt != null) return yt;
    }

    return WebResult(
      id: link,
      kind: images ? WebResultKind.image : WebResultKind.web,
      title: item['title'] as String? ?? link,
      subtitle: images
          ? item['displayLink'] as String?
          : item['snippet'] as String?,
      thumbnailUrl: thumb,
      url: link,
      source: source,
    );
  }

  /// Maps a YouTube watch / playlist / channel URL into a [WebResult].
  WebResult? _youtubeResultFromUrl(
    String link, {
    required String title,
    String? subtitle,
    String? thumbnailUrl,
  }) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final isYt =
        host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
    if (!isYt) return null;

    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      final v = uri.pathSegments.first;
      return WebResult(
        id: v,
        kind: WebResultKind.video,
        title: title,
        subtitle: subtitle ?? 'YouTube',
        thumbnailUrl: thumbnailUrl,
        url: 'https://www.youtube.com/watch?v=$v',
        source: 'YouTube',
      );
    }

    final path = uri.path.toLowerCase();
    final listId = uri.queryParameters['list'];
    if (path.contains('/playlist') && listId != null && listId.isNotEmpty) {
      return WebResult(
        id: listId,
        kind: WebResultKind.playlist,
        title: title,
        subtitle: subtitle ?? 'YouTube',
        thumbnailUrl: thumbnailUrl,
        url: 'https://www.youtube.com/playlist?list=$listId',
        source: 'YouTube',
      );
    }

    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) {
      return WebResult(
        id: videoId,
        kind: WebResultKind.video,
        title: title,
        subtitle: subtitle ?? 'YouTube',
        thumbnailUrl: thumbnailUrl,
        url: 'https://www.youtube.com/watch?v=$videoId',
        source: 'YouTube',
      );
    }

    if (path.startsWith('/channel/') && uri.pathSegments.length >= 2) {
      final ch = uri.pathSegments[1];
      return WebResult(
        id: ch,
        kind: WebResultKind.channel,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
        url: 'https://www.youtube.com/channel/$ch',
        source: 'YouTube',
      );
    }

    if (path.startsWith('/@') ||
        path.startsWith('/c/') ||
        path.startsWith('/user/')) {
      return WebResult(
        id: link,
        kind: WebResultKind.channel,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
        url: link,
        source: 'YouTube',
      );
    }

    return null;
  }

  String? _dateRestrict(WebUploadDate d) => switch (d) {
    WebUploadDate.any => null,
    WebUploadDate.today => 'd1',
    WebUploadDate.week => 'w1',
    WebUploadDate.month => 'm1',
    WebUploadDate.year => 'y1',
  };

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _bestThumb(Object? thumbnails) {
    if (thumbnails is! Map) return null;
    for (final key in const ['high', 'medium', 'default']) {
      final t = thumbnails[key];
      if (t is Map && t['url'] is String) return t['url'] as String;
    }
    return null;
  }

  String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  void dispose() => _dio.close();
}
