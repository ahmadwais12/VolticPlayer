import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'video_downloader_service.dart';

/// Resolves YouTube watch / Shorts URLs into direct stream metadata that the
/// downloader and media_kit player can use.
class YoutubeMediaResolver {
  YoutubeMediaResolver();

  bool isYouTubeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host.endsWith('youtube.com') ||
        host.endsWith('youtube-nocookie.com');
  }

  String? videoIdOf(String value) {
    try {
      return VideoId.parseVideoId(value);
    } catch (_) {
      return null;
    }
  }

  /// Best single URL for playback (muxed preferred, else best video-only).
  Future<String?> playableUrl(String pageUrl) async {
    final meta = await resolve(pageUrl);
    if (meta == null || meta.formats.isEmpty) return null;
    final muxed = meta.formats.where((f) => !f.isAudioOnly).toList();
    if (muxed.isNotEmpty) return muxed.first.url;
    return meta.formats.first.url;
  }

  Future<MediaMetadata?> resolve(String pageUrl) async {
    if (!isYouTubeUrl(pageUrl)) return null;
    final id = videoIdOf(pageUrl);
    if (id == null) return null;

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(id);
      final manifest = await yt.videos.streamsClient.getManifest(id);

      final formats = <MediaFormat>[];

      // Prefer muxed (audio+video) for easy download / playback.
      final muxed = manifest.muxed.toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
      for (final s in muxed) {
        formats.add(
          MediaFormat(
            label: '${s.qualityLabel} (${s.container.name})',
            quality: s.qualityLabel,
            isAudioOnly: false,
            fileSize: s.size.totalBytes,
            url: s.url.toString(),
          ),
        );
      }

      // Higher-quality video-only streams as extras.
      final videoOnly = manifest.videoOnly.toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
      final seenHeights = muxed.map((s) => s.videoResolution.height).toSet();
      for (final s in videoOnly) {
        if (seenHeights.contains(s.videoResolution.height)) continue;
        seenHeights.add(s.videoResolution.height);
        formats.add(
          MediaFormat(
            label: '${s.qualityLabel} video-only (${s.container.name})',
            quality: s.qualityLabel,
            isAudioOnly: false,
            fileSize: s.size.totalBytes,
            url: s.url.toString(),
          ),
        );
      }

      final audio = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      for (final s in audio.take(8)) {
        final kbps = (s.bitrate.bitsPerSecond / 1000).round();
        formats.add(
          MediaFormat(
            label: '${kbps}k (${s.container.name})',
            quality: '${kbps}k',
            isAudioOnly: true,
            fileSize: s.size.totalBytes,
            url: s.url.toString(),
          ),
        );
      }

      return MediaMetadata(
        title: video.title,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration,
        author: video.author,
        sourceUrl: pageUrl,
        formats: formats,
      );
    } catch (e, st) {
      debugPrint('[YoutubeMediaResolver] resolve failed: $e\n$st');
      return null;
    } finally {
      yt.close();
    }
  }
}
