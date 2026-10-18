import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/ui_helper.dart';
import '../../core/services/global_player_controller.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/app_logo.dart';
import '../router/app_router.dart';

/// Persistent bottom-navigation shell for the 5 main tabs.
///
/// Features:
/// - Custom animated indicator on selected tab
/// - Mini player integration (shows when media is playing)
/// - Tablet: NavigationRail with mini player on the side
/// - System UI overlay style adapts to theme
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin {
  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorAnimation;

  static const _destinations = [
    _Tab(
      route: '/home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _Tab(
      route: '/videos',
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie_rounded,
      label: 'Videos',
    ),
    _Tab(
      route: '/music',
      icon: Icons.music_note_outlined,
      activeIcon: Icons.music_note_rounded,
      label: 'Music',
    ),
    _Tab(
      route: '/playlists',
      icon: Icons.queue_music_outlined,
      activeIcon: Icons.queue_music_rounded,
      label: 'Playlists',
    ),
    _Tab(
      route: '/downloads',
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      label: 'Downloads',
    ),
    _Tab(
      route: '/more',
      icon: Icons.more_horiz,
      activeIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeInOut,
    );
    _indicatorController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUI();
  }

  void _updateSystemUI() {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == widget.shell.currentIndex) return;
    HapticFeedback.lightImpact();
    _indicatorController.forward(from: 0);
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = UIHelper.isTablet(context);
    final playerState = ref.watch(globalPlayerProvider);
    final showMiniPlayer = playerState.hasMedia;

    if (isWide) {
      return _buildTabletLayout(
        context,
        theme,
        showMiniPlayer,
        playerState,
      );
    }
    return _buildMobileLayout(
      context,
      theme,
      showMiniPlayer,
      playerState,
    );
  }

  // ─── Mobile Layout ─────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    bool showMiniPlayer,
    GlobalPlayerState playerState,
  ) {
    // Floating pill nav still needs body content/FABs to clear it. Prefer
    // layout above the bar (extendBody: false) so nested FloatingActionButtons
    // never render underneath the navigation.
    return Scaffold(
      extendBody: false,
      body: Column(
        children: [
          Expanded(child: widget.shell),

          // Mini player (above bottom nav)
          if (showMiniPlayer)
            MiniPlayer(
              item: playerState.currentItem!,
              position: playerState.position,
              duration: playerState.duration,
              playing: playerState.isPlaying,
              onTap: () {
                // Navigate to the full player based on mode
                final item = playerState.currentItem!;
                if (playerState.isVideo) {
                  context.push(
                    AppRouter.videoPlayer,
                    extra: {
                      'uri': item.uri,
                      'title': item.displayName,
                      'thumbnailPath': item.thumbnailPath,
                    },
                  );
                } else {
                  context.push(
                    AppRouter.audioPlayer,
                    extra: {
                      'uri': item.uri,
                      'title': item.displayName,
                      'artist': item.artist,
                      'artworkPath': item.thumbnailPath,
                    },
                  );
                }
              },
              onPlayPause: () {
                ref.read(globalPlayerProvider.notifier).togglePlayPause();
              },
              onClose: () {
                ref.read(globalPlayerProvider.notifier).stopAll();
              },
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        destinations: _destinations,
        selectedIndex: widget.shell.currentIndex,
        onTap: _onTap,
        indicatorAnimation: _indicatorAnimation,
      ),
    );
  }

  // ─── Tablet Layout ─────────────────────────────────────────────────────

  Widget _buildTabletLayout(
    BuildContext context,
    ThemeData theme,
    bool showMiniPlayer,
    GlobalPlayerState playerState,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          _TabletNavRail(
            destinations: _destinations,
            selectedIndex: widget.shell.currentIndex,
            onTap: _onTap,
          ),
          const VerticalDivider(width: 1, thickness: 1),

          // Main content + optional mini player
          Expanded(
            child: Column(
              children: [
                Expanded(child: widget.shell),
                if (showMiniPlayer)
                  MiniPlayer(
                    item: playerState.currentItem!,
                    position: playerState.position,
                    duration: playerState.duration,
                    playing: playerState.isPlaying,
                    onTap: () {
                      final item = playerState.currentItem!;
                      if (playerState.isVideo) {
                        context.push(
                          AppRouter.videoPlayer,
                          extra: {
                            'uri': item.uri,
                            'title': item.displayName,
                            'thumbnailPath': item.thumbnailPath,
                          },
                        );
                      } else {
                        context.push(
                          AppRouter.audioPlayer,
                          extra: {
                            'uri': item.uri,
                            'title': item.displayName,
                            'artist': item.artist,
                            'artworkPath': item.thumbnailPath,
                          },
                        );
                      }
                    },
                    onPlayPause: () {
                      ref.read(globalPlayerProvider.notifier).togglePlayPause();
                    },
                    onClose: () {
                      ref.read(globalPlayerProvider.notifier).stopAll();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Bottom Navigation Bar ────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final List<_Tab> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Animation<double> indicatorAnimation;

  const _BottomNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    required this.indicatorAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(11);
    final navHeight = (46 + scaledLabelSize).clamp(64, 120).toDouble();

    // Home stays first (leftmost); route indexes match the tab order.
    const visualOrder = [0, 1, 2, 3, 4, 5];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SizedBox(
              height: navHeight,
              child: Row(
                children: [
                  for (final i in visualOrder)
                    Expanded(
                      child: _NavTab(
                        tab: destinations[i],
                        isSelected: i == selectedIndex,
                        onTap: () => onTap(i),
                        colorScheme: colorScheme,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Individual Tab ──────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  final _Tab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _NavTab({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with animated scale
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 10 : 0,
                vertical: isSelected ? 2 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
              ),
              child: Icon(
                isSelected ? tab.activeIcon : tab.icon,
                size: 24,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tablet Navigation Rail ──────────────────────────────────────────────

class _TabletNavRail extends StatelessWidget {
  final List<_Tab> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _TabletNavRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      labelType: NavigationRailLabelType.all,
      backgroundColor: theme.colorScheme.surface,
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: UIHelper.spaceMD),
        child: const AppLogo(size: 40, radius: UIHelper.radiusSM),
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.activeIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

// ─── Tab Data ────────────────────────────────────────────────────────────

class _Tab {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _Tab({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
