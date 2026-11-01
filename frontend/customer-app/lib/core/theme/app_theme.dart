import 'package:flutter/material.dart';

/// Legacy static palette (light-mode values only).
///
/// Kept only so [AppTheme.lightTheme]/[AppTheme.darkTheme] have concrete
/// literals to build from. Do NOT reference [AppPalette] directly from
/// widgets — those values never change with brightness, which is exactly
/// what caused screens to stay visually "light" (or half-light/half-dark)
/// when the app switched to dark mode.
///
/// Widgets should read colors through `context.colors` (see [AppColors]
/// below), which resolves to the correct value for the active theme.
class AppPalette {
  static const Color background = Color(0xFFF8F9FE);
  static const Color foreground = Color(0xFF1A1A2E);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFFFF6B6B);
  static const Color secondary = Color(0xFF6C63FF);
  static const Color muted = Color(0xFFF0F1F8);
  static const Color mutedForeground = Color(0xFF9095A0);
  static const Color border = Color(0xFFE8EAEF);
  static const Color success = Color(0xFF22C55E);
  static const Color destructive = Color(0xFFEF4444);
  static const Color star = Color(0xFFFFB800);
}

/// Theme-aware palette. This is the single source of truth every screen
/// and widget should use for colors that must flip between light and dark.
///
/// Every field that used to live only in [AppPalette] (and therefore was
/// frozen at its light-mode value) now has an explicit, deliberately chosen
/// dark-mode counterpart here, so nothing falls back to a light color (or
/// disappears) when the app is in dark mode.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.success,
    required this.destructive,
    required this.star,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color success;
  final Color destructive;
  final Color star;

  static const light = AppColors(
    background: AppPalette.background,
    foreground: AppPalette.foreground,
    card: AppPalette.card,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    secondary: AppPalette.secondary,
    onSecondary: Colors.white,
    muted: AppPalette.muted,
    mutedForeground: AppPalette.mutedForeground,
    border: AppPalette.border,
    success: AppPalette.success,
    destructive: AppPalette.destructive,
    star: AppPalette.star,
  );

  static const dark = AppColors(
    background: Color(0xFF0F101A),
    foreground: Color(0xFFF4F5FA),
    card: Color(0xFF171827),
    primary: Color(0xFFFF8585),
    onPrimary: Color(0xFF321010),
    secondary: Color(0xFF9B94FF),
    onSecondary: Color(0xFF17152F),
    muted: Color(0xFF20222F),
    mutedForeground: Color(0xFF9296A8),
    border: Color(0xFF2D3045),
    success: Color(0xFF4ADE80),
    destructive: Color(0xFFFF8A8A),
    star: Color(0xFFFFC94D),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? muted,
    Color? mutedForeground,
    Color? border,
    Color? success,
    Color? destructive,
    Color? star,
  }) {
    return AppColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
      success: success ?? this.success,
      destructive: destructive ?? this.destructive,
      star: star ?? this.star,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      star: Color.lerp(star, other.star, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.primary`, `context.colors.card`, ...
/// Always resolves to the palette that matches the currently active theme.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      secondary: AppPalette.secondary,
      onSecondary: Colors.white,
      error: AppPalette.destructive,
      onError: Colors.white,
      surface: AppPalette.card,
      onSurface: AppPalette.foreground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [AppColors.light],
      scaffoldBackgroundColor: AppPalette.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.foreground,
          side: const BorderSide(color: AppPalette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.muted,
        labelStyle: const TextStyle(color: AppPalette.foreground),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFF8585),
      onPrimary: Color(0xFF321010),
      secondary: Color(0xFF9B94FF),
      onSecondary: Color(0xFF17152F),
      error: Color(0xFFFF8A8A),
      onError: Color(0xFF3A0808),
      surface: Color(0xFF171827),
      onSurface: Color(0xFFF4F5FA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: const [AppColors.dark],
      scaffoldBackgroundColor: const Color(0xFF0F101A),
      canvasColor: const Color(0xFF0F101A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F101A),
        foregroundColor: Color(0xFFF4F5FA),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF171827),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D1F31),
        hintStyle: const TextStyle(color: Color(0xFF9296A8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D3045)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D3045)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF8585), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8585),
          foregroundColor: const Color(0xFF321010),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF4F5FA),
          side: const BorderSide(color: Color(0xFF373A51)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2D3045),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF24263A),
        labelStyle: const TextStyle(color: Color(0xFFF4F5FA)),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF171827),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
