import 'package:flutter/material.dart';

/// Success state shown when a transfer finished (prompt §7 / §21):
/// progress bar reaches 100% on the previous card, then this card's
/// success icon scales/fades in.
class DownloadCompletedCard extends StatefulWidget {
  const DownloadCompletedCard({
    super.key,
    required this.fileName,
    required this.onPlay,
    required this.onDownloadMore,
    this.onOpenFolder,
  });

  final String? fileName;
  final VoidCallback? onPlay;
  final VoidCallback onDownloadMore;
  final VoidCallback? onOpenFolder;

  @override
  State<DownloadCompletedCard> createState() => _DownloadCompletedCardState();
}

class _DownloadCompletedCardState extends State<DownloadCompletedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ScaleTransition(
              scale: reduced ? const AlwaysStoppedAnimation(1) : scale,
              child: FadeTransition(
                opacity: reduced
                    ? const AlwaysStoppedAnimation(1)
                    : _controller,
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Completed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.fileName != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.fileName!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (widget.onPlay != null)
                  FilledButton.tonal(
                    onPressed: widget.onPlay,
                    child: const Text('Play Now'),
                  ),
                FilledButton.tonal(
                  onPressed: widget.onDownloadMore,
                  child: const Text('Download More'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
