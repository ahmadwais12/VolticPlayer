import 'package:flutter/material.dart';

/// Accessibility helpers matching requirements doc §120.
/// Supports TalkBack, VoiceOver, large text, high contrast,
/// semantic labels, screen reader descriptions, keyboard navigation,
/// minimum touch targets.
class AccessibilityHelper {
  AccessibilityHelper._();

  /// Minimum touch target size per Material Design guidelines (48x48).
  static const double minTouchTarget = 48.0;

  /// Wrap a widget with minimum touch target sizing.
  static Widget ensureMinTouchTarget({
    required Widget child,
    required VoidCallback? onTap,
    String? semanticLabel,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: excludeSemantics,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTouchTarget,
            minHeight: minTouchTarget,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Create a semantic label for media items.
  static String mediaItemLabel({
    required String name,
    String? artist,
    String? duration,
    required bool isVideo,
  }) {
    final parts = <String>[
      isVideo ? 'Video' : 'Audio',
      name,
      if (artist != null) 'by $artist',
      if (duration != null) duration,
    ];
    return parts.join(', ');
  }

  /// Create a semantic label for player controls.
  static String playerControlLabel({
    required bool isPlaying,
    String? title,
  }) {
    if (title != null) {
      return isPlaying ? 'Pause $title' : 'Play $title';
    }
    return isPlaying ? 'Pause' : 'Play';
  }

  /// Check if the current text scale factor is large.
  static bool isLargeText(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context);
    return textScale.scale(14) > 18;
  }

  /// Check if high contrast mode is active.
  static bool isHighContrast(BuildContext context) {
    return MediaQuery.highContrastOf(context);
  }

  /// Get accessible color that meets contrast requirements.
  static Color accessibleColor({
    required Color background,
    required Color foreground,
    required Color fallback,
  }) {
    final ratio = _contrastRatio(background, foreground);
    if (ratio >= 4.5) return foreground;
    return fallback;
  }

  /// Calculate contrast ratio between two colors.
  static double _contrastRatio(Color a, Color b) {
    final l1 = _relativeLuminance(a);
    final l2 = _relativeLuminance(b);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color color) {
    final r = color.r / 255;
    final g = color.g / 255;
    final b = color.b / 255;
    final rs = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) * 2.4;
    final gs = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) * 2.4;
    final bs = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) * 2.4;
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }
}
