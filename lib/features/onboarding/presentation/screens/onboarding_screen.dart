import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/permissions/media_access_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../settings/presentation/controllers/theme_controller.dart';

/// Black & white onboarding tour.
///
/// Follows the monochrome logo identity: an ink/paper palette with no colour
/// accents, a hero card per feature, and content that lifts and fades as the
/// user scrolls between pages.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  String _mode = 'system';
  bool _finishing = false;

  static const _pages = <_OnboardPageData>[
    _OnboardPageData(
      step: '01',
      label: 'Library',
      icon: Icons.video_library_rounded,
      title: 'Your library,\nready to play',
      body:
          'Browse videos and music from your device in one clean place — folders, favorites, and history included.',
      features: [
        'Videos & music auto-grouped by folder',
        'Favorites and play history in one tap',
        'Grid, list, and folder views',
      ],
    ),
    _OnboardPageData(
      step: '02',
      label: 'Playback',
      icon: Icons.play_circle_fill_rounded,
      title: 'Playback that\nstays with you',
      body:
          'Gestures, speed control, subtitles, and background audio so watching and listening feel effortless.',
      features: [
        'Swipe gestures for volume & brightness',
        'Speed, aspect ratio, and subtitle sync',
        'Background audio with lock-screen controls',
      ],
    ),
    _OnboardPageData(
      step: '03',
      label: 'Downloads',
      icon: Icons.download_for_offline_rounded,
      title: 'Download &\nstream more',
      body:
          'Save media for offline play and open online sources without leaving VolticPlayer.',
      features: [
        'Batch downloads with pause & resume',
        'Built-in browser for online sources',
        'Integrity check on every downloaded file',
      ],
    ),
  ];

  bool get _isLast => _page >= _pages.length - 1;

  @override
  void initState() {
    super.initState();
    AnalyticsService.onboardingStarted();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(themeControllerProvider.notifier).setMode(_mode);
      await ref.read(settingsRepositoryProvider).setFirstLaunchDone();
      AnalyticsService.onboardingCompleted(themeChosen: _mode);
    } catch (_) {
      // Still leave onboarding — never trap the user here.
      try {
        await ref.read(settingsRepositoryProvider).setFirstLaunchDone();
      } catch (_) {}
    }

    // One-time media access prompt on a fresh install, then auto-scan. The UI
    // is fully up here, so the dialog shows reliably and never races the splash
    // notification ask. Awaits only the permission result — the scan itself
    // runs in the background and streams into the library pages.
    try {
      await ref.read(mediaAccessProvider.notifier).requestAndScan();
    } catch (_) {}

    if (!mounted) return;
    context.go(AppRouter.home);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _prev() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MonoBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onSkip: _finishing ? null : _finish),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) => _OnboardPage(
                      data: _pages[index],
                      controller: _pageController,
                      index: index,
                      showThemePicker: index == _pages.length - 1,
                      mode: _mode,
                      onModeChanged: (m) => setState(() => _mode = m),
                    ),
                  ),
                ),
                _BottomBar(
                  page: _page,
                  count: _pages.length,
                  isLast: _isLast,
                  disabled: _finishing,
                  onBack: _prev,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPageData {
  const _OnboardPageData({
    required this.step,
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    required this.features,
  });

  final String step;
  final String label;
  final IconData icon;
  final String title;
  final String body;
  final List<String> features;
}

/// Paper-white / ink-black canvas with a soft top-lit gradient.
class _MonoBackdrop extends StatelessWidget {
  const _MonoBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF101013), Color(0xFF0B0B0E), Color(0xFF070709)]
              : const [Color(0xFFFFFFFF), Color(0xFFF6F6F8), Color(0xFFEDEDF1)],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Row(
        children: [
          const AppLogo(size: 34, radius: 10, showShadow: false),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.data,
    required this.controller,
    required this.index,
    required this.showThemePicker,
    required this.mode,
    required this.onModeChanged,
  });

  final _OnboardPageData data;
  final PageController controller;
  final int index;
  final bool showThemePicker;
  final String mode;
  final ValueChanged<String> onModeChanged;

  /// How far this page sits from the viewport centre (-1 … 1). Drives the
  /// lift / fade / scale of every block so scrolling feels continuous.
  double get _delta {
    if (!controller.hasClients) return 0;
    if (!controller.position.hasContentDimensions) return 0;
    final page = controller.page;
    if (page == null) return 0;
    return (page - index).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final delta = _delta;
        final focus = (1 - delta.abs()).clamp(0.0, 1.0);
        final drop = 1 - focus;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Entrance(
                focus: focus,
                offset: Offset(0, -18 * delta),
                child: _HeroCard(data: data, focus: focus),
              ),
              const SizedBox(height: 30),
              _Entrance(
                focus: focus,
                offset: Offset(0, 22 * drop),
                child: Text(
                  data.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    height: 1.08,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Entrance(
                focus: focus,
                offset: Offset(0, 30 * drop),
                child: Text(
                  data.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (final feature in data.features) ...[
                _Entrance(
                  focus: focus,
                  offset: Offset(0, 38 * drop),
                  child: _FeatureRow(text: feature),
                ),
                const SizedBox(height: 12),
              ],
              if (showThemePicker) ...[
                const SizedBox(height: 20),
                _Entrance(
                  focus: focus,
                  offset: Offset(0, 42 * drop),
                  child: _ThemePicker(mode: mode, onChanged: onModeChanged),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Slides + fades its child in as the page approaches the viewport centre.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.focus,
    required this.offset,
    required this.child,
  });

  final double focus;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: focus,
      child: Transform.translate(offset: offset, child: child),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data, required this.focus});

  final _OnboardPageData data;
  final double focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Transform.scale(
      scale: 0.95 + 0.05 * focus,
      child: Container(
        height: 216,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1A1A1E), Color(0xFF0E0E11)]
                : const [Color(0xFFFFFFFF), Color(0xFFF0F0F4)],
          ),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: AppLogo.black.withValues(alpha: isDark ? 0.4 : 0.07),
              blurRadius: 26,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Oversized step number as a quiet watermark.
            Positioned(
              right: -4,
              bottom: -38,
              child: Text(
                data.step,
                style: TextStyle(
                  fontSize: 150,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -8,
                  color: colors.onSurface.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.9),
                  ),
                ),
                child: Text(
                  '${data.label.toUpperCase()}  •  ${data.step}/03',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface.withValues(alpha: isDark ? 0.35 : 0.7),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.14),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  data.icon,
                  size: 46,
                  color: colors.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.onSurface.withValues(alpha: 0.06),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.16)),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: colors.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('light', 'Light', Icons.light_mode_rounded),
    ('dark', 'Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.resolvesDark(mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose appearance',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (value, label, icon) in _options)
              _ThemeChip(
                label: label,
                icon: icon,
                selected: (value == 'dark') == isDark,
                onTap: () => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Monochrome: selection inverts the chip, matching the logo's ink / paper.
    final selectedBg = isDark ? AppLogo.white : AppLogo.black;
    final selectedFg = isDark ? AppLogo.black : AppLogo.white;

    return Material(
      color: selected
          ? selectedBg
          : colors.surface.withValues(alpha: isDark ? 0.5 : 0.75),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? selectedBg
                  : colors.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? selectedFg
                    : colors.onSurface.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? selectedFg : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.count,
    required this.isLast,
    required this.disabled,
    required this.onBack,
    required this.onNext,
  });

  final int page;
  final int count;
  final bool isLast;
  final bool disabled;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final buttonBg = isDark ? AppLogo.white : AppLogo.black;
    final buttonFg = isDark ? AppLogo.black : AppLogo.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 26 : 6,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(
                    alpha: active ? 0.9 : 0.16,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: page == 0 ? 0 : 1,
                child: IgnorePointer(
                  ignoring: page == 0,
                  child: _BackButton(enabled: !disabled, onTap: onBack),
                ),
              ),
              if (page > 0) const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: disabled ? null : onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonFg,
                      disabledBackgroundColor: buttonBg.withValues(alpha: 0.4),
                      disabledForegroundColor: buttonFg.withValues(alpha: 0.7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isLast ? 'Get Started' : 'Continue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: colors.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
