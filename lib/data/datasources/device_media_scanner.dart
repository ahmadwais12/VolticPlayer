import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/media_item.dart';

/// Queries Android MediaStore / iOS Photo Library for all video and audio
/// files on the device. This is the primary data source for media discovery.
class DeviceMediaScanner {
  const DeviceMediaScanner();

  /// Scan all videos on the device.
  Future<List<MediaItem>> scanVideos() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    return _fetchAssets(paths.first, isVideo: true);
  }

  /// Scan all audio files on the device.
  Future<List<MediaItem>> scanAudio() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    return _fetchAssets(paths.first, isVideo: false);
  }

  /// Scan all video + audio on the device.
  ///
  /// [onProgress] reports (scanned, total) after every asset. [onBatch] emits
  /// each resolved page-batch of items as it is read, so callers can persist
  /// and reveal media progressively instead of waiting for the full list.
  Future<List<MediaItem>> scanAll({
    void Function(int scanned, int total)? onProgress,
    void Function(List<MediaItem> batch)? onBatch,
  }) async {
    final videoPaths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    final audioPaths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
      onlyAll: true,
    );
    final videoCount = videoPaths.isEmpty
        ? 0
        : await videoPaths.first.assetCountAsync;
    final audioCount = audioPaths.isEmpty
        ? 0
        : await audioPaths.first.assetCountAsync;
    final total = videoCount + audioCount;
    var scanned = 0;
    void advance() => onProgress?.call(++scanned, total);
    onProgress?.call(0, total);

    final videos = videoPaths.isEmpty
        ? <MediaItem>[]
        : await _fetchAssets(
            videoPaths.first,
            isVideo: true,
            onAssetProcessed: advance,
            onBatch: onBatch,
          );
    final audio = audioPaths.isEmpty
        ? <MediaItem>[]
        : await _fetchAssets(
            audioPaths.first,
            isVideo: false,
            onAssetProcessed: advance,
            onBatch: onBatch,
          );
    return [...videos, ...audio];
  }

  /// Fetch assets from an AssetPathEntity with pagination.
  Future<List<MediaItem>> _fetchAssets(
    AssetPathEntity path, {
    required bool isVideo,
    void Function()? onAssetProcessed,
    void Function(List<MediaItem> batch)? onBatch,
    int pageSize = 500,
  }) async {
    final result = <MediaItem>[];
    final count = await path.assetCountAsync;
    if (count == 0) return result;

    // Fetch in pages
    for (var page = 0; page * pageSize < count; page++) {
      final assets = await path.getAssetListPaged(page: page, size: pageSize);

      // Keep platform-channel work concurrent but bounded. A serial request
      // per file makes large phone libraries take several minutes to scan.
      const batchSize = 20;
      for (var offset = 0; offset < assets.length; offset += batchSize) {
        final batch = assets.skip(offset).take(batchSize).toList();
        final converted = await Future.wait(
          batch.map((asset) async {
            final file = await asset.file;
            if (file == null) return null;

            final path2 = file.path;
            final name = path2.split(RegExp(r'[/\\]')).last;
            final dotIndex = name.lastIndexOf('.');
            final displayName = dotIndex > 0
                ? name.substring(0, dotIndex)
                : name;
            final extension = dotIndex > 0
                ? name.substring(dotIndex + 1).toLowerCase()
                : '';
            final fileSize = await asset.fileSize;

            return MediaItem(
              uri: path2,
              path: path2,
              fileName: name,
              displayName: displayName,
              extension: extension,
              size: fileSize,
              durationMs: asset.duration * 1000,
              isVideo: isVideo,
              isAudio: !isVideo,
              createdAt: asset.createDateTime,
              modifiedAt: asset.modifiedDateTime,
              lastScannedAt: DateTime.now(),
              // Thumbnails are generated lazily by VideosController while
              // visible rows are populated. Scanning thousands of videos
              // must not decode and cache every poster before indexing.
              thumbnailPath: null,
              // Audio metadata (best-effort from photo_manager)
              artist: isVideo ? null : (asset.title ?? displayName),
              album: null,
            );
          }),
        );
        result.addAll(converted.whereType<MediaItem>());
        final batchItems = converted.whereType<MediaItem>().toList();
        if (batchItems.isNotEmpty) onBatch?.call(batchItems);
        for (var i = 0; i < batch.length; i++) {
          onAssetProcessed?.call();
        }
      }
    }
    return result;
  }
}
