import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../di/providers.dart';
import 'library_bootstrap.dart';
import 'library_revision.dart';
import 'library_scan_progress.dart';

/// Starts seed + silent device scan as soon as the app process is alive —
/// independent of whether Home / Videos / Music tabs were opened.
class LibraryAutoScan with WidgetsBindingObserver {
  LibraryAutoScan(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _rescanPending = false;
  bool _changeNotifyStarted = false;
  Timer? _changeDebounce;
  Future<bool>? _permissionPrompt;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    // Silent at startup: populate the library for users who already granted
    // access, but never pop a dialog before the first frame is ready. The
    // one-time prompt is driven by onboarding / the library pages instead, so
    // it shows over a real screen and cannot race the splash notification ask.
    await _scan(reason: 'startup', requestPermission: false);
    // Watch only after startup reconciliation, so notification startup cannot
    // immediately schedule a duplicate full scan.
    PhotoManager.addChangeCallback(_onDeviceMediaChanged);
    try {
      await PhotoManager.startChangeNotify();
      _changeNotifyStarted = PhotoManager.notifyingOfChange;
    } catch (error) {
      debugPrint(
        '[LibraryAutoScan] Media change notifications unavailable: $error',
      );
    }
  }

  /// Shows the system media-permission dialog (at most one in flight), then
  /// scans automatically once access is available. Returns true when the app
  /// can read device media afterwards. Safe to call from onboarding and from
  /// a library page's "Allow access" button.
  Future<bool> requestAccessAndScan() async {
    final permissions = _ref.read(permissionServiceProvider);
    if (await permissions.hasMediaAccess()) {
      unawaited(_scan(reason: 'access already granted', forceRefresh: true));
      return true;
    }
    final prompt = _permissionPrompt ??= permissions
        .requestMediaPermissions()
        .whenComplete(() => _permissionPrompt = null);
    final granted = await prompt;
    if (granted) {
      unawaited(_scan(reason: 'access granted', forceRefresh: true));
    } else {
      debugPrint('[LibraryAutoScan] media permission not granted');
    }
    return granted;
  }

  void _onDeviceMediaChanged(MethodCall _) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_scan(reason: 'device media changed', forceRefresh: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Media added while the app was backgrounded may not emit a callback on
      // every Android device, so reconcile once when the app returns.
      unawaited(_scan(reason: 'app resumed'));
    }
  }

  Future<void> _scan({
    required String reason,
    bool requestPermission = false,
    bool forceRefresh = false,
  }) async {
    if (_running) {
      _rescanPending = true;
      return;
    }
    _running = true;
    try {
      await LibraryBootstrap.ensure(_ref);
      final media = _ref.read(mediaRepositoryProvider);
      final permissions = _ref.read(permissionServiceProvider);
      var hasAccess = await permissions.hasMediaAccess();
      if (!hasAccess && requestPermission) {
        hasAccess = await permissions.requestMediaPermissions();
      }
      if (!hasAccess) {
        debugPrint(
          '[LibraryAutoScan] $reason skipped (media permission not granted)',
        );
        return;
      }

      final beforeVideos = await media.countVideos();
      final beforeAudio = await media.countAudio();
      final deviceCounts = await _deviceMediaCounts();
      if (!forceRefresh &&
          beforeVideos == deviceCounts.videos &&
          beforeAudio == deviceCounts.audio) {
        debugPrint(
          '[LibraryAutoScan] $reason skipped (library already current)',
        );
        return;
      }

      await scanMediaWithProgress(
        _ref,
        media,
        estimatedTotal: deviceCounts.videos + deviceCounts.audio,
      );
      final afterVideos = await media.countVideos();
      final afterAudio = await media.countAudio();
      final videosChanged = beforeVideos != afterVideos;
      final audioChanged = beforeAudio != afterAudio;
      if (videosChanged || audioChanged) {
        debugPrint(
          '[LibraryAutoScan] $reason updated library '
          '(videos $beforeVideos→$afterVideos, '
          'audio $beforeAudio→$afterAudio)',
        );
        if (videosChanged) {
          _ref.read(videoLibraryRevisionProvider.notifier).bump();
        }
        if (audioChanged) {
          _ref.read(audioLibraryRevisionProvider.notifier).bump();
        }
      } else {
        debugPrint('[LibraryAutoScan] $reason — no library changes');
      }
    } catch (e) {
      debugPrint('[LibraryAutoScan] $reason failed: $e');
    } finally {
      _running = false;
      if (_rescanPending) {
        _rescanPending = false;
        unawaited(_scan(reason: 'queued device media change'));
      }
    }
  }

  Future<({int videos, int audio})> _deviceMediaCounts() async {
    final videoPaths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    final audioPaths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
      onlyAll: true,
    );
    return (
      videos: videoPaths.isEmpty ? 0 : await videoPaths.first.assetCountAsync,
      audio: audioPaths.isEmpty ? 0 : await audioPaths.first.assetCountAsync,
    );
  }

  void dispose() {
    _changeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PhotoManager.removeChangeCallback(_onDeviceMediaChanged);
    if (_changeNotifyStarted) unawaited(PhotoManager.stopChangeNotify());
  }
}

final libraryAutoScanProvider = Provider<LibraryAutoScan>((ref) {
  final scan = LibraryAutoScan(ref);
  // Run one scan for this app process. Pages only read local database data.
  unawaited(scan.start());
  ref.onDispose(scan.dispose);
  return scan;
});
