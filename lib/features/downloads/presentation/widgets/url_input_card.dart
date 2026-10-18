import 'package:flutter/material.dart';

import 'fade_slide_in.dart';

/// URL input with paste/clear controls and the primary
/// "Analyze URL" action (prompt §1 / §20).
class UrlInputCard extends StatelessWidget {
  const UrlInputCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onAnalyze,
    required this.onPaste,
    required this.onClear,
    required this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.analyzing = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAnalyze;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool analyzing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 12),
              Semantics(
                label: 'Media URL input',
                textField: true,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Enter video or audio URL here',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            tooltip: 'Clear URL',
                            onPressed: enabled ? onClear : null,
                          ),
                        IconButton(
                          icon: const Icon(Icons.content_paste, size: 20),
                          onPressed: enabled ? onPaste : null,
                          tooltip: 'Paste from clipboard',
                        ),
                      ],
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  enabled: enabled,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: enabled && !analyzing ? onAnalyze : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: analyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    analyzing ? 'Analyzing...' : 'Download',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
