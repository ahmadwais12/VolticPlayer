import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// A bottom sheet for entering a network media URL to play.
///
/// Supports optional headers configuration. Used from the home screen
/// or settings to open network streams.
class UrlInputSheet extends StatefulWidget {
  final ValueChanged<String> onPlay;

  const UrlInputSheet({super.key, required this.onPlay});

  /// Convenience method to show and return the entered URL.
  static Future<String?> show(BuildContext context) {
    String? result;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIHelper.radiusLG),
        ),
      ),
      builder: (_) => UrlInputSheet(
        onPlay: (url) {
          result = url;
          Navigator.pop(context);
        },
      ),
    ).then((_) => result);
  }

  @override
  State<UrlInputSheet> createState() => _UrlInputSheetState();
}

class _UrlInputSheetState extends State<UrlInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UIHelper.vSM,
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            UIHelper.vSM,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceMD),
              child: Text(
                'Open Network Stream',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            UIHelper.vMD,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceMD),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://example.com/video.m3u8',
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder(),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UIHelper.spaceMD),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : () => _submit(_controller.text.trim()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onPlay(value.trim());
  }
}
