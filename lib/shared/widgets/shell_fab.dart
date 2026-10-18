import 'package:flutter/material.dart';

/// Wraps a page [FloatingActionButton] so it stays visibly above the shell
/// bottom navigation after layout insets are applied.
class ShellFab extends StatelessWidget {
  const ShellFab({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
}
