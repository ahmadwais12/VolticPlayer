import '../../domain/entities/media_item.dart';

/// A device folder (parent directory) together with the media inside it.
///
/// Used by the Videos / Music sections to group files the way a file
/// manager would: one row per folder with a count (e.g. "150 songs"),
/// tapping it opens the folder's contents.
class MediaFolderGroup implements Comparable<MediaFolderGroup> {
  /// Parent directory of every item in this group ('' when unknown/online).
  final String path;

  /// Display name — the last segment of [path].
  final String name;

  final List<MediaItem> items;

  const MediaFolderGroup({
    required this.path,
    required this.name,
    required this.items,
  });

  int get count => items.length;

  /// Human-readable count, e.g. "150 songs" / "1 video".
  String countLabel({required bool isAudio}) {
    final unit = isAudio
        ? (count == 1 ? 'song' : 'songs')
        : (count == 1 ? 'video' : 'videos');
    return '$count $unit';
  }

  @override
  int compareTo(MediaFolderGroup other) {
    final byCount = other.count.compareTo(count); // biggest first
    if (byCount != 0) return byCount;
    return name.toLowerCase().compareTo(other.name.toLowerCase());
  }
}

/// Parent directory of [item], normalised to forward slashes.
/// Returns '' for network/demo items with no local directory.
String folderPathOf(MediaItem item) {
  final source = item.path.isNotEmpty ? item.path : item.uri;
  if (source.isEmpty || source.startsWith('http')) return '';
  final normalized = source.replaceAll('\\', '/');
  final cut = normalized.lastIndexOf('/');
  if (cut <= 0) return '/'; // file at the filesystem root
  return normalized.substring(0, cut);
}

/// Display name for a folder path produced by [folderPathOf].
String folderNameOf(String path) {
  if (path.isEmpty) return 'Other';
  if (path == '/') return 'Internal storage';
  final cut = path.lastIndexOf('/');
  final name = cut >= 0 ? path.substring(cut + 1) : path;
  return name.isEmpty ? 'Internal storage' : name;
}

/// Groups [items] by their parent folder, biggest folder first
/// (ties broken alphabetically).
List<MediaFolderGroup> groupMediaByFolder(List<MediaItem> items) {
  final byPath = <String, List<MediaItem>>{};
  for (final item in items) {
    byPath.putIfAbsent(folderPathOf(item), () => []).add(item);
  }
  final groups = [
    for (final entry in byPath.entries)
      MediaFolderGroup(
        path: entry.key,
        name: folderNameOf(entry.key),
        items: entry.value,
      ),
  ]..sort();
  return groups;
}
