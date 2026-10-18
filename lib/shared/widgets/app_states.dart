import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Thin wrappers around [UIHelper] state builders so screens can use them as
/// widgets: `<EmptyState message="..." />` instead of repeating boilerplate.
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.video_library_outlined,
  });

  @override
  Widget build(BuildContext context) => UIHelper.emptyState(
    context: context,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    icon: icon,
  );
}

class ErrorState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ErrorState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => UIHelper.errorState(
    context: context,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) => UIHelper.loadingState(message: message);
}

/// Quiet placeholder for library pages while their local database query runs.
/// It avoids a full-screen spinner on each app launch.
class LibraryLoadingState extends StatelessWidget {
  final String title;
  final IconData icon;

  const LibraryLoadingState({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget block({double height = 76}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 18),
        block(height: 82),
        const SizedBox(height: 12),
        block(),
        const SizedBox(height: 12),
        block(),
        const SizedBox(height: 12),
        block(),
      ],
    );
  }
}
