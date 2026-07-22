import 'package:flutter/material.dart';

class AppColors {
  static const forestGreen = Color(0xFF1E3A2F);
  static const forestGreenLight = Color(0xFF2D5442);
  static const warmGold = Color(0xFFB8860B);
  static const warmGoldLight = Color(0xFFD4A017);

  static const offWhite = Color(0xFFF4F3F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEFEEEB);
  static const border = Color(0xFFDDDCDA);

  static const textPrimary = Color(0xFF1A1A18);
  static const textSecondary = Color(0xFF5C5C58);
  static const textMuted = Color(0xFF9C9C98);

  static const success = Color(0xFF2D6A4F);
  static const error = Color(0xFFC0392B);
  static const warning = Color(0xFFD4A017);

  static const darkBackground = Color(0xFF0F1A14);
  static const darkSurface = Color(0xFF1A2E22);
  static const darkSurfaceVariant = Color(0xFF243B2D);
  static const darkBorder = Color(0xFF2E4A38);
  static const darkTextPrimary = Color(0xFFF0EFE8);
  static const darkTextSecondary = Color(0xFFB0B0A8);
}

class AppTextStyles {
  static const String _displayFont = 'Fraunces';
  static const String _bodyFont = 'Inter';

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
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const labelMedium = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.forestGreen,
          onPrimary: Colors.white,
          secondary: AppColors.warmGold,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceVariant,
          outline: AppColors.border,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.offWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.offWhite,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: AppTextStyles.headlineMedium,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: Colors.white,
            textStyle: AppTextStyles.titleMedium,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.forestGreen, width: 2),
          ),
          labelStyle: AppTextStyles.bodyMedium,
          hintStyle: AppTextStyles.bodyMedium,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.forestGreen,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.warmGoldLight,
          onPrimary: AppColors.darkBackground,
          secondary: AppColors.forestGreenLight,
          onSecondary: Colors.white,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.darkSurfaceVariant,
          outline: AppColors.darkBorder,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          margin: EdgeInsets.zero,
        ),
      );
}
