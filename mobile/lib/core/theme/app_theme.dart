// app_theme.dart — Aliases de compatibilidade para ReadLog Design System.
// Mapeia as cores do legado (AppColors.*) para os tokens atuais de ReadLogColors,
// garantindo que todas as telas existentes continuem compilando sem alteração.

import 'package:flutter/material.dart';
import '../../theme/readlog_theme.dart';

export '../../theme/readlog_theme.dart';

class AppColors {
  AppColors._();

  // ── Primárias ──────────────────────────────────────────────────────────────
  static const forestGreen = ReadLogColors.ink;
  static const forestGreenLight = ReadLogColors.inkAlt;
  static const warmGold = ReadLogColors.brass;
  static const warmGoldLight = ReadLogColors.brassLight;

  // ── Superfícies ────────────────────────────────────────────────────────────
  static const offWhite = ReadLogColors.paper;
  static const surface = ReadLogColors.cream;
  static const surfaceVariant = ReadLogColors.paperAlt;
  static const border = ReadLogColors.paperDeep;

  // ── Texto ──────────────────────────────────────────────────────────────────
  static const textPrimary = ReadLogColors.charcoal;
  static const textSecondary = Color(0xFF5C5C4A); // tom compatível com charcoal
  static const textMuted = Color(0xFF9C9C8A);

  // ── Estados ────────────────────────────────────────────────────────────────
  static const success = ReadLogColors.sage;
  static const error = ReadLogColors.stamp;
  static const warning = ReadLogColors.brass;

  // ── Dark ───────────────────────────────────────────────────────────────────
  static const darkBackground = ReadLogColors.ink;
  static const darkSurface = ReadLogColors.inkAlt;
  static const darkSurfaceVariant = Color(0xFF243B2D);
  static const darkBorder = Color(0xFF2E4A38);
  static const darkTextPrimary = ReadLogColors.cream;
  static const darkTextSecondary = ReadLogColors.brassLight;
}

class AppTextStyles {
  AppTextStyles._();

  static const String _displayFont = 'Fraunces';
  static const String _bodyFont = 'IBM Plex Mono';

  static const displayLarge = TextStyle(
    fontFamily: _displayFont,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const displayMedium = TextStyle(
    fontFamily: _displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const headlineMedium = TextStyle(
    fontFamily: _displayFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const labelMedium = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );
}

/// AppTheme mantido para compatibilidade — internamente usa ReadLogTheme.
class AppTheme {
  static ThemeData get light => ReadLogTheme.light();
  static ThemeData get dark => ReadLogTheme.dark();
}
