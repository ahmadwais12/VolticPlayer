import 'package:equatable/equatable.dart';

/// Tabs shown in the top navigation bar of the online search results page.
enum WebSearchTab {
  all('All'),
  playlist('Playlist'),
  instagram('Instagram'),
  facebook('Facebook'),
  pictures('Pictures'),
  google('Google');

  const WebSearchTab(this.label);
  final String label;
}

enum WebResultKind { video, playlist, channel, image, web }

/// A single online search hit, normalized across search backends.
class WebResult extends Equatable {
  final String id;
  final WebResultKind kind;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final String url;
  final String source;
  final DateTime? publishedAt;

  /// Number of videos in a playlist when the backend provides it.
  final int? itemCount;

  const WebResult({
    required this.id,
    required this.kind,
    required this.title,
    required this.url,
    required this.source,
    this.subtitle,
    this.thumbnailUrl,
    this.publishedAt,
    this.itemCount,
  });

  WebResult copyWith({
    String? id,
    WebResultKind? kind,
    String? title,
    String? subtitle,
    String? thumbnailUrl,
    String? url,
    String? source,
    DateTime? publishedAt,
    int? itemCount,
  }) => WebResult(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    url: url ?? this.url,
    source: source ?? this.source,
    publishedAt: publishedAt ?? this.publishedAt,
    itemCount: itemCount ?? this.itemCount,
  );

  /// Directly downloadable media. Channels and playlists are NOT: a
  /// playlist URL is not a single media file (mirrors the widget test).
  bool get isDownloadable =>
      kind == WebResultKind.video ||
      kind == WebResultKind.image ||
      kind == WebResultKind.web;

  bool get isYouTube =>
      source == 'YouTube' || _isYouTubeHost(Uri.tryParse(url)?.host);

  static bool _isYouTubeHost(String? host) {
    if (host == null) return false;
    final h = host.toLowerCase();
    return h == 'youtu.be' ||
        h == 'youtube.com' ||
        h.endsWith('.youtube.com') ||
        h.endsWith('.youtu.be');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'thumbnailUrl': thumbnailUrl,
        'url': url,
        'source': source,
        'publishedAt': publishedAt?.toIso8601String(),
        'itemCount': itemCount,
      };

  factory WebResult.fromJson(Map<String, dynamic> json) => WebResult(
        id: json['id'] as String? ?? '',
        kind: WebResultKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => WebResultKind.web,
        ),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        url: json['url'] as String? ?? '',
        source: json['source'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        itemCount: json['itemCount'] as int?,
      );

  @override
  List<Object?> get props => [id, kind, url, itemCount];
}

enum WebSortOrder {
  relevance('Relevance'),
  date('Upload date'),
  viewCount('View count');

  const WebSortOrder(this.label);
  final String label;
}

enum WebUploadDate {
  any('Any time', null),
  today('Today', Duration(days: 1)),
  week('This week', Duration(days: 7)),
  month('This month', Duration(days: 30)),
  year('This year', Duration(days: 365));

  const WebUploadDate(this.label, this.window);
  final String label;
  final Duration? window;
}

enum WebDuration {
  any('Any', null),
  short('Under 4 min', 'short'),
  medium('4–20 min', 'medium'),
  long('Over 20 min', 'long');

  const WebDuration(this.label, this.apiValue);
  final String label;
  final String? apiValue;
}

class WebSearchFilters extends Equatable {
  final WebSortOrder order;
  final WebUploadDate uploadDate;
  final WebDuration duration;

  const WebSearchFilters({
    this.order = WebSortOrder.relevance,
    this.uploadDate = WebUploadDate.any,
    this.duration = WebDuration.any,
  });

  bool get isDefault => this == const WebSearchFilters();

  WebSearchFilters copyWith({
    WebSortOrder? order,
    WebUploadDate? uploadDate,
    WebDuration? duration,
  }) => WebSearchFilters(
    order: order ?? this.order,
    uploadDate: uploadDate ?? this.uploadDate,
    duration: duration ?? this.duration,
  );

  @override
  List<Object?> get props => [order, uploadDate, duration];
}

class WebSearchRequest extends Equatable {
  final String query;
  final WebSearchTab tab;
  final WebSearchFilters filters;

  const WebSearchRequest({
    required this.query,
    required this.tab,
    required this.filters,
  });

  @override
  List<Object?> get props => [query, tab, filters];
}

class YouTubeChannelDetails {
  final String id;
  final String title;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final int? subscriberCount;
  final int? videoCount;
  final int? viewCount;
  final List<WebResult> latestVideos;

  const YouTubeChannelDetails({
    required this.id,
    required this.title,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.subscriberCount,
    this.videoCount,
    this.viewCount,
    this.latestVideos = const [],
  });
}

/// Thrown when a search backend needs an API key that wasn't provided.
class WebSearchNotConfigured implements Exception {
  final String message;
  const WebSearchNotConfigured(this.message);

  @override
  String toString() => message;
}
