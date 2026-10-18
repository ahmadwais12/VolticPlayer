import 'package:flutter/material.dart';

/// Skeleton shown while media metadata is being retrieved (prompt §6).
class MediaSkeletonLoader extends StatefulWidget {
  const MediaSkeletonLoader({super.key});

  @override
  State<MediaSkeletonLoader> createState() => _MediaSkeletonLoaderState();
}

class _MediaSkeletonLoaderState extends State<MediaSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) _controller.stop();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Box(width: 112, height: 72, color: base, animation: reduced ? null : _controller),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Box(
                        height: 16,
                        width: double.infinity,
                        color: base,
                        animation: reduced ? null : _controller,
                      ),
                      const SizedBox(height: 10),
                      _Box(
                        height: 12,
                        width: 140,
                        color: base,
                        animation: reduced ? null : _controller,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (!reduced)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 10),
                Text(
                  'Analyzing media information...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.height,
    required this.width,
    required this.color,
    required this.animation,
  });

  final double height;
  final double width;
  final Color color;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    if (animation == null) return box;
    return FadeTransition(opacity: animation!, child: box);
  }
}
