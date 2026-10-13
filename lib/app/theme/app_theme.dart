/// All app colors and typography in one place.
/// Change accent/heading colors here and the entire app updates.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Brand colors
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Accent (Royal Navy & Sapphire Blue)
  static const Color accent = Color(0xFF1E40AF); // Royal Blue 800 - dignified, professional
  static const Color accentLight = Color(0xFF3B82F6); // Sapphire Blue 500
  static const Color accentDark = Color(0xFF1E3A8A); // Deep Navy Blue 900

  // Headings (Crisp Slate Navy)
  static const Color heading = Color(0xFF0F172A); // Slate 900 - sharp, premium, crisp
  static const Color headingLight = Color(0xFF1E293B); // Slate 800

  // Neutrals (Light)
  static const Color background = Color(0xFFF8FAFC); // Clean Slate 50 - makes cards pop
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color border = Color(0xFFE2E8F0); // Subtle Slate 200
  static const Color divider = Color(0xFFF1F5F9); // Crisp Slate 100
  static const Color inputFill = Color(0xFFF8FAFC); // Slate 50

  // Text (Light)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Status labels
  static const Color paid = Color(0xFF16A34A); // Emerald Green 600
  static const Color paidBg = Color(0xFFDCFCE7); // Green 100
  static const Color pending = Color(0xFFD97706); // Amber 600
  static const Color pendingBg = Color(0xFFFEF3C7); // Amber 100
  static const Color overdue = Color(0xFFDC2626); // Crimson Red 600
  static const Color overdueBg = Color(0xFFFEE2E2); // Red 100
  static const Color partial = Color(0xFF0284C7); // Sky Blue 600
  static const Color partialBg = Color(0xFFE0F2FE); // Sky 100

  // Dark theme colors (Clean Slate Dark)
  static const Color darkBackground = Color(0xFF0B1120); // Deepest slate navy
  static const Color darkSurface = Color(0xFF1E293B); // Elevated slate navy card
  static const Color darkCardSub = Color(0xFF0F172A); // Recessed inner container
  static const Color darkBorder = Color(0xFF334155); // Slate 700 border
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  // Dynamic theme-aware helpers
  static Color pageBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : background;

  static Color cardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color subCardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardSub : inputFill;

  static Color borderCol(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;

  static Color headingCol(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : heading;

  static Color textPrimaryCol(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color textSecondaryCol(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color textMutedCol(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textMuted;
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
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
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
    cardColor: AppColors.surface,
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
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
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
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accentLight,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      outline: AppColors.darkBorder,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardColor: AppColors.darkSurface,
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        color: AppColors.darkTextPrimary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCardSub,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.accentLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.overdue),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
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
        foregroundColor: AppColors.accentLight,
        side: const BorderSide(color: AppColors.darkBorder),
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
        foregroundColor: AppColors.accentLight,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder, thickness: 1),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextSecondary,
        fontSize: 13,
      ),
      dataTextStyle: const TextStyle(
        fontFamily: fontFamily,
        color: AppColors.darkTextPrimary,
        fontSize: 14,
      ),
      headingRowColor: WidgetStateProperty.all(AppColors.darkCardSub),
      dividerThickness: 1,
    ),
  );
}
