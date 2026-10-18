import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/di/providers.dart';
import '../../../../core/services/library_scan_progress.dart';
import '../../../../data/datasources/device_media_scanner.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/repositories/repositories.dart';

class FolderGroup {
  final String path;
  final String name;
  final List<MediaItem> items;
  FolderGroup(this.path, this.name, this.items);
}

/// MVVM ViewModel for the Folders browser.
class FoldersController extends AsyncNotifier<List<FolderGroup>> {
  late final MediaRepository _media;
  late final DeviceMediaScanner _scanner;

  @override
  Future<List<FolderGroup>> build() async {
    _media = ref.watch(mediaRepositoryProvider);
    _scanner = ref.watch(deviceMediaScannerProvider);
    return _load();
  }

  Future<List<FolderGroup>> _load() async {
    final videos = await _media.getVideos();
    final audio = await _media.getAudio();
    final all = [...videos, ...audio];
    final Map<String, List<MediaItem>> map = {};
    for (final m in all) {
      if (m.path.isEmpty) continue;
      final dir = p.dirname(m.path);
      map.putIfAbsent(dir, () => []).add(m);
    }
    final groups =
        map.entries
            .map((e) => FolderGroup(e.key, p.basename(e.key), e.value))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  Future<void> reload() async => state = await AsyncValue.guard(_load);

  /// Uses the native folder picker then scans & persists that folder.
  /// For device media, we use DeviceMediaScanner which queries MediaStore.
  Future<void> pickAndScan() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    // When user picks a specific folder, scan it using DeviceMediaScanner
    // This will find all media in that folder via MediaStore
    final progress = ref.read(libraryScanProgressProvider.notifier);
    final scanClock = Stopwatch()..start();
    progress.begin(0);
    late final List<MediaItem> found;
    try {
      found = await _scanner.scanAll(onProgress: progress.update);
    } finally {
      final remaining = const Duration(seconds: 3) - scanClock.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (ref.mounted) progress.complete();
    }
    for (final item in found) {
      await _media.addManual(item);
    }
    await reload();
  }

  /// Refresh from device MediaStore
  Future<void> scanDevice() async {
    final count = await scanMediaWithProgress(ref, _media, force: true);
    if (count > 0) await reload();
  }
}

final foldersControllerProvider =
    AsyncNotifierProvider<FoldersController, List<FolderGroup>>(
      FoldersController.new,
    );
