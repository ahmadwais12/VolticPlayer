import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/downloader_limits.dart';
import '../../../../core/services/downloader_settings.dart';

/// Download preferences presented in the compact file-manager style.
class DownloaderSettingsScreen extends ConsumerWidget {
  const DownloaderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(downloaderSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'Download Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ),
      ),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Download settings could not be loaded.')),
        data: (settings) {
          final controller = ref.read(downloaderSettingsProvider.notifier);
          final tasks = settings.maxConcurrent.clamp(
            1,
            DownloaderLimits.maxConcurrent.clamp(1, 6),
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              FutureBuilder<Directory>(
                future: getApplicationDocumentsDirectory(),
                builder: (context, snapshot) {
                  final separator = Platform.pathSeparator;
                  final rootPath =
                      settings.downloadPath ??
                      (snapshot.hasData
                          ? '${snapshot.data!.path}${separator}${AppConstants.appName}'
                          : null);
                  final path = rootPath == null
                      ? 'Loading download folder…'
                      : '$rootPath$separator  ·  '
                            '${AppConstants.downloadSubfolders.join(' / ')}';
                  return _SettingRow(
                    title: 'Download path setting',
                    subtitle: path,
                    onTap: () async {
                      final selected = await FilePicker.platform
                          .getDirectoryPath(
                            dialogTitle: 'Choose download folder',
                          );
                      if (selected != null) {
                        await controller.setDownloadPath(selected);
                        ref
                            .read(downloadManagerProvider.notifier)
                            .refreshFromDisk();
                      }
                    },
                  );
                },
              ),
              _divider(),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: const Text('Download Only in WiFi'),
                value: settings.wifiOnly,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setWifiOnly,
              ),
              _divider(),
              _SettingRow(
                title: 'Max download tasks',
                trailing: '$tasks',
                onTap: () => _selectTaskCount(context, ref, tasks),
              ),
              _divider(),
              _SettingRow(
                title: 'Fast Download Option',
                subtitle: 'Multiple connections for one download',
                onTap: () => _chooseFastDownload(
                  context,
                  controller,
                  settings.fastDownload,
                ),
              ),
              _divider(),
              _SettingRow(
                title: 'Auto Resume downloading',
                trailing: settings.autoResume ? 'Always' : 'Never',
                onTap: () =>
                    _chooseAutoResume(context, controller, settings.autoResume),
              ),
              _divider(),
              _SettingRow(
                title: 'Download Subtitle',
                trailing: settings.downloadSubtitle,
                onTap: () => _chooseSubtitle(
                  context,
                  controller,
                  settings.downloadSubtitle,
                ),
              ),
              _divider(),
              _SettingRow(
                title: 'Download Music Quality',
                trailing: settings.musicQuality,
                onTap: () => _chooseMusicQuality(
                  context,
                  controller,
                  settings.musicQuality,
                ),
              ),
              _sectionGap(theme),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                title: const Text('Copied Link Detection'),
                subtitle: const Text(
                  'Show download button and notification after detecting a downloadable link from clipboard',
                ),
                value: settings.clipboardDetection,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setClipboardDetection,
              ),
              _sectionGap(theme),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                title: const Text('Show hidden files'),
                subtitle: const Text(
                  'Show hidden folders and files starting with .(dot)',
                ),
                value: settings.showHiddenFiles,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setShowHiddenFiles,
              ),
              _sectionGap(theme),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                title: const Text('Download complete notification'),
                value: settings.notifyOnComplete,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setNotifyOnComplete,
              ),
              _sectionGap(theme),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                title: const Text('Delete apk file after installation'),
                value: settings.deleteApkAfterInstall,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setDeleteApkAfterInstall,
              ),
              _sectionGap(theme),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                title: const Text('Smart Muxer'),
                subtitle: const Text(
                  'Increase download speed, improve success rate and reduce storage space.',
                ),
                value: settings.smartMuxer,
                activeTrackColor: const Color(0xFF42A5F5),
                onChanged: controller.setSmartMuxer,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 28),
    child: Divider(height: 1),
  );

  Widget _sectionGap(ThemeData theme) => Container(
    height: 14,
    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
  );

  Future<void> _selectTaskCount(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final maximum = DownloaderLimits.maxConcurrent.clamp(1, 6);
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var selected = current;
        return AlertDialog(
          title: const Text(
            'Select Download Task Count',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          actionsPadding: const EdgeInsets.only(right: 12, bottom: 8),
          content: StatefulBuilder(
            builder: (context, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var count = 1; count <= maximum; count++)
                  ListTile(
                    leading: Icon(
                      count == selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: count == selected
                          ? const Color(0xFF2196F3)
                          : Colors.grey,
                    ),
                    title: Text('$count'),
                    onTap: () {
                      setLocal(() => selected = count);
                      Navigator.pop(dialogContext, count);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Color(0xFF42A5F5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (value == null) return;
    await ref.read(downloaderSettingsProvider.notifier).setMaxConcurrent(value);
    ref.read(downloadManagerProvider.notifier).setMaxConcurrent(value);
  }

  Future<void> _chooseAutoResume(
    BuildContext context,
    DownloaderSettingsController controller,
    bool current,
  ) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Auto Resume downloading'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: _RadioChoice('Always', current),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: _RadioChoice('Never', !current),
          ),
        ],
      ),
    );
    if (value != null) await controller.setAutoResume(value);
  }

  Future<void> _chooseFastDownload(
    BuildContext context,
    DownloaderSettingsController controller,
    bool current,
  ) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Fast Download Option'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: _RadioChoice('On', current),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: _RadioChoice('Off', !current),
          ),
        ],
      ),
    );
    if (value != null) await controller.setFastDownload(value);
  }

  Future<void> _chooseSubtitle(
    BuildContext context,
    DownloaderSettingsController controller,
    String current,
  ) async {
    const options = ['System Language', 'English', 'Off'];
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Download Subtitle'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: _RadioChoice(option, option == current),
            ),
        ],
      ),
    );
    if (value != null) await controller.setDownloadSubtitle(value);
  }

  Future<void> _chooseMusicQuality(
    BuildContext context,
    DownloaderSettingsController controller,
    String current,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Download Music Quality'),
        children: [
          for (final quality in ['Low', 'Medium', 'High'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, quality),
              child: _RadioChoice(quality, quality == current),
            ),
        ],
      ),
    );
    if (value != null) await controller.setMusicQuality(value);
  }
}

class _RadioChoice extends StatelessWidget {
  const _RadioChoice(this.label, this.selected);
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected
            ? const Color(0xFF2196F3)
            : Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      title: Text(title, style: TextStyle(color: colors.onSurface)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant)),
      trailing: trailing == null
          ? null
          : Text(trailing!, style: TextStyle(color: colors.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}
