import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/permissions/media_access_controller.dart';
import '../../../../shared/widgets/app_states.dart';

/// Empty state shown when the library is empty because device media access has
/// not been granted yet. One tap shows the system dialog and auto-scans; if
/// Android has permanently denied it, the user is sent to Settings instead.
class LibraryAccessEmptyState extends ConsumerWidget {
  const LibraryAccessEmptyState({
    super.key,
    required this.isAudio,
    this.isScanning = false,
  });

  final bool isAudio;
  final bool isScanning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      message: isAudio
          ? 'Allow access to find music on your device.'
          : 'Allow access to find videos on your device.',
      actionLabel: 'Allow access',
      icon: isAudio
          ? Icons.library_music_outlined
          : Icons.movie_outlined,
      onAction: isScanning ? null : () => _request(ref),
    );
  }

  Future<void> _request(WidgetRef ref) async {
    final permissions = ref.read(permissionServiceProvider);
    final access = ref.read(mediaAccessProvider.notifier);
    if (await access.requestAndScan()) return;
    // A second denial hides the dialog forever — recover through Settings,
    // then re-check and scan when the user comes back.
    if (await permissions.isMediaPermanentlyDenied()) {
      await permissions.openSettings();
      await access.requestAndScan();
    }
  }
}
