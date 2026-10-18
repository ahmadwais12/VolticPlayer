import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─── Custom Color Tokens ──────────────────────────────────────────────────

/// Semantic color tokens that go beyond Material 3's built-in scheme.
/// Accessed via `Theme.of(context).extension<AppColors>()!`.
class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color warning;
  final Color playerAccent;
  final Color miniPlayerBackground;
  final Color playerOverlay;
  final Color subtitleBackground;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColors({
    required this.success,
    required this.warning,
    required this.playerAccent,
    required this.miniPlayerBackground,
    required this.playerOverlay,
    required this.subtitleBackground,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = AppColors(
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF39C12),
    playerAccent: Color(0xFF4A4A52),
    miniPlayerBackground: Color(0xFFF6F6F8),
    playerOverlay: Color(0xCC000000),
    subtitleBackground: Color(0xCC000000),
    shimmerBase: Color(0xFFE4E4E9),
    shimmerHighlight: Color(0xFFF2F2F5),
  );

  static const dark = AppColors(
    success: Color(0xFF27AE60),
    warning: Color(0xFFE67E22),
    playerAccent: Color(0xFFCFCFD8),
    miniPlayerBackground: Color(0xFF1A1A1E),
    playerOverlay: Color(0xCC000000),
    subtitleBackground: Color(0xCC000000),
    shimmerBase: Color(0xFF26262B),
    shimmerHighlight: Color(0xFF33333A),
  );

  static const oled = AppColors(
    success: Color(0xFF27AE60),
    warning: Color(0xFFE67E22),
    playerAccent: Color(0xFFCFCFD8),
    miniPlayerBackground: Color(0xFF0A0A0A),
    playerOverlay: Color(0xE6000000),
    subtitleBackground: Color(0xE6000000),
    shimmerBase: Color(0xFF1A1A1A),
    shimmerHighlight: Color(0xFF252525),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? playerAccent,
    Color? miniPlayerBackground,
    Color? playerOverlay,
    Color? subtitleBackground,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      playerAccent: playerAccent ?? this.playerAccent,
      miniPlayerBackground: miniPlayerBackground ?? this.miniPlayerBackground,
      playerOverlay: playerOverlay ?? this.playerOverlay,
      subtitleBackground: subtitleBackground ?? this.subtitleBackground,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      playerAccent: Color.lerp(playerAccent, other.playerAccent, t)!,
      miniPlayerBackground: Color.lerp(
        miniPlayerBackground,
        other.miniPlayerBackground,
        t,
      )!,
      playerOverlay: Color.lerp(playerOverlay, other.playerOverlay, t)!,
      subtitleBackground: Color.lerp(
        subtitleBackground,
        other.subtitleBackground,
        t,
      )!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
    );
  }
}

// ─── Theme Builder ────────────────────────────────────────────────────────

/// Central theming for VolticPlayer.
///
/// Material 3, monochrome: the palette comes straight from the logo — pure
/// black ink on white paper in light mode, and the exact inverse in dark mode.
class AppTheme {
  AppTheme._();

  // Brand ink / paper — every accent derives from these two.
  static const Color _ink = Color(0xFF000000);
  static const Color _paper = Color(0xFFFFFFFF);

  // ─── Schemes ──────────────────────────────────────────────────────────

  /// Light: black ink on white paper.
  static ColorScheme _lightScheme() =>
      ColorScheme.fromSeed(
        seedColor: _ink,
        brightness: Brightness.light,
      ).copyWith(
        primary: _ink,
        onPrimary: _paper,
        primaryContainer: const Color(0xFFE6E6EB),
        onPrimaryContainer: const Color(0xFF0B0B0E),
        secondary: const Color(0xFF3E3E45),
        onSecondary: _paper,
        secondaryContainer: const Color(0xFFEDEDF1),
        onSecondaryContainer: const Color(0xFF101013),
        tertiary: const Color(0xFF3E3E45),
        onTertiary: _paper,
        tertiaryContainer: const Color(0xFFEDEDF1),
        onTertiaryContainer: const Color(0xFF101013),
        surface: _paper,
        onSurface: const Color(0xFF0B0B0E),
        surfaceContainerHighest: const Color(0xFFF1F1F5),
        onSurfaceVariant: const Color(0xFF5B5B63),
        outline: const Color(0xFF9A9AA2),
        outlineVariant: const Color(0xFFE4E4E9),
      );

