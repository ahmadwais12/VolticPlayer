import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/repositories.dart';
import 'library_revision.dart';

/// Visible scan window: never shorter than [minScanUi] or longer UI stall
/// than [maxScanUi] before the bar is effectively complete.
const Duration kMinScanUi = Duration(seconds: 3);
const Duration kMaxScanUi = Duration(minutes: 1);

class LibraryScanProgress {
  final bool isScanning;
  final int scanned;
  final int total;

  /// 0.0–1.0 value shown by the progress bar (smoothed).
  final double displayValue;

  const LibraryScanProgress({
    this.isScanning = false,
    this.scanned = 0,
    this.total = 0,
    this.displayValue = 0,
  });

  double get value => displayValue.clamp(0.0, 1.0);
  int get percent => (value * 100).round().clamp(0, 100);

  LibraryScanProgress copyWith({
    bool? isScanning,
    int? scanned,
    int? total,
    double? displayValue,
  }) => LibraryScanProgress(
    isScanning: isScanning ?? this.isScanning,
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    displayValue: displayValue ?? this.displayValue,
  );
}

class LibraryScanProgressController extends Notifier<LibraryScanProgress> {
  Timer? _ticker;
  Stopwatch? _clock;
  bool _scanFinished = false;
  bool _finishing = false;
  int _scanned = 0;
  int _total = 0;

  @override
  LibraryScanProgress build() {
    ref.onDispose(_stopTicker);
    return const LibraryScanProgress();
  }

  void begin(int total) {
    _stopTicker();
    _scanFinished = false;
    _scanned = 0;
    _total = total < 0 ? 0 : total;
    _clock = Stopwatch()..start();
    state = LibraryScanProgress(
      isScanning: true,
      scanned: 0,
      total: _total,
      displayValue: 0.02,
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
  }

  void update(int scanned, int total) {
    if (!state.isScanning) return;
    _total = total > 0 ? total : _total;
    _scanned = scanned.clamp(0, _total > 0 ? _total : scanned);
    _tick();
  }

  void _tick() {
    if (!state.isScanning || _clock == null) return;

    final elapsedMs = _clock!.elapsedMilliseconds.toDouble();
    final maxMs = kMaxScanUi.inMilliseconds.toDouble();

    // Time curve: reaches ~95% by 60s even if MediaStore is slow to report.
    final timeRatio = (elapsedMs / maxMs).clamp(0.0, 1.0);
    final timeBased = _easeOutCubic(timeRatio) * 0.95;

    // Real item progress when the scanner knows the total.
    final realBased = _total > 0
        ? (_scanned / _total).clamp(0.0, 1.0) * 0.97
        : 0.0;

    var display = math.max(timeBased, realBased);
    display = math.max(display, state.displayValue); // never go backwards
    if (_scanFinished) {
      display = math.max(display, 0.985);
    } else {
      display = display.clamp(0.02, 0.97);
    }

    final next = LibraryScanProgress(
      isScanning: true,
      scanned: _scanned,
      total: _total,
      displayValue: display,
    );
    if (next.percent != state.percent ||
        next.scanned != state.scanned ||
        next.total != state.total ||
        (next.displayValue - state.displayValue).abs() > 0.004) {
      state = next;
    }
  }

  /// Call when the underlying MediaStore / DB scan has finished.
  Future<void> finish() async {
    if (!state.isScanning || _finishing) return;
    _finishing = true;
    _scanFinished = true;
    try {
      final elapsed = _clock?.elapsed ?? Duration.zero;
      final remaining = kMinScanUi - elapsed;

      if (remaining > Duration.zero) {
        final start = state.displayValue;
        final steps = math.max(1, remaining.inMilliseconds ~/ 50);
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!ref.mounted) return;
          final t = i / steps;
          state = LibraryScanProgress(
            isScanning: true,
            scanned: _scanned,
            total: _total,
            displayValue: (start + (1.0 - start) * t).clamp(0.0, 1.0),
          );
        }
      } else {
        state = LibraryScanProgress(
          isScanning: true,
          scanned: _scanned,
          total: _total > 0 ? _total : _scanned,
          displayValue: 1.0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }

      if (!ref.mounted) return;
      _stopTicker();
      state = const LibraryScanProgress();
    } finally {
      _finishing = false;
      _scanFinished = false;
    }
  }

  void complete() {
    unawaited(finish());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  static double _easeOutCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }
}

final libraryScanProgressProvider =
    NotifierProvider<LibraryScanProgressController, LibraryScanProgress>(
      LibraryScanProgressController.new,
    );

Future<int> scanMediaWithProgress(
  Ref ref,
  MediaRepository media, {
  bool force = false,
  int estimatedTotal = 0,
}) async {
  final progress = ref.read(libraryScanProgressProvider.notifier);
  // Avoid restarting the banner if another tab already started this scan.
  if (!ref.read(libraryScanProgressProvider).isScanning) {
    progress.begin(estimatedTotal);
  }
  try {
    return await media.scan(
      force: force,
      onProgress: progress.update,
      // Reveal each freshly-persisted batch (~every 5%) so items appear while
      // the bar climbs, instead of only once the scan reaches 100%. Only the
      // affected tab is refreshed.
      onPersisted: (hasVideo, hasAudio) {
        if (!ref.mounted) return;
        if (hasVideo) ref.read(videoLibraryRevisionProvider.notifier).bump();
        if (hasAudio) ref.read(audioLibraryRevisionProvider.notifier).bump();
      },
    );
  } finally {
    if (ref.mounted) await progress.finish();
  }
}
