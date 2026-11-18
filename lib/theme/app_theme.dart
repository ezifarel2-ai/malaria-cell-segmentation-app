import 'package:flutter/material.dart';

/// Strict design tokens and theme definition for MalariaVision Lab.
/// Follows modern laboratory & scientific precision aesthetics (Leica / Apple Health / Linear).
class AppTheme {
  AppTheme._();

  // Surface & Canvas Colors
  static const Color bgCanvas = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardElevated = Color(0xFFFAFAFA);

  // Primary Medical Brand Accents
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealDark = Color(0xFF115E59);
  static const Color primaryTealLight = Color(0xFFF0FDFA);
  static const Color primaryTealBorder = Color(0xFF0D9488);

  // Hairline Borders & Dividers (Strict 1px, NO heavy drop shadows)
  static const Color borderHairline = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFCBD5E1);

  // Typography Palette
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  // Semantic Status Tokens
  static const Color statusParasitized = Color(0xFFDC2626);
  static const Color statusParasitizedBg = Color(0xFFFEF2F2);
  static const Color statusParasitizedBorder = Color(0xFFFECACA);

  static const Color statusUninfected = Color(0xFF059669);
  static const Color statusUninfectedBg = Color(0xFFECFDF5);
  static const Color statusUninfectedBorder = Color(0xFFA7F3D0);

  // Scientific Warning / Caution Tokens
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberBg = Color(0xFFFFFBEB);
  static const Color warningAmberBorder = Color(0xFFFDE68A);

  // Microscopic Viewport Background
  static const Color viewportBg = Color(0xFF090D16);
  static const Color maskForeground = Color(0xFFFFFFFF);

  // Tabular Number & Scientific Typography Styles
  static const List<FontFeature> tabularFeature = [FontFeature.tabularFigures()];

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: textMuted,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle metricLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFeatures: tabularFeature,
  );

  static const TextStyle tabularMono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFeatures: tabularFeature,
    color: textPrimary,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgCanvas,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        onPrimary: Colors.white,
        surface: cardSurface,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderHairline, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderHairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: titleLarge,
      ),
    );
  }
}
