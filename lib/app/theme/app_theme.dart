/// All app colors and typography in one place.
/// Change accent/heading colors here and the entire app updates.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Brand colors
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Accent (teal)
  static const Color accent = Color(0xFF1F7A6D);
  static const Color accentLight = Color(0xFF2A9D8E);
  static const Color accentDark = Color(0xFF155E53);

  // Headings (navy)
  static const Color heading = Color(0xFF12304A);
  static const Color headingLight = Color(0xFF1A4A6E);

  // Neutrals
  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF2F7);
  static const Color inputFill = Color(0xFFF7FAFC);

  // Text
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFF718096);

  // Status labels
  static const Color paid = Color(0xFF38A169);
  static const Color paidBg = Color(0xFFE6F4EC);
  static const Color pending = Color(0xFFD69E2E);
  static const Color pendingBg = Color(0xFFFFF8E1);
  static const Color overdue = Color(0xFFE53E3E);
  static const Color overdueBg = Color(0xFFFEE2E2);
  static const Color partial = Color(0xFF3182CE);
  static const Color partialBg = Color(0xFFEBF8FF);

  // Dark theme
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

// ---------------------------------------------------------------------------
// Light theme
// ---------------------------------------------------------------------------

ThemeData buildLightTheme() {
  const fontFamily = 'Nunito';

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentLight,
      background: AppColors.background,
      surface: AppColors.surface,
      onBackground: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.heading,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.heading,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.overdue),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      dataTextStyle: const TextStyle(
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      headingRowColor: WidgetStateProperty.all(AppColors.inputFill),
      dividerThickness: 1,
    ),
  );
}

// ---------------------------------------------------------------------------
// Dark theme
// ---------------------------------------------------------------------------

ThemeData buildDarkTheme() {
  const fontFamily = 'Nunito';

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accentLight,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onBackground: AppColors.darkTextPrimary,
      onSurface: AppColors.darkTextPrimary,
      outline: AppColors.darkBorder,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder, thickness: 1),
  );
}
