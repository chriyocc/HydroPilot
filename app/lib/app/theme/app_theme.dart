import 'package:flutter/material.dart';
import 'package:home_fi/app/theme/color_theme.dart';

enum AppTheme {
  hydroLight,
}

final appThemeData = {
  AppTheme.hydroLight: ThemeData(
    brightness: Brightness.light,
    primaryColor: GFTheme.primaryGreen,
    scaffoldBackgroundColor: GFTheme.background,
    cardColor: GFTheme.surface,
    dividerColor: GFTheme.border,
    colorScheme: const ColorScheme.light(
      primary: GFTheme.primaryGreen,
      onPrimary: Colors.white,
      surface: GFTheme.surface,
      onSurface: GFTheme.slate900,
      onSurfaceVariant: GFTheme.slate700,
      primaryContainer: GFTheme.primaryGreenSoft,
      onPrimaryContainer: GFTheme.primaryGreen,
      outline: GFTheme.border,
      outlineVariant: GFTheme.surfaceMuted,
      secondary: GFTheme.success,
      tertiary: GFTheme.warning,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GFTheme.background,
      elevation: 0,
      foregroundColor: GFTheme.slate900,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: GFTheme.surface,
      selectedItemColor: GFTheme.primaryGreen,
      unselectedItemColor: GFTheme.slate500,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GFTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GFTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GFTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GFTheme.primaryGreen, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GFTheme.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
};
