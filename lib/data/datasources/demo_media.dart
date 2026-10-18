import '../../domain/entities/media_item.dart';

/// Identifies media rows created by the former bundled demo seeder so they
/// can be removed from existing installations during startup.
class DemoMedia {
  const DemoMedia._();

  static bool isLegacyNetworkDemo(String uri) {
    final value = uri.toLowerCase();
    return value.contains('googleapis.com/gtv-videos-bucket') ||
        value.contains('soundhelix.com/examples') ||
        value.contains('commondatastorage.googleapis.com');
  }

  static bool isBundledDemo(MediaItem item) {
    final values =
        '${item.uri} ${item.path} ${item.fileName} ${item.displayName}'
            .toLowerCase();
    return values.contains('demo_media') ||
        values.contains('(demo)') ||
        const {
          'bunny_tiny.mp4',
          'sample_3s.mp4',
          'silent_3s.mp4',
          'sample_audio.ogg',
        }.any(values.contains);
  }
}
