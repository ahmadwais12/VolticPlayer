import 'package:flutter/material.dart';

/// A semi-transparent overlay showing a buffering indicator.
///
/// Used inside player screens when media is buffering.
class BufferingIndicator extends StatelessWidget {
  final bool visible;
  final String? message;

  const BufferingIndicator({
    super.key,
    this.visible = true,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
