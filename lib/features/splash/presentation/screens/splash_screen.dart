import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_logo.dart';

/// Cinematic branded splash — brand first, then route to onboarding or home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final AnimationController _exit;

  late final Animation<double> _fadeIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _tagFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fadeIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.05, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _titleSlide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );
    _exitFade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeIn));

    _intro.forward();
    unawaited(_bootAndNavigate());
  }

  Future<void> _bootAndNavigate() async {
    unawaited(() async {
      try {
        await ref.read(permissionServiceProvider).requestNotifications();
      } catch (_) {}
    }());

    await Future.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;

    var showOnboarding = false;
    try {
      showOnboarding = await ref
          .read(settingsRepositoryProvider)
          .isFirstLaunch();
    } catch (_) {
      showOnboarding = false;
    }

    if (!mounted) return;
    await _exit.forward();
    if (!mounted) return;
    context.go(showOnboarding ? AppRouter.onboarding : AppRouter.home);
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: FadeTransition(
        opacity: _exitFade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashBackdrop(),
            FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PulseRingsPainter(progress: _pulse.value),
                    size: size,
                  );
                },
              ),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  return Column(
                    children: [
                      const Spacer(flex: 3),
                      Transform.scale(
                        scale: _logoScale.value,
                        child: const AppLogo(size: 132, transparent: true),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _tagFade.value,
                        child: Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      Opacity(
                        opacity: _tagFade.value,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF121216),
            Color(0xFF101013),
            Color(0xFF0C0C0F),
            Color(0xFF070709),
          ],
          stops: [0, 0.35, 0.72, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 0.95,
                colors: [Color(0x1FFFFFFF), Color(0x00000000)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, 0.9),
                radius: 0.7,
                colors: [Color(0x14FFFFFF), Color(0x00000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = 78 + t * 96;
      paint.color = Colors.white.withValues(alpha: (1 - t) * 0.22);
      canvas.drawCircle(center, radius, paint);
    }

    // Soft orbiting accent dot
    final angle = progress * math.pi * 2;
    final orbit = Offset(
      center.dx + math.cos(angle) * 78,
      center.dy + math.sin(angle) * 78,
    );
    canvas.drawCircle(
      orbit,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
