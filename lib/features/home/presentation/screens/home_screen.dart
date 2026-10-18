import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/library_entities.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_card.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/poster_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/shell_fab.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: state.when(
          loading: () => const LibraryLoadingState(
            title: 'Home',
            icon: Icons.home_rounded,
          ),
          error: (e, _) => UIHelper.errorState(
            context: context,
            message: 'Couldn’t load home: $e',
            actionLabel: 'Retry',
            onAction: () => ref.read(homeControllerProvider.notifier).reload(),
          ),
          data: (s) => RefreshIndicator(
            color: colors.primary,
            onRefresh: () => ref.read(homeControllerProvider.notifier).reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _HomeAppBar(
                  onSearch: () => context.push(AppRouter.search),
                  onFavorites: () => context.push(AppRouter.favorites),
                  onHistory: () => context.push(AppRouter.history),
                ),
                SliverToBoxAdapter(
                  child: _HomeGreeting(
                    videoCount: s.videoCount,
                    musicCount: s.musicCount,
                    playlistCount: s.playlists.length,
                    hasContinue: s.continueWatching.isNotEmpty,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _QuickActions(
                    onOpenFile: () => _openFile(context),
                    onVideos: () => context.go(AppRouter.videos),
                    onMusic: () => context.go(AppRouter.music),
                    onDownload: () =>
                        context.push(AppRouter.videoDownloaderLanding),
                  ),
                ),

                if (s.continueWatching.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Continue Watching',
                      actionLabel: 'History',
                      onAction: () => context.push(AppRouter.history),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIHelper.spaceMD,
                        ),
                        itemCount: s.continueWatching.length,
                        separatorBuilder: (_, _) => UIHelper.hSM,
                        itemBuilder: (context, i) {
                          final item = s.continueWatching[i];
                          final p = s.progress[item.id] ?? 0.0;
                          return _ContinueWatchingCard(
                            item: item,
                            progress: p,
                            onTap: () => openMedia(context, item),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: UIHelper.vMD),
                ],

                if (s.recentVideos.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Videos',
                      actionLabel: 'See all',
                      onAction: () => context.go(AppRouter.videos),
                    ),
                  ),
                  SliverPadding(
                    padding: UIHelper.listPadding,
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: UIHelper.responsiveColumns(context),
                        mainAxisSpacing: UIHelper.spaceMD,
                        crossAxisSpacing: UIHelper.spaceMD,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _HomeFadeIn(
                          delay: Duration(milliseconds: 40 * i),
                          child: MediaCard(
                            item: s.recentVideos[i],
                            onTap: () => openMedia(context, s.recentVideos[i]),
                          ),
                        ),
                        childCount: s.recentVideos.length,
                      ),
                    ),
                  ),
                ],

                if (s.music.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Music',
                      actionLabel: 'See all',
                      onAction: () => context.go(AppRouter.music),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 168 + MediaQuery.textScalerOf(context).scale(36),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIHelper.spaceMD,
                        ),
                        itemCount: s.music.length,
                        separatorBuilder: (_, _) => UIHelper.hSM,
                        itemBuilder: (context, i) {
                          final item = s.music[i];
                          return _MusicCard(
                            item: item,
                            onTap: () => openMedia(context, item),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: UIHelper.vMD),
                ],

                if (s.playlists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Playlists',
                      actionLabel: 'See all',
                      onAction: () => context.go(AppRouter.playlists),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIHelper.spaceMD,
                        ),
                        itemCount: s.playlists.length,
                        separatorBuilder: (_, _) => UIHelper.hSM,
                        itemBuilder: (context, i) {
                          final playlist = s.playlists[i];
                          return _PlaylistCard(
                            playlist: playlist,
                            accentIndex: i,
                            onTap: () => context.push(
                              '${AppRouter.playlists}/${playlist.id}',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: UIHelper.vMD),
                ],

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: UIHelper.spaceSM),
                    child: _HomeBannerAd(),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: UIHelper.spaceXXL),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: ShellFab(
          child: FloatingActionButton.extended(
            onPressed: () => _openFile(context),
            icon: const Icon(Icons.file_open_rounded),
            label: const Text('Open file'),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final file = File(path);
    final name = result.files.first.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final isVideo = [
      'mp4',
      'mkv',
      'avi',
      'mov',
      'webm',
      'flv',
      'ts',
      '3gp',
    ].contains(ext);
    if (!context.mounted) return;
    if (isVideo) {
      context.push(
        AppRouter.videoPlayer,
        extra: {'uri': file.path, 'title': name},
      );
    } else {
      context.push(
        AppRouter.audioPlayer,
        extra: {'uri': file.path, 'title': name},
      );
    }
  }
}

