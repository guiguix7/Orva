import 'package:flutter/material.dart';

abstract final class OrvaColors {
  static const canvas = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF2EDE5);
  static const border = Color(0xFFE8E2D8);
  static const borderStrong = Color(0xFFD6CFC1);
  static const text = Color(0xFF2B2A28);
  static const secondaryText = Color(0xFF6B6862);
  static const tertiaryText = Color(0xFF9C9790);
  static const primary = Color(0xFF2F5D57);
  static const primary900 = Color(0xFF16312E);
  static const primary500 = Color(0xFF4A857E);
  static const primary300 = Color(0xFF8FB8B2);
  static const primary100 = Color(0xFFDCEAE7);
  static const primary50 = Color(0xFFEFF6F4);
  static const terracotta = Color(0xFFC97B5A);
  static const terracottaLight = Color(0xFFF6E3D8);
  static const mustard = Color(0xFFE0A93B);
  static const accent100 = Color(0xFFFBF0D2);
  static const success = Color(0xFF4A9E6E);
  static const error = Color(0xFFC25A4E);
  static const information = Color(0xFF4A7A9E);

  static const darkCanvas = Color(0xFF1A1815);
  static const darkSurface = Color(0xFF242220);
  static const darkSubtle = Color(0xFF2E2B28);
  static const darkBorder = Color(0xFF3A3633);
  static const darkText = Color(0xFFF0EBE3);
  static const darkSecondary = Color(0xFFA8A29A);
  static const darkPrimary = Color(0xFF7FB8B1);
}

ThemeData buildOrvaLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OrvaColors.primary,
    brightness: Brightness.light,
    surface: OrvaColors.surface,
    primary: OrvaColors.primary,
    error: OrvaColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OrvaColors.canvas,
    dividerColor: OrvaColors.border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: OrvaColors.canvas,
      foregroundColor: OrvaColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: OrvaColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OrvaColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrvaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.error)),
      labelStyle: const TextStyle(color: OrvaColors.secondaryText),
      hintStyle: const TextStyle(color: OrvaColors.tertiaryText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: OrvaColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OrvaColors.primary,
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: OrvaColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 36, height: 1.12, fontWeight: FontWeight.w600, color: OrvaColors.text, letterSpacing: -1.2, fontFamily: 'serif'),
      headlineMedium: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w600, color: OrvaColors.text, letterSpacing: -0.6, fontFamily: 'serif'),
      titleLarge: TextStyle(fontSize: 22, height: 1.28, fontWeight: FontWeight.w600, color: OrvaColors.text, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, color: OrvaColors.text),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: OrvaColors.text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: OrvaColors.secondaryText),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: OrvaColors.secondaryText),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: OrvaColors.surface,
      indicatorColor: OrvaColors.primary100,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontSize: 12, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    visualDensity: VisualDensity.standard,
  );
}

ThemeData buildOrvaDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OrvaColors.darkPrimary,
    brightness: Brightness.dark,
    surface: OrvaColors.darkSurface,
    primary: OrvaColors.darkPrimary,
    error: const Color(0xFFE28B81),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OrvaColors.darkCanvas,
    dividerColor: OrvaColors.darkBorder,
    appBarTheme: const AppBarTheme(backgroundColor: OrvaColors.darkCanvas, foregroundColor: OrvaColors.darkText, elevation: 0, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      color: OrvaColors.darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: OrvaColors.darkBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrvaColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.darkBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.darkBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: OrvaColors.darkPrimary, width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: OrvaColors.darkPrimary, foregroundColor: OrvaColors.primary900, minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 36, height: 1.12, fontWeight: FontWeight.w600, color: OrvaColors.darkText, letterSpacing: -1.2, fontFamily: 'serif'),
      headlineMedium: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w600, color: OrvaColors.darkText, letterSpacing: -0.6, fontFamily: 'serif'),
      titleLarge: TextStyle(fontSize: 22, height: 1.28, fontWeight: FontWeight.w600, color: OrvaColors.darkText),
      titleMedium: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, color: OrvaColors.darkText),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: OrvaColors.darkText),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: OrvaColors.darkSecondary),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: OrvaColors.darkSecondary),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: OrvaColors.darkSurface, indicatorColor: Color(0xFF334742), elevation: 0, height: 72),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
