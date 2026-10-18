import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/ad_service.dart';
import '../../../../core/services/review_service.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final settings = ref.watch(settingsMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: UIHelper.listPadding,
        children: [
          // ── Appearance ──────────────────────────────────────────
          const SectionHeader(title: 'Appearance'),
          _ThemeChooser(
            current: themeState.mode,
            onChanged: (mode) =>
                ref.read(themeControllerProvider.notifier).setMode(mode),
          ),

          // ── Playback ────────────────────────────────────────────
          const SectionHeader(title: 'Playback'),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Playback settings'),
            subtitle: const Text('Speed, background audio, PiP, etc.'),
            onTap: () => context.push(AppRouter.playbackSettings),
          ),
          ListTile(
            leading: const Icon(Icons.equalizer),
            title: const Text('Equalizer'),
            subtitle: const Text('Audio frequency bands & presets'),
            onTap: () => context.push(AppRouter.equalizer),
          ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Audio Effects'),
            subtitle: const Text('Bass, treble, balance, reverb'),
            onTap: () => context.push(AppRouter.audioEffects),
          ),

          // ── Subtitles ───────────────────────────────────────────
          const SectionHeader(title: 'Subtitles'),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('Subtitle settings'),
            subtitle: const Text('Font, size, color, delay, etc.'),
            onTap: () => context.push(AppRouter.subtitleSettings),
          ),

          // ── Gestures ────────────────────────────────────────────
          const SectionHeader(title: 'Gestures'),
          ListTile(
            leading: const Icon(Icons.touch_app),
            title: const Text('Gesture settings'),
            subtitle: const Text('Enable/disable, durations, etc.'),
            onTap: () => context.push(AppRouter.gestureSettings),
          ),

          // ── Network ─────────────────────────────────────────────
          const SectionHeader(title: 'Network'),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('Open network stream'),
            subtitle: const Text('HLS, DASH, RTSP, SMB, FTP, etc.'),
            onTap: () => context.push(AppRouter.networkStream),
          ),

          // ── Library ─────────────────────────────────────────────
          const SectionHeader(title: 'Library'),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Queue'),
            onTap: () => context.push(AppRouter.queue),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Smart Playlists'),
            onTap: () => context.push(AppRouter.smartPlaylists),
          ),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Folder Exclusions'),
            subtitle: const Text('Exclude folders from scanner'),
            onTap: () => context.push(AppRouter.folderExclusions),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Bookmarks'),
            onTap: () => context.push(AppRouter.bookmarks),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Downloads'),
            onTap: () => context.go(AppRouter.downloads),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Downloader settings'),
            subtitle: const Text(
              'Enable/disable, file size, concurrency, cleanup, providers',
            ),
            onTap: () => context.push(AppRouter.downloaderSettings),
          ),

          // ── Privacy ─────────────────────────────────────────────
          const SectionHeader(title: 'Privacy'),
          _SettingsSwitch(
            settings: settings,
            settingKey: SettingsKeys.analytics,
            label: 'Send anonymous analytics',
          ),

          // ── IPTV ─────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.live_tv_outlined),
            title: const Text('IPTV'),
            subtitle: const Text('Import M3U/M3U8 playlists'),
            onTap: () => context.push(AppRouter.iptv),
          ),

          // ── Storage ────────────────────────────────────────────
          const SectionHeader(title: 'Storage & Data'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage & Data'),
            subtitle: const Text('Manage cache, downloads, and app data'),
            onTap: () => context.push(AppRouter.storage),
          ),

          // ── Backup ─────────────────────────────────────────────
          const SectionHeader(title: 'Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export and import your data'),
            onTap: () => context.push(AppRouter.backupRestore),
          ),

          // ── Language ─────────────────────────────────────────
          const SectionHeader(title: 'Language'),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('App Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context),
          ),

          // ── Support ─────────────────────────────────────────────
          const SectionHeader(title: 'Support'),
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('Watch Ad to Support'),
            subtitle: const Text('Watch a short ad to support development'),
            onTap: () async {
              final reward = await AdService.showRewardedAd(
                onReward: (amount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thanks for watching! ❤️')),
                  );
                },
              );
              if (!reward && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ad not ready yet. Try again later.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate VolticPlayer'),
            onTap: () => ReviewService.openStoreListing(),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a Bug'),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              final uri = Uri(
                scheme: 'mailto',
                path: 'support@volticplayer.app',
                queryParameters: {
                  'subject': 'Bug Report - VolticPlayer ${info.version}',
                  'body':
                      'Describe the bug here:\n\nApp Version: ${info.version}\nBuild: ${info.buildNumber}\n',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),

          // ── About ───────────────────────────────────────────────
          const SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About VolticPlayer'),
            onTap: () => context.push(AppRouter.about),
          ),
        ],
      ),
    );
  }
}

