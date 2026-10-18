import 'package:flutter/material.dart';

/// Central design system for VolticPlayer.
///
/// Every screen must build its layout using the tokens and helper methods
/// exposed here so the visual language stays identical across the app.
/// Do NOT hard-code margins, radii, paddings or card styling in widgets.
class UIHelper {
  UIHelper._();

  // ---------------------------------------------------------------------------
  // Spacing scale (use these everywhere instead of raw numbers)
  // ---------------------------------------------------------------------------
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // ---------------------------------------------------------------------------
  // Corner radius
  // ---------------------------------------------------------------------------
  static const double radiusXS = 6.0;
  static const double radiusSM = 10.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 24.0;
  static const double radiusXL = 32.0;
  static const double radiusCircular = 999.0;

  // ---------------------------------------------------------------------------
  // Standard insets
  // ---------------------------------------------------------------------------
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD);
  static const EdgeInsets cardPadding = EdgeInsets.all(spaceMD);
  static const EdgeInsets listPadding =
      EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM);

  // ---------------------------------------------------------------------------
  // Elevation / shadows (theme-aware via [card])
  // ---------------------------------------------------------------------------
  static const double elevationSM = 2.0;
  static const double elevationMD = 6.0;

  // ---------------------------------------------------------------------------
  // Icon / avatar sizes
  // ---------------------------------------------------------------------------
  static const double iconSM = 18.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double avatarSM = 36.0;
  static const double avatarMD = 48.0;
  static const double avatarLG = 64.0;

  // ---------------------------------------------------------------------------
  // Player-specific constants
  // ---------------------------------------------------------------------------
  static const double playerControlsHeight = 120.0;
  static const double miniPlayerHeight = 64.0;

  // ---------------------------------------------------------------------------
  // Spacers — use instead of SizedBox for consistent rhythm
  // ---------------------------------------------------------------------------
  static SizedBox vSpace(double h) => SizedBox(height: h);
  static SizedBox hSpace(double w) => SizedBox(width: w);

  static const SizedBox vXS = SizedBox(height: spaceXS);
  static const SizedBox vSM = SizedBox(height: spaceSM);
  static const SizedBox vMD = SizedBox(height: spaceMD);
  static const SizedBox vLG = SizedBox(height: spaceLG);
  static const SizedBox vXL = SizedBox(height: spaceXL);
  static const SizedBox hXS = SizedBox(width: spaceXS);
  static const SizedBox hSM = SizedBox(width: spaceSM);
  static const SizedBox hMD = SizedBox(width: spaceMD);
  static const SizedBox hLG = SizedBox(width: spaceLG);
  static const SizedBox hXL = SizedBox(width: spaceXL);

  // ---------------------------------------------------------------------------
  // Responsive helpers
  // ---------------------------------------------------------------------------

  /// Returns the number of grid columns based on screen width.
  static int responsiveColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return switch (width) {
      >= 1200 => 6,
      >= 900 => 5,
      >= 600 => 4,
      >= 400 => 3,
      _ => 2,
    };
  }

  /// True when running on a tablet-sized device (>= 600 shortest side).
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  /// True when running on a wide layout (>= 900 width).
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  /// True when running in landscape mode.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Returns a responsive value based on screen width breakpoints.
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900 && desktop != null) return desktop;
    if (width >= 600 && tablet != null) return tablet;
    return mobile;
  }

  // ---------------------------------------------------------------------------
  // Section header used on every list/grid screen
  // ---------------------------------------------------------------------------
  static Widget sectionTitle(
    BuildContext context, {
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: spaceMD,
        vertical: spaceSM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: spaceSM),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card — consistent surface container for all content tiles
  // ---------------------------------------------------------------------------
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Color? color,
    double radius = radiusMD,
  }) {
    final widget = Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? cardPadding,
        child: child,
      ),
    );
    if (onTap == null && onLongPress == null) return widget;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(radius),
      child: widget,
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state — reused on every screen that can have no data
  // ---------------------------------------------------------------------------
  static Widget emptyState({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = Icons.video_library_outlined,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            vMD,
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            if (actionLabel != null && onAction != null) ...[
              vMD,
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error state — consistent failure presentation
  // ---------------------------------------------------------------------------
  static Widget errorState({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            vMD,
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              vMD,
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.replay),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading state — skeleton/indicator placeholder
  // ---------------------------------------------------------------------------
  static Widget loadingState({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            vMD,
            Text(message, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gradient overlays for player controls
  // ---------------------------------------------------------------------------

  /// Top-to-bottom fade gradient for player top bar.
  static LinearGradient topGradient({
    double opacity = 0.7,
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        Colors.black.withValues(alpha: opacity),
        Colors.transparent,
      ],
    );
  }

  /// Bottom-to-top fade gradient for player bottom controls.
  static LinearGradient bottomGradient({
    double opacity = 0.8,
    Alignment begin = Alignment.bottomCenter,
    Alignment end = Alignment.topCenter,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        Colors.black.withValues(alpha: opacity),
        Colors.transparent,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog / Bottom Sheet builders
  // ---------------------------------------------------------------------------

  /// Shows a consistent bottom sheet with SafeArea wrapping.
  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLG)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            vSM,
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            vSM,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceMD),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            vSM,
            const Divider(height: 1),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }

  /// Shows a consistent confirmation dialog.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a consistent list-option bottom sheet (for single selection).
  static Future<int?> showOptionSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    int selectedIndex = -1,
    Widget Function(int index)? trailingBuilder,
  }) {
    return showAppBottomSheet<int>(
      context,
      title: title,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: options.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(options[i]),
          trailing: trailingBuilder?.call(i) ??
              (selectedIndex == i ? const Icon(Icons.check) : null),
          onTap: () => Navigator.pop(context, i),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Badge / chip helpers
  // ---------------------------------------------------------------------------

  /// Small badge used for track counts, notifications, etc.
  static Widget badge({
    required BuildContext context,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(radiusCircular),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Truncated text with ellipsis (reusable pattern)
  // ---------------------------------------------------------------------------
  static Widget ellipsisText(
    String text, {
    int maxLines = 1,
    TextStyle? style,
    TextAlign? textAlign,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
      textAlign: textAlign,
    );
  }
}
