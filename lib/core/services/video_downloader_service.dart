import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'youtube_media_resolver.dart';

// ── Media metadata resolved from a URL ──────────────────────────────────────

class MediaMetadata {
  final String title;
  final String? thumbnailUrl;
  final Duration? duration;
  final String? author;
  final String? sourceUrl;
  final List<MediaFormat> formats;

  const MediaMetadata({
    required this.title,
    this.thumbnailUrl,
    this.duration,
    this.author,
    this.sourceUrl,
    this.formats = const [],
  });
}

// ── A downloadable format option ────────────────────────────────────────────

class MediaFormat {
  final String label; // e.g. "1080p", "720p", "Audio (MP3 320kbps)"
  final String? quality; // e.g. "1080p", "best"
  final bool isAudioOnly;
  final int? fileSize; // bytes, null if unknown
  final String? url; // direct download URL (if different from source)

  const MediaFormat({
    required this.label,
    this.quality,
    this.isAudioOnly = false,
    this.fileSize,
    this.url,
  });
}

// ── Supported URL patterns ──────────────────────────────────────────────────

class VideoDownloaderService {
  final Dio _dio;

  VideoDownloaderService({Dio? dio}) : _dio = dio ?? Dio();

  /// Check if a URL looks like a supported media URL.
  bool isSupportedUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
    if (uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return false;
    }
    final address = InternetAddress.tryParse(host);
    if (address != null &&
        (address.isLoopback ||
            address.isLinkLocal ||
            _isPrivateAddress(address))) {
      return false;
    }
    return true;
  }

  bool _isPrivateAddress(InternetAddress address) {
    final b = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          b[0] == 127 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168) ||
          (b[0] == 169 && b[1] == 254) ||
          b[0] == 0 ||
          (b[0] == 100 && b[1] >= 64 && b[1] <= 127) ||
          (b[0] == 192 && b[1] == 0 && b[2] == 0) ||
          (b[0] == 198 && (b[1] == 18 || b[1] == 19)) ||
          b[0] >= 224;
    }
    final isGlobalUnicast = (b[0] & 0xe0) == 0x20;
    final isDocumentation =
        b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8;
    return !isGlobalUnicast || isDocumentation;
  }

  Future<void> _ensurePublicDestination(Uri uri) async {
    if (!isSupportedUrl(uri.toString())) {
      throw const FormatException('Unsupported URL');
    }
    final host = uri.host.toLowerCase();
    if (!host.contains('.') && InternetAddress.tryParse(host) == null) {
      throw const FormatException('Internal hostnames are not supported');
    }
    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      if (_isPrivateAddress(literal)) {
        throw const FormatException('Private network URLs are not supported');
      }
      return;
    }
    final addresses = await InternetAddress.lookup(host);
    if (addresses.isEmpty || addresses.any(_isPrivateAddress)) {
      throw const FormatException('Private network URLs are not supported');
    }
  }

  Future<void> validatePublicDestination(String url) async {
    await _ensurePublicDestination(Uri.parse(url));
  }

  Future<String> resolveSafeRedirects(String url) async {
    final response = await _requestPublicUrl(url, 'HEAD');
    return response.requestOptions.uri.toString();
  }

  Future<Response<dynamic>> _requestPublicUrl(
    String url,
    String method, {
    Duration? receiveTimeout,
    ResponseType? responseType,
    Map<String, Object?>? headers,
    int? maxResponseBytes,
  }) async {
    var current = Uri.parse(url);
    for (var redirects = 0; redirects <= 5; redirects++) {
      await _ensurePublicDestination(current);
      final cancelToken = CancelToken();
      final response = await _dio.requestUri<dynamic>(
        current,
        options: Options(
          method: method,
          followRedirects: false,
          maxRedirects: 0,
          receiveTimeout: receiveTimeout,
          responseType: responseType,
          headers: headers,
          validateStatus: (status) => status != null && status < 400,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: maxResponseBytes == null
            ? null
            : (received, _) {
                if (received > maxResponseBytes) {
                  cancelToken.cancel('metadata response limit exceeded');
                }
              },
      );
      final status = response.statusCode ?? 0;
      if (status < 300 || status >= 400) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || redirects == 5) {
        throw const FormatException('Too many or invalid redirects');
      }
      current = current.resolve(location);
    }
    throw const FormatException('Too many redirects');
  }

  /// Check if a URL is HTTPS (secure).
  bool isSecureUrl(String url) => isSupportedUrl(url);

  /// Resolve metadata from a URL. Tries HEAD request for direct files,
  /// then falls back to content-type sniffing.
  Future<MediaMetadata> resolveFromUrl(String url) async {
    final trimmed = url.trim();

    // YouTube pages need stream extraction — plain HTML has no file URL.
    final yt = YoutubeMediaResolver();
    if (yt.isYouTubeUrl(trimmed)) {
      final meta = await yt.resolve(trimmed);
      if (meta != null && meta.formats.isNotEmpty) return meta;
      return MediaMetadata(
        title: yt.videoIdOf(trimmed) ?? _guessTitleFromUrl(trimmed),
        sourceUrl: trimmed,
        formats: const [],
      );
    }

    // Try HEAD request first to get content info
    try {
      final response = await _requestPublicUrl(trimmed, 'HEAD');

      final contentType = response.headers.value('content-type') ?? '';
      final contentLength = response.headers.value('content-length');
      final fileName = _extractFileName(trimmed, response);
      final extension = p.extension(fileName).toLowerCase();

      // Check if it's a media file
      if (_isMediaContentType(contentType) || _isMediaExtension(extension)) {
        final title = p.basenameWithoutExtension(fileName);
        final isAudio = _isAudioOnly(contentType, extension);

        return MediaMetadata(
          title: title,
          sourceUrl: trimmed,
          formats: [
            MediaFormat(
              label: isAudio
                  ? 'Audio (${extension.toUpperCase()})'
                  : extension.toUpperCase(),
              fileSize: contentLength != null
                  ? int.tryParse(contentLength)
                  : null,
              isAudioOnly: isAudio,
              url: response.requestOptions.uri.toString(),
            ),
          ],
        );
      }

      // Not a direct media file - try to parse as HTML for og:video/og:audio
      return await _resolveFromHtml(trimmed);
    } on DioException {
      // HEAD failed, try GET with range header
      return await _resolveFromHtml(trimmed);
    }
  }

  /// Resolve from HTML page metadata (og:video, og:audio, og:title).
  Future<MediaMetadata> _resolveFromHtml(String url) async {
    try {
      final response = await _requestPublicUrl(
        url,
        'GET',
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.plain,
        headers: const {HttpHeaders.rangeHeader: 'bytes=0-262143'},
        maxResponseBytes: 1024 * 1024,
      );

      final html = response.data?.toString() ?? '';

      // Extract og:title
      String? title =
          _extractMetaContent(html, 'og:title') ??
          _extractMetaContent(html, 'twitter:title');

      // Extract og:video or og:audio
      String? mediaUrl =
          _extractMetaContent(html, 'og:video') ??
          _extractMetaContent(html, 'og:video:url') ??
          _extractMetaContent(html, 'og:audio') ??
          _extractMetaContent(html, 'og:audio:url');

      // Extract og:image as thumbnail
      String? thumbnail = _extractMetaContent(html, 'og:image');

      // Extract og:video:duration
      Duration? duration;
      final durationStr =
          _extractMetaContent(html, 'og:video:duration') ??
          _extractMetaContent(html, 'duration');
      if (durationStr != null) {
        final seconds = int.tryParse(durationStr);
        if (seconds != null) {
          duration = Duration(seconds: seconds);
        }
      }

      // Extract <title> if og:title missing
      title ??= _extractHtmlTitle(html);

      if (mediaUrl != null) {
        final mediaUri = response.requestOptions.uri.resolve(mediaUrl);
        if (!isSupportedUrl(mediaUri.toString())) {
          return MediaMetadata(
            title: title ?? _guessTitleFromUrl(url),
            thumbnailUrl: await _safeImageUrl(
              response.requestOptions.uri,
              thumbnail,
            ),
            duration: duration,
            sourceUrl: url,
          );
        }
        await _ensurePublicDestination(mediaUri);
        mediaUrl = mediaUri.toString();
        final ext = p.extension(mediaUri.path).toLowerCase();
        return MediaMetadata(
          title: title ?? _guessTitleFromUrl(url),
          thumbnailUrl: await _safeImageUrl(
            response.requestOptions.uri,
            thumbnail,
          ),
          duration: duration,
          sourceUrl: url,
          formats: [
            MediaFormat(
              label: ext.isNotEmpty ? ext.toUpperCase() : 'Media',
              url: mediaUrl,
              isAudioOnly: _isAudioOnly('', ext),
            ),
          ],
        );
      }

      // No embedded media found - return metadata for the page itself
      if (title != null || thumbnail != null) {
        return MediaMetadata(
          title: title ?? _guessTitleFromUrl(url),
          thumbnailUrl: await _safeImageUrl(
            response.requestOptions.uri,
            thumbnail,
          ),
          duration: duration,
          sourceUrl: url,
          formats: const [], // No downloadable format found
        );
      }

      // Nothing found - return generic metadata
      return MediaMetadata(
        title: _guessTitleFromUrl(url),
        sourceUrl: url,
        formats: const [],
      );
    } catch (_) {
      return MediaMetadata(
        title: _guessTitleFromUrl(url),
        sourceUrl: url,
        formats: const [],
      );
    }
  }

  Future<String?> _safeImageUrl(Uri base, String? value) async {
    if (value == null || value.isEmpty) return null;
    final uri = base.resolve(value);
    try {
      await _ensurePublicDestination(uri);
      return uri.toString();
    } catch (_) {
      return null;
    }
  }

  /// Download a file with progress tracking.
  Future<String> downloadFile({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options: Options(followRedirects: false, maxRedirects: 0),
    );
    return savePath;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _extractFileName(String url, Response response) {
    // Try Content-Disposition header
    final disposition = response.headers.value('content-disposition');
    if (disposition != null) {
      // Simple parsing: look for filename= or filename*=
      final lower = disposition.toLowerCase();
      final fnIdx = lower.indexOf('filename*=');
      final fn2Idx = lower.indexOf('filename=');
      final idx = fnIdx >= 0 ? fnIdx : fn2Idx;
      if (idx >= 0) {
        final start = disposition.indexOf('=', idx) + 1;
        var value = disposition.substring(start).trim();
        // Remove quotes
        if (value.startsWith('"') && value.length > 1) {
          value = value.substring(1, value.length - 1);
        }
        // Take value until semicolon or whitespace
        final semiIdx = value.indexOf(';');
        if (semiIdx > 0) value = value.substring(0, semiIdx);
        value = value.trim();
        if (value.isNotEmpty) {
          try {
            return Uri.decodeComponent(value);
          } catch (_) {
            return value;
          }
        }
      }
    }
    // Fall back to URL path
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      return Uri.decodeComponent(pathSegments.last);
    }
    return 'download';
  }

  String? _extractMetaContent(String html, String property) {
    // Simple string-based extraction: find <meta property="..." content="...">
    final lowerHtml = html.toLowerCase();
    final lowerProp = property.toLowerCase();

    // Try property="X" content="Y" pattern
    var idx = lowerHtml.indexOf(lowerProp);
    while (idx >= 0) {
      // Check if it's inside a property or name attribute
      final before = lowerHtml.substring(0, idx);
      final lastMeta = before.lastIndexOf('<meta');
      final lastClose = before.lastIndexOf('>');
      if (lastMeta >= 0 && lastClose < lastMeta) {
        // We're inside a <meta ...> tag
        final tagEnd = lowerHtml.indexOf('>', idx);
        if (tagEnd > 0) {
          final tag = html.substring(lastMeta, tagEnd + 1);
          // Find content= in this tag
          final contentIdx = tag.toLowerCase().indexOf('content=');
          if (contentIdx > 0) {
            final afterContent = tag.substring(contentIdx + 8).trim();
            if (afterContent.startsWith('"')) {
              final end = afterContent.indexOf('"', 1);
              if (end > 1) return afterContent.substring(1, end);
            } else if (afterContent.startsWith("'")) {
              final end = afterContent.indexOf("'", 1);
              if (end > 1) return afterContent.substring(1, end);
            }
          }
        }
      }
      idx = lowerHtml.indexOf(lowerProp, idx + 1);
    }
    return null;
  }

  String? _extractHtmlTitle(String html) {
    final start = html.toLowerCase().indexOf('<title');
    if (start < 0) return null;
    final openEnd = html.indexOf('>', start);
    if (openEnd < 0) return null;
    final closeStart = html.toLowerCase().indexOf('</title>', openEnd);
    if (closeStart < 0) return null;
    return html.substring(openEnd + 1, closeStart).trim();
  }

  String _guessTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final last = Uri.decodeComponent(pathSegments.last);
        return p.basenameWithoutExtension(last);
      }
      return uri.host;
    } catch (_) {
      return 'Download';
    }
  }

  bool _isMediaContentType(String contentType) {
    final ct = contentType.toLowerCase();
    return ct.contains('video/') ||
        ct.contains('audio/') ||
        ct.contains('application/mp4') ||
        ct.contains('application/ogg');
  }

  bool _isMediaExtension(String ext) {
    const mediaExts = {
      // Video
      '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts',
      '.m4v', '.3gp', '.wmv', '.mpg', '.mpeg', '.vob',
      // Audio
      '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a',
      '.opus', '.aiff', '.alac',
    };
    return mediaExts.contains(ext.toLowerCase());
  }

  bool _isAudioOnly(String contentType, String ext) {
    final ct = contentType.toLowerCase();
    const audioExts = {
      '.mp3',
      '.wav',
      '.flac',
      '.aac',
      '.ogg',
      '.wma',
      '.m4a',
      '.opus',
    };
    return ct.contains('audio/') || audioExts.contains(ext.toLowerCase());
  }

  /// Dispose the Dio instance.
  void dispose() {
    _dio.close();
  }
}