// ─── App bar ────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onFavorites;
  final VoidCallback onHistory;

  const _HomeAppBar({
    required this.onSearch,
    required this.onFavorites,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      expandedHeight: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      titleSpacing: UIHelper.spaceMD,
      title: Row(
        children: [
          const AppLogo(size: 36, radius: UIHelper.radiusSM),
          UIHelper.hSM,
          Text(
            'VolticPlayer',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
      actions: [
        _AppBarIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onPressed: onSearch,
        ),
        _AppBarIconButton(
          icon: Icons.favorite_outline_rounded,
          tooltip: 'Favorites',
          onPressed: onFavorites,
        ),
        _AppBarIconButton(
          icon: Icons.history_rounded,
          tooltip: 'History',
          onPressed: onHistory,
        ),
        UIHelper.hXS,
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: colors.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          foregroundColor: colors.onSurface,
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

// ─── Greeting ───────────────────────────────────────────────────────────────

class _HomeGreeting extends StatelessWidget {
  final int videoCount;
  final int musicCount;
  final int playlistCount;
  final bool hasContinue;

  const _HomeGreeting({
    required this.videoCount,
    required this.musicCount,
    required this.playlistCount,
    required this.hasContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final subtitle = hasContinue
        ? 'Pick up where you left off'
        : 'Videos, music and playlists ready for you';

    return _HomeFadeIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          UIHelper.spaceXS,
          UIHelper.spaceMD,
          UIHelper.spaceMD,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(UIHelper.spaceMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UIHelper.radiusLG),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.16),
                colors.tertiary.withValues(alpha: 0.08),
                colors.surfaceContainerHighest.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    UIHelper.vXS,
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    UIHelper.vSM,
                    Wrap(
                      spacing: UIHelper.spaceSM,
                      runSpacing: UIHelper.spaceXS,
                      children: [
                        _SoftChip(
                          icon: Icons.movie_rounded,
                          label: '$videoCount videos',
                        ),
                        _SoftChip(
                          icon: Icons.music_note_rounded,
                          label: '$musicCount tracks',
                        ),
                        _SoftChip(
                          icon: Icons.queue_music_rounded,
                          label: '$playlistCount playlists',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: colors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          UIHelper.hXS,
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Quick actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onVideos;
  final VoidCallback onMusic;
  final VoidCallback onDownload;

  const _QuickActions({
    required this.onOpenFile,
    required this.onVideos,
    required this.onMusic,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickActionData(
        label: 'Videos',
        icon: Icons.movie_rounded,
        onTap: onVideos,
        tone: 0,
      ),
      _QuickActionData(
        label: 'Music',
        icon: Icons.music_note_rounded,
        onTap: onMusic,
        tone: 1,
      ),
      _QuickActionData(
        label: 'Download',
        icon: Icons.cloud_download_rounded,
        onTap: onDownload,
        tone: 2,
      ),
      _QuickActionData(
        label: 'Open',
        icon: Icons.folder_open_rounded,
        onTap: onOpenFile,
        tone: 3,
      ),
    ];

    return _HomeFadeIn(
      delay: const Duration(milliseconds: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UIHelper.spaceMD,
          0,
          UIHelper.spaceMD,
          UIHelper.spaceMD,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) UIHelper.hSM,
              Expanded(child: _QuickActionTile(data: items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int tone;

  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tone,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickActionData data;

  const _QuickActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (data.tone) {
      0 => colors.primary,
      1 => colors.tertiary,
      2 => AppTheme.appColors(context).playerAccent,
      _ => colors.secondary,
    };

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(UIHelper.radiusMD),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: UIHelper.spaceMD,
            horizontal: UIHelper.spaceXS,
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                ),
                child: Icon(data.icon, color: accent, size: 22),
              ),
              UIHelper.vSM,
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Continue watching ──────────────────────────────────────────────────────

class _ContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  final double progress;
  final VoidCallback onTap;

  const _ContinueWatchingCard({
    required this.item,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final clamped = progress.clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(
                      path: item.thumbnailPath,
                      width: 220,
                      height: 124,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            UIHelper.radiusSM,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: colors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(UIHelper.radiusSM),
                        ),
                        child: LinearProgressIndicator(
                          value: clamped,
                          minHeight: 3.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: colors.primary,
                        ),
                      ),
                    ),
                    if (clamped > 0)
                      Positioned(
                        right: 8,
                        bottom: 10,
                        child: Text(
                          '${(clamped * 100).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              UIHelper.vSM,
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Resume playback',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Music card ─────────────────────────────────────────────────────────────

class _MusicCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _MusicCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MediaArtwork(item: item, width: 132, height: 132),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: colors.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              UIHelper.vSM,
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                item.artist?.isNotEmpty == true
                    ? item.artist!
                    : 'Unknown artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Playlist card ──────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final int accentIndex;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.accentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = [
      colors.primary,
      colors.tertiary,
      AppTheme.appColors(context).playerAccent,
      colors.secondary,
    ];
    final accent = accents[accentIndex % accents.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        child: Ink(
          width: 168,
          padding: const EdgeInsets.all(UIHelper.spaceMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UIHelper.radiusMD),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.22),
                colors.surfaceContainerHighest.withValues(alpha: 0.65),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.queue_music_rounded, color: accent),
              const Spacer(),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Entrance animation ─────────────────────────────────────────────────────

class _HomeFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _HomeFadeIn({required this.child, this.delay = Duration.zero});

  @override
  State<_HomeFadeIn> createState() => _HomeFadeInState();
}

class _HomeFadeInState extends State<_HomeFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final totalMs = math.max(1, widget.delay.inMilliseconds + 320);
    final startMs = widget.delay.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: startMs == 0
          ? Curves.easeOutCubic
          : Interval(startMs / totalMs, 1, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Banner Ad ──────────────────────────────────────────────────────────────

class _HomeBannerAd extends StatefulWidget {
  const _HomeBannerAd();

  @override
  State<_HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<_HomeBannerAd> {
  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _ad = AdService.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _isLoaded = true);
      },
      onFailedToLoad: () {
        if (mounted) setState(() => _isLoaded = false);
      },
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
