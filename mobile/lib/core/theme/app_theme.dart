// app_theme.dart — Aliases de compatibilidade para ReadLog Design System.
// Mapeia as cores do legado (AppColors.*) para os tokens atuais de LumenColors,
// garantindo que todas as telas existentes continuem compilando sem alteração.

import 'package:flutter/material.dart';
import '../../theme/lumen_theme.dart';

export '../../theme/lumen_theme.dart';

class AppColors {
  AppColors._();

  // ── Primárias ──────────────────────────────────────────────────────────────
  static const forestGreen      = LumenColors.read;
  static const forestGreenLight = LumenColors.readLight;
  static const warmGold         = LumenColors.warning;
  static const warmGoldLight    = Color(0xFFB8843A); // warm gold light

  // ── Superfícies ────────────────────────────────────────────────────────────
  static const offWhite       = LumenColors.surface;
  static const surface        = LumenColors.surface;
  static const surfaceVariant = LumenColors.surfaceVariant;
  static const border         = LumenColors.surfaceSubtle;

  // ── Texto ──────────────────────────────────────────────────────────────────
  static const textPrimary   = LumenColors.ink;
  static const textSecondary = Color(0xFF5C5C4A);
  static const textMuted     = LumenColors.inkMuted;

  // ── Estados ────────────────────────────────────────────────────────────────
  static const success = LumenColors.success;
  static const error   = LumenColors.danger;
  static const warning = LumenColors.warning;

  // ── Dark ───────────────────────────────────────────────────────────────────
  static const darkBackground    = LumenColors.canvas;
  static const darkSurface       = LumenColors.canvasVariant;
  static const darkSurfaceVariant = Color(0xFF243B2D);
  static const darkBorder        = Color(0xFF2E4A38);
  static const darkTextPrimary   = LumenColors.inkInverse;
  static const darkTextSecondary = LumenColors.readLight;
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

/// AppTheme mantido para compatibilidade — internamente usa LumenTheme.
class AppTheme {
  static ThemeData get light => LumenTheme.light();
  static ThemeData get dark  => LumenTheme.dark();
}
