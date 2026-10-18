import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/video_downloader_service.dart';
import 'package:voltic_player/features/downloads/domain/media_provider.dart';

class _FakeProvider implements MediaProvider {
  _FakeProvider(this.id, this.handles, {MediaMetadata? metadata})
      : metadata = metadata ?? _sample;

  @override
  final String id;
  final bool handles;
  final MediaMetadata metadata;

  static const _sample = MediaMetadata(title: 'Sample', sourceUrl: null);

  @override
  bool canHandle(String url) => handles;

  @override
  Future<MediaMetadata> analyze(String url) async => metadata;

  @override
  List<MediaFormat> getFormats(MediaMetadata media) => media.formats;

  @override
  Future<String> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async => savePath;
}

void main() {
  group('MediaProviderRegistry (§19 provider architecture)', () {
    test('dispatches to the first provider that can handle the URL', () async {
      final a = _FakeProvider('a', false);
      final b = _FakeProvider(
        'b',
        true,
        metadata: const MediaMetadata(title: 'From B'),
      );
      final c = _FakeProvider('c', true);
      final registry = MediaProviderRegistry([a, b, c]);

      expect(registry.providerFor('https://example.com/v')?.id, 'b');
      final media = await registry.analyze('https://example.com/v');
      expect(media.title, 'From B');
    });

    test('throws for unsupported URLs instead of guessing', () async {
      final registry = MediaProviderRegistry([_FakeProvider('a', false)]);
      expect(registry.providerFor('https://example.com/v'), isNull);
      expect(
        () => registry.analyze('https://example.com/v'),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty registry handles nothing', () {
      const registry = MediaProviderRegistry([]);
      expect(registry.providerFor('https://example.com/v'), isNull);
    });

    test('generic public provider accepts public HTTPS media URLs', () {
      final service = VideoDownloaderService();
      addTearDown(service.dispose);
      final generic = PublicMediaProvider(service);

      expect(generic.canHandle('https://media.example.com/clip.mp4'), isTrue);
      expect(generic.canHandle('https://127.0.0.1/clip.mp4'), isFalse);
      expect(generic.canHandle('http://media.example.com/clip.mp4'), isFalse);
      expect(generic.id, 'public_media');
    });
  });
}
