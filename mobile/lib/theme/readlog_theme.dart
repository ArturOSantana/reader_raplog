// ReadLog — Design System v3 · Editorial Contemporary
//
// Identidade: produto de leitura premium — Kindle · Arc · Apple Books · Notion
// Princípios: espaço branco, hierarquia tipográfica forte, livro como protagonista,
//             sem decoração excessiva, sem gamificação visual.
//
// Fontes via assets/fonts (pubspec):
//   Display / títulos → Fraunces (serifada de alta personalidade)
//   Interface / dados  → IBM Plex Sans (substituindo o Mono em UI genérica)
//   Números / código   → IBM Plex Mono (restrito a dados e timer)
//
// Paleta: fundo quase-branco e quase-preto puros. Um único acento.
// Sem papeis envelhecidos, sem latão, sem carimbos em destaque.

import 'package:flutter/material.dart';

export 'lumen_design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS DE COR
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogColors {
  ReadLogColors._();

  // ── Superfícies ──────────────────────────────────────────────────────────────
  /// Fundo principal light — branco suave, não puro
  static const surface = Color(0xFFFAF9F7);
  /// Fundo de cards e seções elevadas (light)
  static const surfaceVariant = Color(0xFFF2F1EF);
  /// Superfície ainda mais sutil (divisores, hover)
  static const surfaceSubtle = Color(0xFFECEBE9);

  /// Fundo principal dark — quase-preto, tinta escura
  static const canvas = Color(0xFF0F0F0E);
  /// Superfície de cards (dark)
  static const canvasVariant = Color(0xFF1A1A18);
  /// Superfície elevada (dark)
  static const canvasElevated = Color(0xFF222220);

  // ── Texto ────────────────────────────────────────────────────────────────────
  /// Texto principal (light)
  static const ink = Color(0xFF1A1918);
  /// Texto principal (dark)
  static const inkInverse = Color(0xFFF5F4F2);

  /// Texto secundário / metadados (light)
  static const inkMuted = Color(0xFF6B6863);
  /// Texto secundário (dark)
  static const inkMutedInverse = Color(0xFF8A8884);

  /// Placeholder / ghost text (light)
  static const inkGhost = Color(0xFFB0AEA9);
  /// Placeholder (dark)
  static const inkGhostInverse = Color(0xFF5A5856);

  // ── Acento único — preto editorial ──────────────────────────────────────────
  /// Acento primário — usado com extrema parcimônia
  /// Progresso, CTA principal, estado ativo da nav
  static const accent = Color(0xFF1A1918);
  static const accentInverse = Color(0xFFF5F4F2);

  // ── Acento secundário — usado só para progresso de leitura ──────────────────
  /// Verde-musgo refinado — só para progresso e streak ativo
  static const progress = Color(0xFF3D6B5A);
  static const progressLight = Color(0xFF5A9480);
  static const progressSubtle = Color(0x1A3D6B5A); // 10% progress

  // ── Estado / semântica ───────────────────────────────────────────────────────
  static const success = Color(0xFF3D6B5A);
  static const warning = Color(0xFF8B5E2E);
  static const danger  = Color(0xFF8B2E2E);

  // ── Divisores ────────────────────────────────────────────────────────────────
  /// Linha fina (light) — 8% ink
  static const hairline = Color(0x141A1918);
  /// Linha fina (dark) — 10% inkInverse
  static const hairlineDark = Color(0x1AF5F4F2);
  /// Separador mais visível (light) — 14% ink
  static const divider = Color(0x241A1918);
  /// Separador (dark)
  static const dividerDark = Color(0x24F5F4F2);

  // ── Presença ─────────────────────────────────────────────────────────────────
  static const online  = progress;
  static const idle    = Color(0xFF8B7355);
  static const offline = Color(0x4A6B6863);

  // ── Retrocompatibilidade com código legado ────────────────────────────────────
  /// @deprecated Use [canvas] em vez de [ink]
  static const ink_ = canvas;
  /// @deprecated Use [canvasVariant]
  static const inkAlt = canvasVariant;
  /// @deprecated Use [surface]
  static const paper = surface;
  /// @deprecated Use [surfaceVariant]
  static const paperAlt = surfaceVariant;
  /// @deprecated Use [surfaceSubtle]
  static const paperDeep = surfaceSubtle;
  /// @deprecated Use [progress]
  static const brass = progress;
  /// @deprecated Use [progressLight]
  static const brassLight = progressLight;
  /// @deprecated Use [danger]
  static const stamp = danger;
  /// @deprecated Use [progress]
  static const sage = progress;
  /// @deprecated Use [ink]
  static const charcoal = ink;
  /// @deprecated Use [surface]
  static const cream = surface;
  /// @deprecated Use [hairlineDark]
  static const inkLine = hairlineDark;
  /// @deprecated Use [hairline]
  static const paperLine = hairline;
  /// @deprecated Use [progress]
  static const sageDark = progress;
  /// @deprecated Use [hairline]
  static const paperShadow = hairline;
  /// @deprecated Use [warning]
  static const warning_ = warning;
}

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS DE TIPOGRAFIA
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogType {
  ReadLogType._();

  /// Escala tipográfica completa do Material 3.
  /// Fraunces para títulos/display, IBM Plex Sans para interface.
  static TextTheme textTheme(Color onSurface) => TextTheme(
        // ── Display — títulos de tela grandes, nome do livro ─────────────────
        displayLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 36,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          height: 1.1,
          color: onSurface,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 28,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          height: 1.15,
          color: onSurface,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          height: 1.2,
          color: onSurface,
        ),

        // ── Headline — títulos de seção ──────────────────────────────────────
        headlineLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          height: 1.3,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: onSurface,
        ),

        // ── Title — rótulos de card, nomes de livro em listas ────────────────
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.4,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.4,
          color: onSurface,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          height: 1.4,
          color: onSurface,
        ),

        // ── Body — texto corrido ──────────────────────────────────────────────
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: onSurface.withValues(alpha: 0.65),
        ),

        // ── Label — UI compacta, chips, nav ──────────────────────────────────
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: onSurface,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
          color: onSurface,
        ),
      );

  // ─── Helpers de estilo semântico ─────────────────────────────────────────────

  /// Título de livro — Fraunces, proeminente. O protagonista da interface.
  static TextStyle bookTitle({
    double size = 17,
    FontWeight weight = FontWeight.w500,
    Color? color,
    bool italic = false,
  }) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  /// Nome de autor — Sans, menor, espaçado
  static TextStyle authorName({
    double size = 13,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.4,
        color: color,
      );

  /// Citação / trecho de livro — Fraunces itálico
  static TextStyle quote({
    double size = 15,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.55,
        letterSpacing: 0.05,
        color: color,
      );

  /// Kicker/overline — IBM Plex Sans uppercase espaçado
  /// Usar para rótulos de seção como "LENDO AGORA", "BIBLIOTECA"
  static TextStyle kicker({
    double size = 10,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        height: 1.2,
        color: color,
      );

  /// Número grande — IBM Plex Mono para dados, timer, contagens
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontFamilyFallback: const ['Courier New', 'monospace'],
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  /// Retrocombatibilidade
  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w500,
    Color? color,
    bool italic = false,
  }) =>
      bookTitle(size: size, weight: weight, color: color, italic: italic);

  static TextStyle stampLabel({double size = 10, Color? color}) =>
      kicker(size: size, color: color);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMA MATERIAL
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogTheme {
  ReadLogTheme._();

  static final _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS:     const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS:   const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux:   const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: const _FadeSlidePageTransitionsBuilder(),
    },
  );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final tt   = ReadLogType.textTheme(ReadLogColors.ink);
    return base.copyWith(
      scaffoldBackgroundColor: ReadLogColors.surface,
      colorScheme: base.colorScheme.copyWith(
        primary:    ReadLogColors.ink,
        onPrimary:  ReadLogColors.inkInverse,
        secondary:  ReadLogColors.progress,
        onSecondary: ReadLogColors.inkInverse,
        surface:    ReadLogColors.surface,
        surfaceContainerHighest: ReadLogColors.surfaceVariant,
        onSurface:  ReadLogColors.ink,
        outline:    ReadLogColors.hairline,
        outlineVariant: ReadLogColors.divider,
        error:      ReadLogColors.danger,
      ),
      textTheme: tt,
      pageTransitionsTheme: _pageTransitions,

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: ReadLogColors.surface,
        foregroundColor: ReadLogColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: ReadLogType.bookTitle(size: 17, color: ReadLogColors.ink),
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
      ),

      // ── Botões ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ReadLogColors.ink,
          foregroundColor: ReadLogColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ReadLogColors.ink,
          foregroundColor: ReadLogColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ReadLogColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: ReadLogColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ReadLogColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),

      // ── Cards — sem elevação, borda sutil ────────────────────────────────
      cardTheme: CardThemeData(
        color: ReadLogColors.surfaceVariant,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: ReadLogColors.hairline),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── Inputs ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ReadLogColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.ink, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: ReadLogColors.inkMuted,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: ReadLogColors.inkGhost,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ReadLogColors.ink,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ReadLogColors.ink,
        selectionColor: ReadLogColors.ink.withValues(alpha: 0.15),
        selectionHandleColor: ReadLogColors.ink,
      ),

      // ── Divisores ────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: ReadLogColors.hairline,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        iconColor: ReadLogColors.inkMuted,
        textColor: ReadLogColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      ),

      // ── Dialogs / Sheets ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: ReadLogColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ReadLogColors.hairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReadLogColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: ReadLogColors.surfaceVariant,
        selectedColor: ReadLogColors.ink,
        disabledColor: ReadLogColors.surfaceSubtle,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: ReadLogColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final tt   = ReadLogType.textTheme(ReadLogColors.inkInverse);
    return base.copyWith(
      scaffoldBackgroundColor: ReadLogColors.canvas,
      colorScheme: base.colorScheme.copyWith(
        primary:    ReadLogColors.inkInverse,
        onPrimary:  ReadLogColors.ink,
        secondary:  ReadLogColors.progressLight,
        onSecondary: ReadLogColors.ink,
        surface:    ReadLogColors.canvas,
        surfaceContainerHighest: ReadLogColors.canvasVariant,
        onSurface:  ReadLogColors.inkInverse,
        outline:    ReadLogColors.hairlineDark,
        outlineVariant: ReadLogColors.dividerDark,
        error:      ReadLogColors.danger,
      ),
      textTheme: tt,
      pageTransitionsTheme: _pageTransitions,

      appBarTheme: AppBarTheme(
        backgroundColor: ReadLogColors.canvas,
        foregroundColor: ReadLogColors.inkInverse,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: ReadLogType.bookTitle(size: 17, color: ReadLogColors.inkInverse),
        iconTheme: const IconThemeData(color: ReadLogColors.inkInverse, size: 20),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ReadLogColors.inkInverse,
          foregroundColor: ReadLogColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ReadLogColors.inkInverse,
          foregroundColor: ReadLogColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ReadLogColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: ReadLogColors.dividerDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ReadLogColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: ReadLogColors.canvasVariant,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: ReadLogColors.hairlineDark),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ReadLogColors.canvasVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ReadLogColors.inkInverse, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: ReadLogColors.inkMutedInverse,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: ReadLogColors.inkGhostInverse,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ReadLogColors.inkInverse,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ReadLogColors.inkInverse,
        selectionColor: ReadLogColors.inkInverse.withValues(alpha: 0.2),
        selectionHandleColor: ReadLogColors.inkInverse,
      ),

      dividerTheme: const DividerThemeData(
        color: ReadLogColors.hairlineDark,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ReadLogColors.inkMutedInverse,
        textColor: ReadLogColors.inkInverse,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ReadLogColors.canvasVariant,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ReadLogColors.hairlineDark),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReadLogColors.canvasVariant,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ReadLogColors.canvasElevated,
        selectedColor: ReadLogColors.inkInverse,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: ReadLogColors.dividerDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSIÇÃO DE PÁGINA — FADE + MICRO-SLIDE
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fast = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.65)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(fast),
        child: child,
      ),
    );
  }
}

