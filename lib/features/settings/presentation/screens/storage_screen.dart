import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// Storage & data management screen.
///
/// Shows cache size, thumbnails, downloads, and database size
/// with options to clear each.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  Map<String, int> _sizes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _calculateSizes();
  }

  Future<void> _calculateSizes() async {
    setState(() => _loading = true);
    final sizes = <String, int>{};

    try {
      final cacheDir = await getTemporaryDirectory();
      sizes['Cache'] = await _dirSize(cacheDir);
    } catch (_) {}

    try {
      final appDir = await getApplicationDocumentsDirectory();
      sizes['App Data'] = await _dirSize(appDir);
    } catch (_) {}

    try {
      final appSupport = await getApplicationSupportDirectory();
      sizes['Database'] = await _dirSize(appSupport, extensions: ['.drift', '.sqlite', '.db']);
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        sizes['Downloads'] = await _dirSize(extDir);
      }
    } catch (_) {}

    // Thumbnail cache
    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory('${cacheDir.path}/thumbnails');
      if (await thumbDir.exists()) {
        sizes['Thumbnails'] = await _dirSize(thumbDir);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _sizes = sizes;
        _loading = false;
      });
    }
  }

  Future<int> _dirSize(Directory dir, {List<String>? extensions}) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          if (extensions != null) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (!extensions.contains('.$ext')) continue;
          }
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear Cache',
      message: 'This will remove temporary files. It will not delete your downloads or settings.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    try {
      final cacheDir = await getTemporaryDirectory();
      await cacheDir.delete(recursive: true);
      await _calculateSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage & Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateSizes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: UIHelper.screenPadding,
              children: [
                // ── Storage overview ─────────────────────────────
                Text('Storage Usage', style: theme.textTheme.titleMedium),
                UIHelper.vSM,
                ..._sizes.entries.map((e) => _StorageTile(
                      label: e.key,
                      bytes: e.value,
                      icon: _iconForLabel(e.key),
                    )),
                UIHelper.vMD,
                const Divider(),
                UIHelper.vMD,

                // ── Actions ─────────────────────────────────────
                Text('Manage Storage', style: theme.textTheme.titleMedium),
                UIHelper.vSM,
                ListTile(
                  leading: Icon(Icons.cleaning_services, color: theme.colorScheme.primary),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Remove temporary files'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Remove all app data including settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Clear All Data?',
                      message: 'This will permanently delete all app data, settings, '
                          'playlists, and history. This cannot be undone.',
                      confirmLabel: 'Delete All',
                      isDestructive: true,
                    );
                    if (!confirmed) return;
                    try {
                      final appDir = await getApplicationDocumentsDirectory();
                      await appDir.delete(recursive: true);
                      final cacheDir = await getTemporaryDirectory();
                      await cacheDir.delete(recursive: true);
                      await _calculateSizes();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All data cleared. Restart the app.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                ),
                UIHelper.vMD,
                const Divider(),
                UIHelper.vMD,

                // ── Info ────────────────────────────────────────
                Text('About Storage', style: theme.textTheme.titleMedium),
                UIHelper.vSM,
                _InfoTile(
                  icon: Icons.info_outline,
                  text: 'Cache stores temporary thumbnails and playback data. '
                      'Clearing it is safe and will not affect your media.',
                ),
                _InfoTile(
                  icon: Icons.download_outlined,
                  text: 'Downloads are stored in the app\'s external storage. '
                      'They persist until manually deleted.',
                ),
              ],
            ),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case 'Cache':
        return Icons.cleaning_services;
      case 'Downloads':
        return Icons.cloud_download_outlined;
      case 'Thumbnails':
        return Icons.photo_library_outlined;
      case 'Database':
        return Icons.storage_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}

class _StorageTile extends StatelessWidget {
  final String label;
  final int bytes;
  final IconData icon;

  const _StorageTile({required this.label, required this.bytes, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          UIHelper.hSM,
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            _formatBytes(bytes),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          UIHelper.hSM,
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
