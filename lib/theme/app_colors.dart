import 'package:flutter/material.dart';

/// Neutral colours that change between light and dark mode.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.fieldFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.dotInactive,
    required this.border,
    required this.buttonDisabled,
    required this.buttonDisabledText,
    required this.otpBorder,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color fieldFill;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color dotInactive;
  final Color border;
  final Color buttonDisabled;
  final Color buttonDisabledText;
  final Color otpBorder;
}

class AppColors {
  AppColors._();

  static const AppPalette light = AppPalette(
    background: Color(0xFFF2F2F7),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF5F6F8),
    fieldFill: Color(0xFFE8EBF2),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    dotInactive: Color(0xFFD1D5DB),
    border: Color(0xFFE5E7EB),
    buttonDisabled: Color(0xFFC5CEE0),
    buttonDisabledText: Color(0xFF6B7A9A),
    otpBorder: Color(0xFFB8C4E0),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0B1220),
    surface: Color(0xFF151E2E),
    surfaceMuted: Color(0xFF1C2638),
    fieldFill: Color(0xFF1F2A3D),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFA3ADBD),
    textMuted: Color(0xFF7B8698),
    dotInactive: Color(0xFF374151),
    border: Color(0xFF263247),
    buttonDisabled: Color(0xFF26324A),
    buttonDisabledText: Color(0xFF7C89A6),
    otpBorder: Color(0xFF3B4A6B),
  );

  static AppPalette _palette = light;

  static bool get isDark => identical(_palette, dark);

  /// Called by [UserSession] when the theme mode changes; widgets pick
  /// the new colours up on their next build.
  static void setDark(bool value) => _palette = value ? dark : light;

  /// A pastel fill used for chips, icon circles and banners. Light mode
  /// gets it unchanged; dark mode gets the same hue as a muted wash over
  /// [surface] so it doesn't glow. Use a higher [strength] for borders.
  static Color tint(Color light, {double strength = 0.16}) {
    if (!isDark) return light;
    final hsl = HSLColor.fromColor(light);
    final accent = hsl
        .withSaturation(hsl.saturation.clamp(0.0, 0.85))
        .withLightness(0.55)
        .toColor();
    return Color.alphaBlend(accent.withValues(alpha: strength), surface);
  }

  /// A deep accent used as text on a [tint] fill; lifted in dark mode so
  /// it stays readable on the darker fill.
  static Color onTint(Color light) {
    if (!isDark) return light;
    final hsl = HSLColor.fromColor(light);
    return hsl.withLightness(hsl.lightness.clamp(0.75, 1.0)).toColor();
  }

  static const Color primary = Color(0xFF0052FF);
  static const Color primaryDark = Color(0xFF003DB8);
  static const Color primaryGradientEnd = Color(0xFF0039CC);
  static const Color pinDot = Color(0xFF0052FF);

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceMuted => _palette.surfaceMuted;
  static Color get fieldFill => _palette.fieldFill;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get dotInactive => _palette.dotInactive;
  static Color get border => _palette.border;
  static Color get buttonDisabled => _palette.buttonDisabled;
  static Color get buttonDisabledText => _palette.buttonDisabledText;
  static Color get otpBorder => _palette.otpBorder;
}
