import 'package:flutter/material.dart';

/// Renders the VolticPlayer logo mark in the black & white identity.
///
/// The artwork is tinted to a flat black and sits on a white plate;
/// [transparent] drops the plate and tints the mark white instead, so it reads
/// on the dark splash / onboarding backdrops.
///
/// Usage:
///   AppLogo(size: 72)
///   AppLogo(size: 36, radius: 8)
///   AppLogo(size: 124, transparent: true)
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.radius,
    this.showShadow = true,
    this.transparent = false,
    this.assetPath,
  });

  final double size;

  /// Corner radius. Defaults to size * 0.22 (matches adaptive icon shape).
  final double? radius;

  final bool showShadow;

  /// True = no white plate; the white mark floats on the backdrop with a soft
  /// glow instead.
  final bool transparent;

  /// Override the asset. Defaults to the consistent transparent mark.
  final String? assetPath;

  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.22;

    final path = assetPath ?? 'assets/logo/logo_mark_transparent.png';
    final markColor = transparent ? white : black;

    final image = Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      color: markColor,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) => Icon(
        Icons.bolt_rounded,
        size: size * 0.55,
        color: markColor,
      ),
    );

    if (transparent) {
      // White mark on a dark backdrop: soft glow behind, no plate.
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: white.withValues(alpha: 0.22),
                    blurRadius: size * 0.42,
                    spreadRadius: -size * 0.06,
                  ),
                ]
              : null,
        ),
        child: image,
      );
    }

    // Black mark on a white plate.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: black.withValues(alpha: 0.08)),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: black.withValues(alpha: 0.22),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.1),
                  spreadRadius: -size * 0.04,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(color: white, child: image),
    );
  }
}
