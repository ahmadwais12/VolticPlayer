import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/data/google_profile_service.dart';
import '../../../settings/presentation/controllers/theme_controller.dart';

/// Hub for library tools, downloads, playback features and app settings.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeControllerProvider);
    final currentMode = themeState.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          UIHelper.spaceSM,
          UIHelper.spaceMD,
          UIHelper.spaceXXL,
        ),
        children: [
          // ── Profile / YouTube sign-in ───────────────────────────
          const _ProfileEntry(),
          UIHelper.vLG,

          // ── Theme ───────────────────────────────────────────────
          _SectionLabel('Appearance'),
          UIHelper.vSM,
          _ThemeSelector(
            current: currentMode,
            onChanged: (mode) =>
                ref.read(themeControllerProvider.notifier).setMode(mode),
          ),
          UIHelper.vLG,

          // ── Quick actions ───────────────────────────────────────
          _SectionLabel('Quick access'),
          UIHelper.vSM,
          _QuickLinks(
            links: const [
              _MoreLink(Icons.search_rounded, 'Search', AppRouter.search),
              _MoreLink(Icons.history_rounded, 'History', AppRouter.history),
              _MoreLink(
                Icons.favorite_outline_rounded,
                'Favorites',
                AppRouter.favorites,
              ),
              _MoreLink(
                Icons.bookmark_outline_rounded,
                'Bookmarks',
                AppRouter.bookmarks,
              ),
              _MoreLink(
                Icons.travel_explore_rounded,
                'Online search',
                AppRouter.downloads,
              ),
              _MoreLink(
                Icons.download_for_offline_outlined,
                'My downloads',
                AppRouter.downloadDetails,
              ),
            ],
          ),
          UIHelper.vLG,

          // ── Library ─────────────────────────────────────────────
          _MoreSection(
            title: 'Library',
            links: const [
              _MoreLink(
                Icons.queue_music_rounded,
                'Playlists',
                AppRouter.playlists,
                subtitle: 'Create and organize playlists',
              ),
              _MoreLink(
                Icons.auto_awesome_outlined,
                'Smart playlists',
                AppRouter.smartPlaylists,
                subtitle: 'Collections built from your library',
              ),
              _MoreLink(
                Icons.playlist_play_rounded,
                'Playback queue',
                AppRouter.queue,
                subtitle: 'See what plays next',
              ),
              _MoreLink(
                Icons.folder_outlined,
                'Browse folders',
                AppRouter.folders,
                subtitle: 'Local media by folder',
              ),
              _MoreLink(
                Icons.folder_off_outlined,
                'Folder exclusions',
                AppRouter.folderExclusions,
                subtitle: 'Hide folders from scanning',
              ),
              _MoreLink(
                Icons.storage_outlined,
                'Storage',
                AppRouter.storage,
                subtitle: 'Cache and media space',
              ),
            ],
          ),

          // ── Downloads ───────────────────────────────────────────
          _MoreSection(
            title: 'Downloads',
            links: const [
              _MoreLink(
                Icons.download_for_offline_outlined,
                'Download manager',
                AppRouter.downloadDetails,
                subtitle: 'View, pause and organize downloads',
              ),
              _MoreLink(
                Icons.link_rounded,
                'Download from URL',
                AppRouter.videoDownloader,
                subtitle: 'Paste a link and pick a format',
              ),
              _MoreLink(
                Icons.travel_explore_rounded,
                'Online search',
                AppRouter.downloads,
                subtitle: 'Find songs, movies and playlists',
              ),
              _MoreLink(
                Icons.tune_outlined,
                'Downloader settings',
                AppRouter.downloaderSettings,
                subtitle: 'Limits, media types and providers',
              ),
            ],
          ),

          // ── Playback ────────────────────────────────────────────
          _MoreSection(
            title: 'Playback',
            links: const [
              _MoreLink(
                Icons.equalizer_rounded,
                'Equalizer',
                AppRouter.equalizer,
                subtitle: 'Bands and presets',
              ),
              _MoreLink(
                Icons.graphic_eq_rounded,
                'Audio effects',
                AppRouter.audioEffects,
                subtitle: 'Bass, treble, balance, reverb',
              ),
              _MoreLink(
                Icons.play_circle_outline_rounded,
                'Playback settings',
                AppRouter.playbackSettings,
                subtitle: 'Speed, background audio, PiP',
              ),
              _MoreLink(
                Icons.subtitles_outlined,
                'Subtitle settings',
                AppRouter.subtitleSettings,
                subtitle: 'Font, size, color and delay',
              ),
              _MoreLink(
                Icons.touch_app_outlined,
                'Gesture settings',
                AppRouter.gestureSettings,
                subtitle: 'Tap, swipe and seek controls',
              ),
              _MoreLink(
                Icons.video_settings_outlined,
                'Video filters',
                AppRouter.videoFilters,
                subtitle: 'Brightness, contrast and more',
              ),
            ],
          ),

          // ── Explore ─────────────────────────────────────────────
          _MoreSection(
            title: 'Explore & connect',
            links: const [
              _MoreLink(
                Icons.public_outlined,
                'Sites',
                AppRouter.sites,
                subtitle: 'YouTube, Instagram, Facebook and more',
              ),
              _MoreLink(
                Icons.live_tv_outlined,
                'IPTV',
                AppRouter.iptv,
                subtitle: 'Live channels and playlists',
              ),
              _MoreLink(
                Icons.wifi_rounded,
                'Network stream',
                AppRouter.networkStream,
                subtitle: 'Open a stream from a URL',
              ),
            ],
          ),

          // ── App ─────────────────────────────────────────────────
          _MoreSection(
            title: 'App',
            links: const [
              _MoreLink(
                Icons.palette_outlined,
                'Appearance',
                AppRouter.settings,
                subtitle: 'Theme and display preferences',
              ),
              _MoreLink(
                Icons.settings_outlined,
                'Settings',
                AppRouter.settings,
                subtitle: 'All app preferences',
              ),
              _MoreLink(
                Icons.backup_outlined,
                'Backup and restore',
                AppRouter.backupRestore,
                subtitle: 'Save or restore your data',
              ),
              _MoreLink(
                Icons.info_outline_rounded,
                'About ${AppConstants.appName}',
                AppRouter.about,
                subtitle: 'Version, licenses and credits',
              ),
            ],
          ),

          UIHelper.vMD,
          Center(
            child: Text(
              AppConstants.appName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.outline,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreLink {
  const _MoreLink(this.icon, this.title, this.route, {this.subtitle});

  final IconData icon;
  final String title;
  final String route;
  final String? subtitle;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Compact entry to the YouTube sign-in flow on the More page.
///
/// Signed out it reads "Sign in" and opens the full "Sign in with YouTube"
/// screen; once signed in the label switches to "Profile" and opens the
/// Profile page.
class _ProfileEntry extends StatefulWidget {
  const _ProfileEntry();

  @override
  State<_ProfileEntry> createState() => _ProfileEntryState();
}

class _ProfileEntryState extends State<_ProfileEntry> {
  final _google = GoogleProfileService.instance;
  SignedInProfile? _account;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    SignedInProfile? account;
    try {
      account = await _google.currentProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _account = account;
      // Only a real Google sign-in writes a profile, so tapping the row always
      // opens the Google sign-in page. The downloader's own
      // `downloads_youtube_signed_in_v1` unlock flag must not short-circuit it
      // into the Profile screen.
      _signedIn = account != null;
    });
  }

  Future<void> _onTap() async {
    if (_signedIn) {
      await context.push(AppRouter.profile);
      if (mounted) await _restore();
      return;
    }
    final result = await context.push<bool>(AppRouter.youtubeSignIn);
    if (!mounted || result != true) return;
    await _restore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = _account;

    final title = _signedIn ? 'Profile' : 'Sign in';
    final signedInLabel = account?.displayName ?? account?.email;
    final subtitle = _signedIn
        ? (signedInLabel ?? 'Manage your account and preferences')
        : 'Sign in with YouTube to unlock subscriptions, watch later, '
              'history and more';

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(UIHelper.radiusLG),
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(UIHelper.spaceSM + 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UIHelper.radiusLG),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              _ProfileAvatar(account: account, signedIn: _signedIn),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading icon for [_ProfileEntry]: the YouTube badge while signed out, the
/// account photo once the user is signed in.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.account, required this.signedIn});

  final SignedInProfile? account;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (signedIn) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: colors.primaryContainer,
        backgroundImage: account?.photoUrl == null
            ? null
            : NetworkImage(account!.photoUrl!),
        child: account?.photoUrl == null
            ? Icon(Icons.person_rounded, color: colors.onPrimaryContainer)
            : null,
      );
    }
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFE62117),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SvgPicture.asset(
        'assets/icons/youtube.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.links});

  final List<_MoreLink> links;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: links.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: UIHelper.spaceSM,
        crossAxisSpacing: UIHelper.spaceSM,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final link = links[index];
        return Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(UIHelper.radiusMD),
          child: InkWell(
            onTap: () => context.push(link.route),
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
            child: Padding(
              padding: const EdgeInsets.all(UIHelper.spaceSM),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                    ),
                    child: Icon(link.icon, color: colors.primary, size: 22),
                  ),
                  UIHelper.vSM,
                  Text(
                    link.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.links});

  final String title;
  final List<_MoreLink> links;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: UIHelper.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          UIHelper.vSM,
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(UIHelper.radiusMD),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < links.length; index++) ...[
                  _MoreTile(link: links[index]),
                  if (index != links.length - 1)
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 12,
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.link});

  final _MoreLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UIHelper.spaceSM + 4,
        vertical: 2,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(UIHelper.radiusSM),
        ),
        child: Icon(link.icon, color: colors.primary, size: 21),
      ),
      title: Text(
        link.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: link.subtitle == null
          ? null
          : Text(
              link.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.outline),
      onTap: () => context.push(link.route),
    );
  }
}

// ── Theme Selector ───────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('light', Icons.light_mode_rounded, 'Light'),
    ('dark', Icons.dark_mode_rounded, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = AppTheme.resolvesDark(current);

    final children = <Widget>[];
    for (final (mode, icon, label) in _options) {
      final selected = (mode == 'dark') == isDark;
      children.add(
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                border: Border.all(
                  color: selected
                      ? colors.primary
                      : colors.outlineVariant.withValues(alpha: 0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mode != _options.last.$1) children.add(const SizedBox(width: 8));
    }
    return Row(children: children);
  }
}
