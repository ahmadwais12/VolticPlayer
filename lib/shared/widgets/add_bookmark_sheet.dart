import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Bottom sheet for adding a bookmark at the current playback position.
class AddBookmarkSheet extends StatefulWidget {
  final Duration currentPosition;
  final ValueChanged<String?> onConfirm;

  const AddBookmarkSheet({
    super.key,
    required this.currentPosition,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Duration currentPosition,
    required ValueChanged<String?> onConfirm,
  }) {
    return UIHelper.showAppBottomSheet(
      context,
      title: 'Add Bookmark',
      child: AddBookmarkSheet(
        currentPosition: currentPosition,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<AddBookmarkSheet> createState() => _AddBookmarkSheetState();
}

class _AddBookmarkSheetState extends State<AddBookmarkSheet> {
  late final TextEditingController _controller;

  String get _positionFormatted {
    final h = widget.currentPosition.inHours;
    final m = widget.currentPosition.inMinutes.remainder(60);
    final s = widget.currentPosition.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Position display
        Container(
          padding: const EdgeInsets.all(UIHelper.spaceMD),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(UIHelper.radiusSM),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmark, color: theme.colorScheme.primary),
              UIHelper.hSM,
              Text(
                'Position: $_positionFormatted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        UIHelper.vMD,

        // Title input
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Bookmark title (optional)',
            hintText: 'e.g. Important scene',
          ),
          autofocus: true,
        ),
        UIHelper.vMD,

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final title = _controller.text.trim();
              widget.onConfirm(title.isEmpty ? null : title);
              Navigator.pop(context);
            },
            child: const Text('Save Bookmark'),
          ),
        ),
      ],
    );
  }
}