class ReadLogPageRoute<T> extends MaterialPageRoute<T> {
  ReadLogPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: BOOK SPINE NAV BAR
// Navegação inferior editorial: 4 abas + FAB central de sessão.
// Sem decorações excessivas. Linha tênue, indicador minimal.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogSpineNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool sessionActive;

  static const _sideIcons = [
    Icons.home_outlined,
    Icons.groups_2_outlined,
    Icons.menu_book_outlined,
    Icons.person_outline,
  ];

  const ReadLogSpineNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.sessionActive = false,
  });

  @override
  State<ReadLogSpineNavBar> createState() => _ReadLogSpineNavBarState();
}

class _ReadLogSpineNavBarState extends State<ReadLogSpineNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.sessionActive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ReadLogSpineNavBar old) {
    super.didUpdateWidget(old);
    if (widget.sessionActive && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.sessionActive && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static int _visualToLogical(int v) => v;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surface;
    final border = isDark ? ReadLogColors.hairlineDark  : ReadLogColors.hairline;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Row(
                children: [
                  // Abas 0 e 1
                  ...List.generate(2, (i) {
                    final logical = _visualToLogical(i);
                    return Expanded(
                      child: _NavTab(
                        icon: ReadLogSpineNavBar._sideIcons[i],
                        active: widget.currentIndex == logical,
                        onTap: () => widget.onTap(logical),
                        isDark: isDark,
                      ),
                    );
                  }),
                  // Espaço central do FAB
                  const SizedBox(width: 68),
                  // Abas 3 e 4
                  ...List.generate(2, (i) {
                    final sideIdx = i + 2;
                    final logical = _visualToLogical(i + 3);
                    return Expanded(
                      child: _NavTab(
                        icon: ReadLogSpineNavBar._sideIcons[sideIdx],
                        active: widget.currentIndex == logical,
                        onTap: () => widget.onTap(logical),
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
              // FAB central — círculo limpo
              Positioned(
                top: -16,
                child: FadeTransition(
                  opacity: widget.sessionActive
                      ? Tween<double>(begin: 0.7, end: 1.0).animate(
                          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                        )
                      : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: () => widget.onTap(2),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? ReadLogColors.inkInverse : ReadLogColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.sessionActive
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isDark ? ReadLogColors.ink : ReadLogColors.inkInverse,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab individual — ícone + indicador pontual ativo
class _NavTab extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool isDark;

  const _NavTab({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: active
                ? fg
                : fg.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: active ? 1.0 : 0.0,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? ReadLogColors.progressLight : ReadLogColors.progress,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: CATALOG CARD — Card de livro com capa
// Design editorial: tipografia protagonista, barra de progresso discreta.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogCatalogCard extends StatelessWidget {
  final String title;
  final String author;
  final double progress; // 0..1
  final Color tabColor;  // mantido para compatibilidade, mas usado sutilmente
  final VoidCallback? onTap;
  final String? coverUrl;
  final int? currentPage;
  final int? totalPages;

  const ReadLogCatalogCard({
    super.key,
    required this.title,
    required this.author,
    required this.progress,
    this.tabColor = ReadLogColors.progress,
    this.onTap,
    this.coverUrl,
    this.currentPage,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final fg     = isDark ? ReadLogColors.inkInverse    : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;

    final pct = (progress * 100).round();
    final pageText = (currentPage != null && totalPages != null && totalPages! > 0)
        ? 'p. $currentPage de $totalPages'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Capa ──────────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: hasCover
                      ? Image.network(
                          coverUrl!,
                          width: 48,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderCover(color: tabColor),
                        )
                      : _PlaceholderCover(color: tabColor),
                ),
                const SizedBox(width: 16),

                // ── Texto + progresso ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ReadLogType.bookTitle(size: 16, color: fg),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        author,
                        style: ReadLogType.authorName(size: 13, color: fgMut),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Barra de progresso limpa
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: fg.withValues(alpha: 0.1),
                          color: progress >= 1.0
                              ? ReadLogColors.success
                              : (isDark ? ReadLogColors.progressLight : ReadLogColors.progress),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$pct%',
                            style: ReadLogType.mono(
                              size: 11,
                              weight: FontWeight.w500,
                              color: fgMut,
                            ),
                          ),
                          if (pageText != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '·',
                              style: TextStyle(
                                fontSize: 11,
                                color: fgMut.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pageText,
                              style: ReadLogType.mono(
                                size: 11,
                                color: fgMut.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chevron ───────────────────────────────────────────────
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: fg.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final Color color;
  const _PlaceholderCover({required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 48,
      height: 68,
      color: color.withValues(alpha: isDark ? 0.15 : 0.1),
      child: Center(
        child: Icon(
          Icons.book_outlined,
          size: 20,
          color: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS LEGADOS — mantidos para compatibilidade, marcados para migração
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Substituído por layout tipográfico direto.
/// Mantido para compatibilidade com telas não migradas.
class ReadLogStamp extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double size;
  final double rotationDeg;

  const ReadLogStamp({
    super.key,
    required this.value,
    required this.label,
    this.color = ReadLogColors.progress,
    this.size = 72,
    this.rotationDeg = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final border = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: ReadLogType.mono(
              size: size * 0.28,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: ReadLogType.kicker(size: size * 0.1, color: color),
          ),
        ],
      ),
    );
  }
}

class ReadLogLeaderRow extends StatelessWidget {
  final String label;
  final String value;

  const ReadLogLeaderRow(
      {super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: fg,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: fg.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// Componentes de leaderboard, poll, notification — mantidos para compatibilidade

class ReadLogMilestoneTrack extends StatelessWidget {
  final int totalSegments;
  final int completedSegments;
  final List<String> labels;

  const ReadLogMilestoneTrack({
    super.key,
    this.totalSegments = 5,
    required this.completedSegments,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? ReadLogColors.progressLight : ReadLogColors.progress;
    final inactive = isDark ? ReadLogColors.canvasElevated : ReadLogColors.surfaceSubtle;

    return Row(
      children: List.generate(totalSegments, (i) {
        final done = i < completedSegments;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < totalSegments - 1 ? 3 : 0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: done ? active : inactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ReadLogLiveChip extends StatefulWidget {
  final String label;
  const ReadLogLiveChip({super.key, required this.label});

  @override
  State<ReadLogLiveChip> createState() => _ReadLogLiveChipState();
}

class _ReadLogLiveChipState extends State<ReadLogLiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? ReadLogColors.canvasElevated : ReadLogColors.surfaceVariant;
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ReadLogColors.progress,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: ReadLogType.kicker(size: 10, color: fg),
          ),
        ],
      ),
    );
  }
}

class ReadLogLeaderboardRow extends StatelessWidget {
  final int position;
  final String name;
  final String metric;
  final bool highlight;

  const ReadLogLeaderboardRow({
    super.key,
    required this.position,
    required this.name,
    required this.metric,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fgMut = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position',
              style: ReadLogType.mono(
                size: 12,
                weight: highlight ? FontWeight.w700 : FontWeight.w400,
                color: highlight
                    ? (isDark ? ReadLogColors.progressLight : ReadLogColors.progress)
                    : fgMut,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: fg,
              ),
            ),
          ),
          Text(
            metric,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: fgMut,
            ),
          ),
        ],
      ),
    );
  }
}

class ReadLogPollBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color fillColor;

  const ReadLogPollBar({
    super.key,
    required this.label,
    required this.percent,
    this.fillColor = ReadLogColors.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final bg = isDark ? ReadLogColors.canvasElevated : ReadLogColors.surfaceSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: ReadLogType.mono(size: 12, color: fg.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: bg),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(height: 4, color: fillColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReadLogNotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  const ReadLogNotificationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? (unread ? ReadLogColors.canvasVariant : ReadLogColors.canvas)
        : (unread ? ReadLogColors.surfaceVariant : ReadLogColors.surface);
    final fg     = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, size: 18, color: fg.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        color: fg,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: fgMut,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                time,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: fgMut,
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: ReadLogColors.progress,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