// ─── Visual Theme Chooser ────────────────────────────────────────────────

void _showLanguagePicker(BuildContext context) {
  final languages = {
    'English': 'en',
    'فارسی (Dari)': 'fa',
    'پښتو (Pashto)': 'ps',
    'العربية (Arabic)': 'ar',
    'اردو (Urdu)': 'ur',
  };

  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Language',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ...languages.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.language),
              title: Text(entry.key),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Language set to ${entry.key} (restart required)',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _ThemeChooser extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ThemeChooser({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.resolvesDark(current);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceMD),
      child: Row(
        children: [
          Expanded(
            child: _ThemeCard(
              label: 'Light',
              icon: Icons.light_mode,
              mode: 'light',
              isSelected: !isDark,
              onTap: () => onChanged('light'),
              previewColors: _PreviewColors(
                scaffold: const Color(0xFFF6F6F8),
                card: Colors.white,
                accent: const Color(0xFF000000),
                text: Colors.black87,
              ),
            ),
          ),
          UIHelper.hSM,
          Expanded(
            child: _ThemeCard(
              label: 'Dark',
              icon: Icons.dark_mode,
              mode: 'dark',
              isSelected: isDark,
              onTap: () => onChanged('dark'),
              previewColors: _PreviewColors(
                scaffold: const Color(0xFF101013),
                card: const Color(0xFF1A1A1E),
                accent: const Color(0xFFFFFFFF),
                text: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewColors {
  final Color scaffold;
  final Color card;
  final Color accent;
  final Color text;

  const _PreviewColors({
    required this.scaffold,
    required this.card,
    required this.accent,
    required this.text,
  });
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String mode;
  final bool isSelected;
  final VoidCallback onTap;
  final _PreviewColors previewColors;

  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.previewColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIHelper.radiusSM),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Mini preview ──────────────────────────────────
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: previewColors.scaffold,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(UIHelper.radiusXS + 2),
                ),
              ),
              child: Stack(
                children: [
                  // Mini card
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: previewColors.card,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: previewColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: previewColors.text.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Mini nav bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: previewColors.card,
                        border: Border(
                          top: BorderSide(
                            color: previewColors.text.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (i) => Icon(
                            [
                              Icons.home,
                              Icons.movie,
                              Icons.music_note,
                              Icons.folder,
                            ][i],
                            size: 7,
                            color: i == 0
                                ? previewColors.accent
                                : previewColors.text.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Label ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : previewColors.card,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(UIHelper.radiusXS + 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Switch ─────────────────────────────────────────────────────

class _SettingsSwitch extends ConsumerWidget {
  final AsyncValue<Map<String, bool>> settings;
  final String settingKey;
  final String label;

  const _SettingsSwitch({
    required this.settings,
    required this.settingKey,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value =
        settings.value?[settingKey] ?? SettingsKeys.defaultFor(settingKey);
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (v) async {
        final repo = ref.read(settingsRepositoryProvider);
        await repo.setSetting<bool>(settingKey, v);
        ref.invalidate(settingsMapProvider);
      },
    );
  }
}
