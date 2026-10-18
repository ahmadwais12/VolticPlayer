import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/features/web_search/data/web_search_service.dart';
import 'package:voltic_player/features/web_search/domain/web_search_models.dart';

void main() {
  group('WebSearchService without API keys', () {
    final service = WebSearchService();

    for (final tab in WebSearchTab.values) {
      test('${tab.label} tab reports that search is not configured', () {
        expect(
          service.search(
            WebSearchRequest(
              query: 'lofi',
              tab: tab,
              filters: const WebSearchFilters(),
            ),
          ),
          throwsA(isA<WebSearchNotConfigured>()),
        );
      });
    }

    test('channel details report that search is not configured', () {
      expect(service.channel('UC123'), throwsA(isA<WebSearchNotConfigured>()));
    });
  });

  group('WebSearchFilters', () {
    test('defaults are recognised and compare by value', () {
      expect(const WebSearchFilters().isDefault, isTrue);
      expect(
        const WebSearchFilters().copyWith(order: WebSortOrder.date),
        const WebSearchFilters(order: WebSortOrder.date),
      );
      expect(
        const WebSearchFilters(duration: WebDuration.long).isDefault,
        isFalse,
      );
    });

    test('requests with equal values share a cache key', () {
      const a = WebSearchRequest(
        query: 'q',
        tab: WebSearchTab.all,
        filters: WebSearchFilters(),
      );
      const b = WebSearchRequest(
        query: 'q',
        tab: WebSearchTab.all,
        filters: WebSearchFilters(),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  test('only channels and playlists are not directly downloadable', () {
    WebResult r(WebResultKind k) => WebResult(
      id: 'x',
      kind: k,
      title: 't',
      url: 'https://a.b',
      source: 's',
    );
    expect(r(WebResultKind.video).isDownloadable, isTrue);
    expect(r(WebResultKind.image).isDownloadable, isTrue);
    expect(r(WebResultKind.web).isDownloadable, isTrue);
    expect(r(WebResultKind.channel).isDownloadable, isFalse);
    expect(r(WebResultKind.playlist).isDownloadable, isFalse);
  });

  test('isYouTube detects YouTube source and hosts', () {
    expect(
      const WebResult(
        id: '1',
        kind: WebResultKind.video,
        title: 't',
        url: 'https://www.youtube.com/watch?v=1',
        source: 'YouTube',
      ).isYouTube,
      isTrue,
    );
    expect(
      const WebResult(
        id: '1',
        kind: WebResultKind.web,
        title: 't',
        url: 'https://youtu.be/abc',
        source: 'Google',
      ).isYouTube,
      isTrue,
    );
    expect(
      const WebResult(
        id: '1',
        kind: WebResultKind.web,
        title: 't',
        url: 'https://example.com/a',
        source: 'Google',
      ).isYouTube,
      isFalse,
    );
  });
}