  /// Dark: white ink on near-black — the light scheme inverted.
  static ColorScheme _darkScheme() =>
      ColorScheme.fromSeed(
        seedColor: _ink,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _paper,
        onPrimary: _ink,
        primaryContainer: const Color(0xFF26262B),
        onPrimaryContainer: const Color(0xFFF2F2F6),
        secondary: const Color(0xFFC6C6CF),
        onSecondary: const Color(0xFF1A1A1E),
        secondaryContainer: const Color(0xFF26262B),
        onSecondaryContainer: const Color(0xFFEDEDF1),
        tertiary: const Color(0xFFC6C6CF),
        onTertiary: const Color(0xFF1A1A1E),
        tertiaryContainer: const Color(0xFF26262B),
        onTertiaryContainer: const Color(0xFFEDEDF1),
        surface: const Color(0xFF101013),
        onSurface: const Color(0xFFF3F3F6),
        surfaceContainerHighest: const Color(0xFF1E1E22),
        onSurfaceVariant: const Color(0xFFA9A9B2),
        outline: const Color(0xFF6E6E77),
        outlineVariant: const Color(0xFF2C2C31),
      );

  // ─── Light Theme ──────────────────────────────────────────────────────

  static ThemeData light() {
    return _build(
      colorScheme: _lightScheme(),
      brightness: Brightness.light,
      scaffoldBg: const Color(0xFFF6F6F8),
      cardColor: _paper,
      appBarBg: _paper,
      dividerColor: const Color(0xFFE4E4E9),
      appColors: AppColors.light,
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────

  static ThemeData dark() {
    return _build(
      colorScheme: _darkScheme(),
      brightness: Brightness.dark,
      scaffoldBg: const Color(0xFF101013),
      cardColor: const Color(0xFF1A1A1E),
      appBarBg: const Color(0xFF131316),
      dividerColor: const Color(0xFF26262B),
      appColors: AppColors.dark,
    );
  }

  // ─── OLED Theme ───────────────────────────────────────────────────────

  static ThemeData oled() {
    return _build(
      colorScheme: _darkScheme(),
      brightness: Brightness.dark,
      scaffoldBg: Colors.black,
      cardColor: const Color(0xFF0A0A0A),
      appBarBg: const Color(0xFF0A0A0A),
      dividerColor: const Color(0xFF1A1A1A),
      appColors: AppColors.oled,
    );
  }

  // ─── Shared Builder ──────────────────────────────────────────────────

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required Color scaffoldBg,
    required Color cardColor,
    required Color appBarBg,
    required Color dividerColor,
    required AppColors appColors,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      extensions: [appColors],

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // ── Cards ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      // ── Navigation Bar ──────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ── Navigation Rail (tablet) ────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      // Filled tonal button (not available in this Flutter version)
      // Using elevatedButtonTheme as fallback
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // ── Chips ───────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),

      // ── ListTile ────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),

      // ── Switch ──────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return isDark ? Colors.grey.shade400 : Colors.grey.shade50;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? Colors.grey.shade700 : Colors.grey.shade300;
        }),
      ),

      // ── Slider ──────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.2),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.1),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),

      // ── Dialog ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Bottom Sheet ────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── SnackBar ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2C2C2C)
            : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Divider ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0.5,
      ),

      // ── Progress Indicator ──────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  static ThemeMode themeModeFromName(String name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'oled':
        return ThemeMode.dark; // OLED uses dark + flag
      default:
        return ThemeMode.system;
    }
  }

  static bool isOled(String name) => name == 'oled';

  static String currentPlatformBrightnessName() {
    final platform =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return platform == Brightness.dark ? 'dark' : 'light';
  }

  /// Whether [name] currently renders dark. `system` follows the device, which
  /// keeps the Light / Dark chooser highlighting the right option for installs
  /// still on the old default.
  static bool resolvesDark(String name) {
    switch (name) {
      case 'light':
        return false;
      case 'dark':
      case 'oled':
        return true;
      default:
        return currentPlatformBrightnessName() == 'dark';
    }
  }

  /// Convenience to get AppColors from context.
  static AppColors appColors(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;
}
