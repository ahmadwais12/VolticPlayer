import 'package:flutter/material.dart';

/// Subtle entrance animation used across the downloader screens
/// (prompt §21): fades in while sliding up a few pixels.
///
/// Animations are skipped entirely when the platform reports reduced
/// motion (`prefers-reduced-motion`, prompt §29).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Fraction of the child size to travel from; `Offset(0, 0.06)` ≈ slide-up.
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // The stagger [delay] is modeled as the start of an interval inside a
    // single controller run — no timers, so nothing leaks into test zones.
    final totalMs = widget.delay.inMilliseconds + widget.duration.inMilliseconds;
    final startMs = widget.delay.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs == 0 ? 1 : totalMs),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: startMs == 0
          ? Curves.easeOutCubic
          : Interval(
              startMs / totalMs,
              1,
              curve: Curves.easeOutCubic,
            ),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide =
        Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(curve);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced-motion preferences: show content immediately.
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
