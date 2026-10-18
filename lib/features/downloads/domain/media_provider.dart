import 'package:dio/dio.dart';

import '../../../core/services/video_downloader_service.dart';

/// Contract for adding an authorized, public media source to the downloader.
abstract interface class MediaProvider {
  String get id;

  bool canHandle(String url);

  Future<MediaMetadata> analyze(String url);

  List<MediaFormat> getFormats(MediaMetadata media);

  Future<String> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });
}

/// Generic provider for public HTTPS files and openly embedded media URLs.
/// Platform specific extractors can be registered separately when authorized.
class PublicMediaProvider implements MediaProvider {
  PublicMediaProvider(this.service);

  final VideoDownloaderService service;

  @override
  String get id => 'public_media';

  @override
  bool canHandle(String url) => service.isSupportedUrl(url);

  @override
  Future<MediaMetadata> analyze(String url) => service.resolveFromUrl(url);

  @override
  List<MediaFormat> getFormats(MediaMetadata media) => media.formats;

  @override
  Future<String> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) => service.downloadFile(
    url: url,
    savePath: savePath,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
}

class MediaProviderRegistry {
  const MediaProviderRegistry(this.providers);

  final List<MediaProvider> providers;

  MediaProvider? providerFor(String url) {
    for (final provider in providers) {
      if (provider.canHandle(url)) return provider;
    }
    return null;
  }

  Future<MediaMetadata> analyze(String url) {
    final provider = providerFor(url);
    if (provider == null) {
      throw const FormatException('Unsupported URL');
    }
    return provider.analyze(url);
  }
}
