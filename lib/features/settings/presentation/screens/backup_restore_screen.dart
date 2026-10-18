import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/backup_service.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  late final BackupService _backupService;
  List<BackupInfo> _backups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(ref.read(appDatabaseProvider));
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      _backups = await _backupService.listBackups();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _exportBackup() async {
    try {
      final path = await _backupService.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to: $path')),
        );
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(String path) async {
    try {
      await _backupService.importBackup(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          // ── Export ──────────────────────────────────────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Export Backup'),
              subtitle: const Text('Save playlists, favorites, history, bookmarks & settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportBackup,
            ),
          ),
          UIHelper.vSM,

          // ── Existing Backups ────────────────────────────────
          Text('Available Backups', style: theme.textTheme.titleMedium),
          UIHelper.vSM,

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(UIHelper.spaceLG),
              child: Text(
                'No backups found.\nCreate your first backup above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            )
          else
            ...List.generate(_backups.length, (index) {
              final backup = _backups[index];
              final date = DateFormat.yMMMd().add_jm().format(backup.createdAt);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    backup.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('$date • ${backup.sizeFormatted}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') {
                        _importBackup(backup.path);
                      } else if (value == 'delete') {
                        _backupService.deleteBackup(backup.path).then((_) {
                          _loadBackups();
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'restore', child: Text('Restore')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
