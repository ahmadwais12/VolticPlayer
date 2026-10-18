import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../services/library_auto_scan.dart';
import '../services/library_revision.dart';

/// Reactive "can we currently read device media?" flag. Library pages watch it
/// so an empty library caused by a missing permission shows a grant-access
/// prompt instead of a misleading "no videos yet" message.
class MediaAccessController extends Notifier<bool> {
  @override
  bool build() {
    // A finished scan means access was granted (and possibly revoked later),
    // so re-check whenever either library section changes.
    ref.listen(videoLibraryRevisionProvider, (_, _) => _refresh());
    ref.listen(audioLibraryRevisionProvider, (_, _) => _refresh());
    _refresh();
    return false;
  }

  Future<void> _refresh() async {
    final granted = await ref.read(permissionServiceProvider).hasMediaAccess();
    if (ref.mounted) state = granted;
  }

  Future<void> refresh() => _refresh();

  /// Show the one-time system dialog (if needed) and auto-scan once granted.
  /// Returns true when access is available afterwards.
  Future<bool> requestAndScan() async {
    final granted =
        await ref.read(libraryAutoScanProvider).requestAccessAndScan();
    if (ref.mounted) state = granted;
    return granted;
  }
}

final mediaAccessProvider =
    NotifierProvider<MediaAccessController, bool>(MediaAccessController.new);
