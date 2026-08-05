// Lumen — Design System · fonte única de verdade
// Shims de compatibilidade exportados por lumen_compat.dart (período de migração).
// @see lib/theme/lumen_compat.dart
//
// Identidade: produto de leitura premium — Kindle, Linear, Arc, Notion.
// Princípios: espaço branco, hierarquia tipográfica forte, livro como
//             protagonista, sem gamificação visual, sem decoração excessiva.
//
// Fontes (declaradas em pubspec.yaml):
//   Fraunces      — títulos de livro, heroes, números grandes
//   Inter         — interface, body text
//   IBM Plex Mono — dados, timer, kickers uppercase
//
// Para migrar do sistema v1, substitua:
//   ReadLogColors  → LumenColors
//   ReadLogType    → LumenType
//   ReadLogTheme   → LumenTheme
//   AppColors.*    → LumenColors.*
//   AppTextStyles  → use LumenType ou Theme.of(context).textTheme diretamente
//
// Componentes v1 SEM equivalente direto (reescrita manual necessária):
//   ReadLogStamp          → remover (gamificação proibida pela spec)
//   ReadLogLeaderboardRow → LumenReputationRow (quando criado)
//   ReadLogReadingHeatmap → exibição textual + linha monocromática fina
//   ReadLogCatalogCard    → LumenBookRow (lista) ou LumenBookHero (uma por tela)
//   ReadLogEventStamp     → remover variant badge/challenge; checkIn/milestone → texto
//   ReadLogFeedCard       → LumenFeedRow (sem curtida com coração cheio)
//   ReadLogClubCard       → reescrita editorial
//   ReadLogChip (filled)  → tabs-texto + sublinhado; nunca chip colorido
//   ReadLogMilestoneTrack → LumenReadingProgress (linha fina + ponto)
//   ReadLogLiveChip       → ponto 5px animado + texto mono inline

library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

export 'lumen_compat.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORES
// ─────────────────────────────────────────────────────────────────────────────

/// Paleta canônica do Lumen.
///
/// Light e dark são variantes próprias — o dark NÃO é o light invertido.
/// Acento único: o próprio preto/branco editorial. Verde-musgo (`read`) é
/// reservado para progresso de leitura e estado de presença ativa.
abstract final class LumenColors {
  LumenColors._();

  // ── Superfícies light ──────────────────────────────────────────────────────
  /// Fundo principal light — off-white quente
  static const surface         = Color(0xFFFAF9F7);
  /// Fundo de cards/seções ligeiramente elevadas
  static const surfaceVariant  = Color(0xFFF2F1EF);
  /// Fundo ainda mais sutil (divisores, hover)
  static const surfaceSubtle   = Color(0xFFECEBE9);

  // ── Superfícies dark ───────────────────────────────────────────────────────
  /// Fundo principal dark — quase-preto
  static const canvas          = Color(0xFF0F0F0E);
  /// Cards dark
  static const canvasVariant   = Color(0xFF1A1A18);
  /// Superfície elevada dark
  static const canvasElevated  = Color(0xFF222220);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const ink             = Color(0xFF1A1918); // texto principal light
  static const inkInverse      = Color(0xFFF5F4F2); // texto principal dark
  static const inkMuted        = Color(0xFF6B6863); // metadados light
  static const inkMutedInverse = Color(0xFFA8A5A0); // metadados dark — mais claro para visibilidade
  static const inkGhost        = Color(0xFFB0AEA9); // placeholder light
  static const inkGhostInverse = Color(0xFF8A8884); // placeholder dark — mais claro que antes

  // ── Acento editorial ──────────────────────────────────────────────────────
  /// Acento primário — mesmo tom do texto. Usado com parcimônia extrema.
  static const accent          = Color(0xFF1A1918);
  static const accentInverse   = Color(0xFFF5F4F2);

  // ── Progresso e presença ──────────────────────────────────────────────────
  /// Verde-musgo — exclusivo para progresso de leitura e presença ativa.
  static const read            = Color(0xFF3D6B5A);
  static const readLight       = Color(0xFF5A9480);
  static const readSubtle      = Color(0x1A3D6B5A); // 10% read

  // ── Estado / semântica ────────────────────────────────────────────────────
  static const success         = Color(0xFF3D6B5A);
  static const warning         = Color(0xFF8B5E2E);
  static const danger          = Color(0xFF8B2E2E);

  // ── Divisores ─────────────────────────────────────────────────────────────
  /// Linha mais fina — 8% ink
  static const hairline        = Color(0x141A1918);
  static const hairlineDark    = Color(0x1AF5F4F2);
  /// Separador visível — 14% ink
  static const divider         = Color(0x241A1918);
  static const dividerDark     = Color(0x24F5F4F2);

  // ── Texto secundário (ícones, labels, disable state) ─────────────────────
  /// Texto desabilitado/secundário light — mantém contraste mínimo
  static const inkSecondary         = Color(0xFF8A8884);
  /// Texto desabilitado/secundário dark — mantém contraste mínimo (mais claro para visibilidade)
  static const inkSecondaryInverse  = Color(0xFF9B9892);

  // ── Presença ──────────────────────────────────────────────────────────────
  static const online          = read;
  static const idle            = Color(0xFF8B7355);
  static const offline         = Color(0x4A6B6863);

  // ── Aliases @deprecated — usados apenas durante janela de migração ─────────
  /// @deprecated Use [surface]
  @Deprecated('Use LumenColors.surface') static const paper       = surface;
  /// @deprecated Use [surfaceVariant]
  @Deprecated('Use LumenColors.surfaceVariant') static const paperAlt  = surfaceVariant;
  /// @deprecated Use [surfaceSubtle]
  @Deprecated('Use LumenColors.surfaceSubtle') static const paperDeep = surfaceSubtle;
  /// @deprecated Use [ink]
  @Deprecated('Use LumenColors.ink') static const charcoal        = ink;
  /// @deprecated Use [surface]
  @Deprecated('Use LumenColors.surface') static const cream        = surface;
  /// @deprecated Use [read]
  @Deprecated('Use LumenColors.read') static const progress        = read;
  /// @deprecated Use [readLight]
  @Deprecated('Use LumenColors.readLight') static const progressLight = readLight;
  /// @deprecated Use [readSubtle]
  @Deprecated('Use LumenColors.readSubtle') static const progressSubtle = readSubtle;
  /// @deprecated Use [read]
  @Deprecated('Use LumenColors.read') static const brass           = read;
  /// @deprecated Use [readLight]
  @Deprecated('Use LumenColors.readLight') static const brassLight  = readLight;
  /// @deprecated Use [danger]
  @Deprecated('Use LumenColors.danger') static const stamp          = danger;
  /// @deprecated Use [read]
  @Deprecated('Use LumenColors.read') static const sage             = read;
  /// @deprecated Use [read]
  @Deprecated('Use LumenColors.read') static const sageDark         = read;
  /// @deprecated Use [hairline]
  @Deprecated('Use LumenColors.hairline') static const paperLine    = hairline;
  /// @deprecated Use [hairline]
  @Deprecated('Use LumenColors.hairline') static const paperShadow  = hairline;
  /// @deprecated Use [hairlineDark]
  @Deprecated('Use LumenColors.hairlineDark') static const inkLine  = hairlineDark;
  /// @deprecated Use [canvasVariant]
  @Deprecated('Use LumenColors.canvasVariant') static const inkAlt  = canvasVariant;
  /// @deprecated Use [canvas]
  @Deprecated('Use LumenColors.canvas') static const ink_           = canvas;
  /// @deprecated Use [warning]
  @Deprecated('Use LumenColors.warning') static const warning_      = warning;
}

/// Extension para facilitar uso de cores secundárias com visibilidade garantida.
/// Evita .withValues(alpha: ...) que fica invisível em fundo contrário.
extension LumenColorsExt on BuildContext {
  Color get inkSecondary {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? LumenColors.inkSecondaryInverse : LumenColors.inkSecondary;
  }
  
  Color get hairlineColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? LumenColors.hairlineDark : LumenColors.hairline;
  }
  
  Color get surfaceBg {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? LumenColors.canvasVariant : LumenColors.surfaceVariant;
  }
}

/// Helper para converter cores genéricas (legacy) com segurança de tema.
/// Usa mapeamento inteligente: se opacidade >= 0.5, retorna a cor em si;
/// se menor, retorna versão mais fraca da paleta.
extension LumenSafeColor on Color {
  /// Aplica opacidade de forma segura — retorna cor apropriada da paleta
  /// em vez de apenas reduzir opacidade (que fica invisível em dark mode).
  Color withSafeOpacity(double opacity) {
    // Se opacidade é alta (>= 50%), use a cor diretamente
    if (opacity >= 0.5) {
      return this;
    }
    
    // Se é cor clara (texto light mode), use versão mais fraca
    if (this == LumenColors.ink) {
      return LumenColors.inkMuted;
    }
    if (this == LumenColors.inkInverse) {
      return LumenColors.inkMutedInverse;
    }
    
    // Fallback: retorna cor com opacidade reduzida (não ideal, mas segura)
    return withValues(alpha: opacity);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOGRAFIA
// ─────────────────────────────────────────────────────────────────────────────

/// Escala tipográfica do Lumen.
///
/// Fraunces: títulos de livro, heroes, números grandes — nunca em listas.
/// Inter: interface, body, labels.
/// IBM Plex Mono: dados, timer, kickers uppercase.
abstract final class LumenType {
  LumenType._();

  /// TextTheme completo para MaterialApp — mapeia slots M3.
  static TextTheme textTheme(Color onSurface) => TextTheme(
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
          color: onSurface,
        ),
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

  // ── Helpers semânticos ────────────────────────────────────────────────────

  /// Título de livro — Fraunces, o protagonista.
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

  /// Nome de autor — Inter light, espaçado.
  static TextStyle authorName({double size = 13, Color? color}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.4,
        color: color,
      );

  /// Citação / trecho de livro — Fraunces itálico.
  static TextStyle quote({double size = 15, Color? color}) => TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.55,
        letterSpacing: 0.05,
        color: color,
      );

  /// Kicker/overline — Inter uppercase espaçado.
  /// Usar em labels de seção: "LENDO AGORA", "BIBLIOTECA".
  static TextStyle kicker({double size = 10, Color? color}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        height: 1.2,
        color: color,
      );

  /// Dados, timer, contagens — IBM Plex Mono.
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

  /// Alias de compatibilidade — delegar para bookTitle.
  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w500,
    Color? color,
    bool italic = false,
  }) =>
      bookTitle(size: size, weight: weight, color: color, italic: italic);

  /// @deprecated Use [kicker]
  @Deprecated('Use LumenType.kicker')
  static TextStyle stampLabel({double size = 10, Color? color}) =>
      kicker(size: size, color: color);
}

// ─────────────────────────────────────────────────────────────────────────────
// ESPAÇAMENTO — grid de 8px
// ─────────────────────────────────────────────────────────────────────────────

/// Escala de espaçamento baseada em 8px.
/// Valores fora desta escala (ex.: 5, 7, 11) não devem ser usados.
abstract final class LumenSpace {
  LumenSpace._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;
  static const double huge = 64;

  /// Padding horizontal padrão de página (24px cada lado)
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);
  /// Padding padrão de item de lista
  static const EdgeInsets listItem =
      EdgeInsets.symmetric(horizontal: lg, vertical: 12);
}

// ─────────────────────────────────────────────────────────────────────────────
// RAIOS DE BORDA
// ─────────────────────────────────────────────────────────────────────────────

abstract final class LumenRadius {
  LumenRadius._();

  static const double card   = 6;    // cards compactos
  static const double button = 4;    // botões, inputs
  static const double modal  = 12;   // bottom sheets, modals
  static const double pill   = 999;  // apenas para CTAs pill (Sala de Leitura)

  static const BorderRadius cardAll   = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonAll = BorderRadius.all(Radius.circular(button));
  static const BorderRadius modalTop  =
      BorderRadius.vertical(top: Radius.circular(modal));
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTION — valores canônicos da spec
// ─────────────────────────────────────────────────────────────────────────────

/// Tokens de animação.
///
/// Duração canônica: 220ms · Curva canônica: easeOutCubic.
/// Nada "aparece" instantâneo — toda transição tem fade de opacidade/posição.
abstract final class LumenMotion {
  LumenMotion._();

  /// 220ms — duração padrão de componente (botão, input focus, container)
  static const Duration duration = Duration(milliseconds: 220);

  /// 150ms — micro-interações (toggle, press feedback)
  static const Duration fast = Duration(milliseconds: 150);

  /// 350ms — transições de página, modais
  static const Duration slow = Duration(milliseconds: 350);

  /// Curva padrão — easeOutCubic (spec canônica)
  static const Curve curve = Curves.easeOutCubic;

  /// Curva de saída
  static const Curve curveOut = Curves.easeInCubic;

  /// Cadência do skeleton pulse — mais lenta que animações de UI
  /// para não competir visualmente com o grain.
  static const Duration skelPulse = Duration(milliseconds: 1800);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMA MATERIAL
// ─────────────────────────────────────────────────────────────────────────────

/// Fábrica de ThemeData.
///
/// Uso no MaterialApp:
/// ```dart
/// theme:      LumenTheme.light(),
/// darkTheme:  LumenTheme.dark(),
/// themeMode:  ThemeMode.system,
/// ```
abstract final class LumenTheme {
  LumenTheme._();

  static final _pageTransitions = PageTransitionsTheme(
    builders: {
      for (final p in TargetPlatform.values)
        p: const _FadeSlidePageTransitionsBuilder(),
    },
  );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final tt   = LumenType.textTheme(LumenColors.ink);
    return base.copyWith(
      scaffoldBackgroundColor: LumenColors.surface,
      colorScheme: base.colorScheme.copyWith(
        primary:                  LumenColors.ink,
        onPrimary:                LumenColors.inkInverse,
        secondary:                LumenColors.read,
        onSecondary:              LumenColors.inkInverse,
        surface:                  LumenColors.surface,
        surfaceContainerHighest:  LumenColors.surfaceVariant,
        onSurface:                LumenColors.ink,
        outline:                  LumenColors.hairline,
        outlineVariant:           LumenColors.divider,
        error:                    LumenColors.danger,
      ),
      textTheme:            tt,
      pageTransitionsTheme: _pageTransitions,

      appBarTheme: AppBarTheme(
        backgroundColor:     LumenColors.surface,
        foregroundColor:     LumenColors.ink,
        elevation:           0,
        scrolledUnderElevation: 0,
        titleTextStyle:      LumenType.bookTitle(size: 17, color: LumenColors.ink),
        iconTheme:           const IconThemeData(color: LumenColors.ink, size: 20),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LumenColors.ink,
          foregroundColor: LumenColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LumenColors.ink,
          foregroundColor: LumenColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LumenColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: LumenColors.divider),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LumenColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),

      // Cards — sem elevação; hierarquia por cor e espaço, não sombra
      cardTheme: CardThemeData(
        color:       LumenColors.surfaceVariant,
        elevation:   0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: LumenRadius.cardAll,
          side: const BorderSide(color: LumenColors.hairline),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Inputs — borda via InputDecorationTheme (não viola a regra Border.all)
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      LumenColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.danger),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: LumenColors.inkMuted,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: LumenColors.inkGhost,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
          color: LumenColors.ink,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor:           LumenColors.ink,
        selectionColor:        LumenColors.ink.withValues(alpha: 0.15),
        selectionHandleColor:  LumenColors.ink,
      ),

      dividerTheme: const DividerThemeData(
        color:     LumenColors.hairline,
        thickness: 1,
        space:     1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor:       LumenColors.inkMuted,
        textColor:       LumenColors.ink,
        contentPadding:  EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:   LumenColors.surface,
        surfaceTintColor:  Colors.transparent,
        elevation:         0,
        shape: RoundedRectangleBorder(
          borderRadius: LumenRadius.cardAll,
          side: const BorderSide(color: LumenColors.hairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:  LumenColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.modalTop),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: LumenColors.surfaceVariant,
        selectedColor:   LumenColors.ink,
        disabledColor:   LumenColors.surfaceSubtle,
        labelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
        ),
        side:  const BorderSide(color: LumenColors.divider),
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LumenColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 13, color: LumenColors.inkInverse,
        ),
        behavior:  SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.cardAll),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final tt   = LumenType.textTheme(LumenColors.inkInverse);
    return base.copyWith(
      scaffoldBackgroundColor: LumenColors.canvas,
      colorScheme: base.colorScheme.copyWith(
        primary:                  LumenColors.inkInverse,
        onPrimary:                LumenColors.ink,
        secondary:                LumenColors.readLight,
        onSecondary:              LumenColors.ink,
        surface:                  LumenColors.canvas,
        surfaceContainerHighest:  LumenColors.canvasVariant,
        onSurface:                LumenColors.inkInverse,
        outline:                  LumenColors.hairlineDark,
        outlineVariant:           LumenColors.dividerDark,
        error:                    LumenColors.danger,
      ),
      textTheme:            tt,
      pageTransitionsTheme: _pageTransitions,

      appBarTheme: AppBarTheme(
        backgroundColor:     LumenColors.canvas,
        foregroundColor:     LumenColors.inkInverse,
        elevation:           0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            LumenType.bookTitle(size: 17, color: LumenColors.inkInverse),
        iconTheme:
            const IconThemeData(color: LumenColors.inkInverse, size: 20),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LumenColors.inkInverse,
          foregroundColor: LumenColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LumenColors.inkInverse,
          foregroundColor: LumenColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LumenColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: LumenColors.dividerDark),
          shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LumenColors.inkInverse,
          textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color:       LumenColors.canvasVariant,
        elevation:   0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: LumenRadius.cardAll,
          side: const BorderSide(color: LumenColors.hairlineDark),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      LumenColors.canvasVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.inkInverse, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: LumenRadius.buttonAll,
          borderSide: const BorderSide(color: LumenColors.danger),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14,
          color: LumenColors.inkMutedInverse,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14,
          color: LumenColors.inkGhostInverse,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
          color: LumenColors.inkInverse,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor:          LumenColors.inkInverse,
        selectionColor:       LumenColors.inkInverse.withValues(alpha: 0.2),
        selectionHandleColor: LumenColors.inkInverse,
      ),

      dividerTheme: const DividerThemeData(
        color:     LumenColors.hairlineDark,
        thickness: 1,
        space:     1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor:      LumenColors.inkMutedInverse,
        textColor:      LumenColors.inkInverse,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:  LumenColors.canvasVariant,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(
          borderRadius: LumenRadius.cardAll,
          side: const BorderSide(color: LumenColors.hairlineDark),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:  LumenColors.canvasVariant,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.modalTop),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: LumenColors.canvasElevated,
        selectedColor:   LumenColors.inkInverse,
        labelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
        ),
        side:  const BorderSide(color: LumenColors.dividerDark),
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.buttonAll),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LumenColors.canvasVariant,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 13, color: LumenColors.inkInverse,
        ),
        behavior:  SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: LumenRadius.cardAll),
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
    // ── A página "emerge" do papel, não desliza sobre ele ──
    //
    // Três camadas sobrepostas:
    //   1. FadeTransition     — dissolve de 0 → 1 (entra) / 1 → 0 (sai)
    //   2. SlideTransition    — micro-slide de 6 px para cima (apenas entrada)
    //   3. _GrainDissolve     — o grain de textura fica levemente mais visível
    //                           no início da transição e dissolve junto à página
    //
    // secondaryAnimation (saída da rota anterior): só fade, sem slide —
    // isso evita que duas páginas deslizem em direções opostas.
    final curved = CurvedAnimation(
      parent: animation,
      curve: LumenMotion.curve,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: _GrainDissolve(animation: curved, child: child),
      ),
    );
  }
}

// ── Grain dissolve: sobreposição do grain que aparece durante a transição ──────
//
// Durante a entrada de uma nova rota, aumentamos brevemente a opacidade
// do grain (de 0.035 para ~0.07) e dissolvemos junto com a transição.
// O efeito é quase imperceptível — é uma "sensação" de papel voltando
// ao foco, não um artefato visual visível.
class _GrainDissolve extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _GrainDissolve({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Opacidade do grain: começa em 0.035 (igual ao permanente) e dissolve para 0
        // enquanto a página entra. O grain permanente (LumenTexturedBackground) já
        // está sob tudo — este layer extra é o "foco de papel" na transição.
        final grainExtra = (1.0 - animation.value) * 0.035;
        return CustomPaint(
          foregroundPainter: grainExtra > 0.001
              ? _TexturePainter(
                  dotColor: base.withSafeOpacity(grainExtra),
                )
              : null,
          child: child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES DO CLUBE — primitivos Lumen
// ─────────────────────────────────────────────────────────────────────────────
// Esses widgets definem o vocabulário visual do módulo Clube.
// Não adicionar cor de fundo + Border.all juntos — cada um usa apenas
// o que está descrito abaixo (texto, Divider, linha fina, ponto).

/// Barra de progresso de leitura — linha fina + ponto na posição atual.
///
/// Usar para: progresso individual, marcos do clube, % coletiva.
/// Nunca usar círculo com % ou barra segmentada colorida.
///
/// ```dart
/// LumenReadingProgress(
///   progress: 0.62,
///   label: '62% do clube já passou deste ponto',
/// )
/// ```
class LumenReadingProgress extends StatelessWidget {
  /// Progresso de 0.0 a 1.0
  final double progress;
  final String? label;

  const LumenReadingProgress({
    super.key,
    required this.progress,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? LumenColors.hairlineDark : LumenColors.hairline;
    final fillColor  = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final p          = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: 12,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // trilha
                Positioned.fill(
                  top: 5,
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // preenchimento
                Positioned(
                  left: 0,
                  top: 5,
                  bottom: 5,
                  width: w * p,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // ponto
                Positioned(
                  left: (w * p - 3).clamp(0, w - 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: fillColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!,
            style: LumenType.mono(
              size: 10,
              color: isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Banner de desbloqueio de marco.
///
/// Exibe acima do título na tela de discussão quando um marco é atingido.
/// Sem Container colorido — apenas kicker mono em verde.
///
/// ```dart
/// LumenUnlockBanner(label: 'Marco 50% liberado')
/// ```
class LumenUnlockBanner extends StatelessWidget {
  final String label;

  const LumenUnlockBanner({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: LumenType.kicker(
        size: 10,
        color: LumenColors.read,
      ).copyWith(letterSpacing: 1.2),
    );
  }
}

/// Nota de spoiler — borda-esquerda fina + texto muted.
///
/// ```dart
/// LumenSpoilerNote(
///   text: 'Você está na página 284. Comentários além deste ponto '
///         'ficam ocultos até você chegar lá.',
/// )
/// ```
class LumenSpoilerNote extends StatelessWidget {
  final String text;

  const LumenSpoilerNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 2,
            decoration: BoxDecoration(
              color: isDark ? LumenColors.hairlineDark : LumenColors.divider,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: LumenType.authorName(
                size: 12,
                color: isDark
                    ? LumenColors.inkMutedInverse
                    : LumenColors.inkMuted,
              ).copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de leitor na Sala de Leitura — nome + tempo decorrido.
///
/// Sem avatar circular. Sem anel de cor.
class LumenReaderRow extends StatelessWidget {
  final String name;
  final String elapsed;
  final bool isYou;
  /// URL da foto do membro (opcional). Quando null, exibe iniciais.
  final String? avatarUrl;

  const LumenReaderRow({
    super.key,
    required this.name,
    required this.elapsed,
    this.isYou = false,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final mutedColor = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _LumenAvatar(name: name, avatarUrl: avatarUrl, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isYou ? '$name (você)' : name,
              style: LumenType.bookTitle(size: 14, color: textColor),
            ),
          ),
          Text(
            elapsed,
            style: LumenType.mono(size: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }
}

/// Linha de teoria — texto + status narrativo + votos.
///
/// Status: 'pending' | 'confirmed' | 'wrong'
/// Sem card colorido. Tags como texto mono com cor semântica mínima.
class LumenTheoryRow extends StatelessWidget {
  final String text;
  final int votes;
  /// 'pending' | 'confirmed' | 'wrong'
  final String status;

  const LumenTheoryRow({
    super.key,
    required this.text,
    required this.votes,
    this.status = 'pending',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (tagLabel, tagColor) = switch (status) {
      'confirmed' => ('confirmada', LumenColors.read),
      'wrong'     => ('errada',     LumenColors.danger),
      _           => ('em aberto',  isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: LumenType.authorName(
              size: 13,
              color: isDark ? LumenColors.inkInverse : LumenColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$votes ${votes == 1 ? "voto" : "votos"}',
                style: LumenType.mono(
                  size: 11,
                  color: isDark
                      ? LumenColors.inkMutedInverse
                      : LumenColors.inkMuted,
                ),
              ),
              _TheoryTag(label: tagLabel, color: tagColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _TheoryTag extends StatelessWidget {
  final String label;
  final Color color;

  const _TheoryTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(LumenRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: LumenType.kicker(size: 9, color: color),
        ),
      ),
    );
  }
}

/// Linha de reputação — substitui selos/trofeus.
///
/// Exibe contribuições qualitativas: "contribuiu em 14 discussões · criou 6 teorias".
/// Nunca exibir volume de páginas lidas como métrica de reputação.
class LumenReputationRow extends StatelessWidget {
  final String name;
  final String descriptor;
  final bool highlight;

  const LumenReputationRow({
    super.key,
    required this.name,
    required this.descriptor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final muted  = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: LumenType.authorName(
                    size: 13,
                    color: highlight ? LumenColors.read : color,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  descriptor,
                  style: LumenType.mono(size: 11, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÍCONE SVG — wrapper para assets/icons/
// ─────────────────────────────────────────────────────────────────────────────

/// Ícone do set Lumen (assets/icons/*.svg).
///
/// Todos os ícones são 24×24, stroke 1.75, cantos arredondados.
/// Não usar ícones Material — usar este widget ou os SVGs diretamente.
///
/// ```dart
/// LumenIcon('home')           // assets/icons/home.svg
/// LumenIcon('bookmark', size: 20, color: LumenColors.inkMuted)
/// ```
class LumenIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const LumenIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ??
        (isDark ? LumenColors.inkInverse : LumenColors.ink);

    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width:           size,
      height:          size,
      colorFilter:     ColorFilter.mode(c, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR NEUTRO — foto real ou iniciais, nunca cor aleatória
// ─────────────────────────────────────────────────────────────────────────────

/// Avatar circular: foto via URL ou iniciais sobre fundo cinza neutro.
///
/// Nunca usa cor aleatória por usuário — fallback sempre cinza neutro.
/// Usa [NetworkImage] direto; para cache persistente, troque por
/// CachedNetworkImageProvider na camada de feature.
class _LumenAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _LumenAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? LumenColors.canvasElevated : LumenColors.surfaceSubtle;
    final fg = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    final provider = avatarUrl != null && avatarUrl!.isNotEmpty
        ? NetworkImage(avatarUrl!) as ImageProvider
        : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: provider,
      child: provider == null
          ? Text(initials, style: LumenType.mono(size: radius * 0.65, color: fg))
          : null,
    );
  }
}

/// Avatar público, exportado para componentes fora do tema.
///
/// Usa os mesmos critérios de [_LumenAvatar] — foto ou iniciais neutras.
class LumenAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const LumenAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) => _LumenAvatar(
        name: name,
        avatarUrl: avatarUrl,
        radius: radius,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXTURED BACKGROUND — granulado sutil, CustomPainter com seed fixa
// ─────────────────────────────────────────────────────────────────────────────

/// Aplica textura de granulado sutil sobre o fundo do Scaffold.
///
/// Envolver apenas o `body` de cada [Scaffold] — não a árvore inteira.
/// Opacidade padrão 3.5 % (`opacity: 0.035`), igual em light e dark.
///
/// ```dart
/// Scaffold(
///   body: LumenTexturedBackground(child: ...),
/// )
/// ```
class LumenTexturedBackground extends StatelessWidget {
  final Widget child;

  const LumenTexturedBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light → pontos pretos   14 % de opacidade sobre fundo claro.
    // Dark  → pontos brancos  14 % de opacidade sobre fundo escuro.
    // Sem BlendMode especial — srcOver puro é suficiente porque a cor
    // já é a oposta do fundo. BlendMode.overlay num PictureRecorder
    // isolado não acessa o fundo real do canvas pai e não produz efeito.
    final dotColor = isDark
        ? const Color(0x24FFFFFF) // ~14 % branco
        : const Color(0x24000000); // ~14 % preto
    return CustomPaint(
      // foregroundPainter pinta NA FRENTE do child —
      // sobrepõe o backgroundColor opaco do Scaffold.
      foregroundPainter: _TexturePainter(dotColor: dotColor),
      child: child,
    );
  }
}

class _TexturePainter extends CustomPainter {
  final Color dotColor;

  const _TexturePainter({required this.dotColor});

  // Cache estático por (tamanho × cor).
  // Recriar o Picture custa ~200-3000 drawCircle calls; com cache
  // qualquer frame subsequente é apenas um drawPicture barato.
  static ui.Picture? _cachedPicture;
  static Size _cachedSize = Size.zero;
  static Color _cachedColor = const Color(0x00000000);

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedPicture == null ||
        _cachedSize != size ||
        _cachedColor != dotColor) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      final paint = Paint()..color = dotColor; // srcOver padrão
      final rng = math.Random(42);             // seed fixa = reprodutível
      const density = 0.0018;                  // pontos por pixel²
      final count =
          (size.width * size.height * density).round().clamp(400, 3000);
      for (var i = 0; i < count; i++) {
        final x = rng.nextDouble() * size.width;
        final y = rng.nextDouble() * size.height;
        c.drawCircle(Offset(x, y), 0.7, paint);
      }
      _cachedPicture = recorder.endRecording();
      _cachedSize = size;
      _cachedColor = dotColor;
    }
    canvas.drawPicture(_cachedPicture!);
  }

  @override
  bool shouldRepaint(_TexturePainter old) => old.dotColor != dotColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// LUMEN GRAIN LOADER
// ─────────────────────────────────────────────────────────────────────────────
//
// Loading de tela inteira que usa o grain como âncora visual, em vez de
// um spinner giratório. A tela "respira" — fades suaves de opacidade que
// casam com a cadência do LumenMotion.skelPulse.
//
// Uso:
// ```dart
// if (isLoading) return const LumenGrainLoader();
// ```
//
// Também disponível como wrapper:
// ```dart
// LumenGrainLoader.wrap(
//   isLoading: state.isLoading,
//   child: MyContent(),
// )
// ```

/// Indicador de loading editorial — grain + fades suaves, sem spinner.
class LumenGrainLoader extends StatefulWidget {
  const LumenGrainLoader({super.key});

  /// Wrapper condicional: exibe [LumenGrainLoader] quando [isLoading] é true,
  /// senão exibe [child] com animação `page-enter` (fade + micro-slide).
  static Widget wrap({
    required bool isLoading,
    required Widget child,
  }) =>
      isLoading
          ? const LumenGrainLoader()
          : _PageEnterReveal(child: child);

  @override
  State<LumenGrainLoader> createState() => _LumenGrainLoaderState();
}

class _LumenGrainLoaderState extends State<LumenGrainLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: LumenMotion.skelPulse,
    );
    _opacity = Tween<double>(begin: 0.7, end: 0.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? LumenColors.canvas : LumenColors.surface;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        color: bg,
        child: CustomPaint(
          painter: _TexturePainter(
            dotColor: (isDark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF000000))
                .withSafeOpacity(_opacity.value * 0.06),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

// ── Page-enter reveal: usado pelo LumenGrainLoader.wrap ──────────────────────

class _PageEnterReveal extends StatefulWidget {
  final Widget child;
  const _PageEnterReveal({required this.child});

  @override
  State<_PageEnterReveal> createState() => _PageEnterRevealState();
}

class _PageEnterRevealState extends State<_PageEnterReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: LumenMotion.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: LumenMotion.curve);
    _fade  = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLUB TINT BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
//
// Wrap para telas de clube: aplica o grão canônico + um wash de cor extraído
// da capa do livro atual (2.5% de opacidade), dando personalidade editorial
// a cada clube sem decoração arbitrária.
//
// Uso:
// ```dart
// body: LumenClubTintBackground(
//   coverUrl: club.currentBookCoverUrl,
//   child: ...,
// )
// ```
//
// Telas pessoais (Home, Perfil) usam LumenTexturedBackground diretamente,
// sem tint — a diferenciação por cor é reservada ao espaço de clube.

/// Constante de opacidade do tint de cor da capa.
/// 0.025 → ~2.5 % — apenas um "wash de papel levemente tingido".
const _kClubTintOpacity = 0.025;

class LumenClubTintBackground extends StatefulWidget {
  final Widget child;

  /// URL da capa do livro atual do clube. Quando nulo, comporta-se como
  /// [LumenTexturedBackground] puro — sem tint de cor.
  final String? coverUrl;

  const LumenClubTintBackground({
    super.key,
    required this.child,
    this.coverUrl,
  });

  @override
  State<LumenClubTintBackground> createState() =>
      _LumenClubTintBackgroundState();
}

class _LumenClubTintBackgroundState extends State<LumenClubTintBackground> {
  Color? _tintColor;
  String? _lastUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeExtract();
  }

  @override
  void didUpdateWidget(LumenClubTintBackground old) {
    super.didUpdateWidget(old);
    if (old.coverUrl != widget.coverUrl) _maybeExtract();
  }

  Future<void> _maybeExtract() async {
    final url = widget.coverUrl;
    if (url == null || url == _lastUrl) return;
    _lastUrl = url;

    try {
      final provider = NetworkImage(url);
      final scheme = await ColorScheme.fromImageProvider(provider: provider);
      if (mounted && _lastUrl == url) {
        setState(() => _tintColor = scheme.primary);
      }
    } catch (_) {
      // Falha silenciosa — cai no grão puro.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tintColor;

    if (tint == null) {
      // Ainda carregando ou sem capa — grão puro sem flash de cor.
      return LumenTexturedBackground(child: widget.child);
    }

    return ColoredBox(
      color: tint.withSafeOpacity(_kClubTintOpacity),
      child: LumenTexturedBackground(child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HALL DA FAMA — pódio em barra, fechamento de ciclo
// ─────────────────────────────────────────────────────────────────────────────

/// Modelo mínimo para um finalista do pódio.
class LumenPodiumEntry {
  final String name;
  final String? avatarUrl;
  final int checkinDays; // dias com check-in — mesma métrica do ranking
  final int position;    // 1, 2 ou 3

  const LumenPodiumEntry({
    required this.name,
    this.avatarUrl,
    required this.checkinDays,
    required this.position,
  });
}

/// Pódio de 3 barras para fechamento de ciclo — 2º | 1º | 3º (meio mais alto).
///
/// Cores neutras apenas: 1º usa `onSurface` cheio, 2º e 3º usam `textSecondary`
/// com opacidade reduzida. Nunca ouro/prata/bronze.
/// Só deve aparecer quando `closeReadingCycle()` rodou — não durante ciclo ativo.
///
/// ```dart
/// LumenHallOfFamePodium(entries: [entry1st, entry2nd, entry3rd])
/// ```
class LumenHallOfFamePodium extends StatelessWidget {
  /// Exatamente 3 entradas: posição 1, 2 e 3 (qualquer ordem — o widget ordena).
  final List<LumenPodiumEntry> entries;

  const LumenHallOfFamePodium({super.key, required this.entries})
      : assert(entries.length == 3, 'LumenHallOfFamePodium requer exatamente 3 entradas');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final secondary = isDark ? LumenColors.inkSecondaryInverse : LumenColors.inkSecondary;

    // Ordena: 1, 2, 3
    final sorted = [...entries]..sort((a, b) => a.position.compareTo(b.position));
    final first  = sorted[0]; // posição 1
    final second = sorted[1]; // posição 2
    final third  = sorted[2]; // posição 3

    final maxDays = entries.map((e) => e.checkinDays).reduce(math.max);

    // Altura máxima da barra (px) — 1º sempre tem essa altura
    const double maxH = 100;

    double barHeight(int days) =>
        maxDays == 0 ? 20 : (days / maxDays * maxH).clamp(20, maxH);

    Color barColor(int position) {
      if (position == 1) return onSurface;
      if (position == 2) return secondary;
      return secondary.withSafeOpacity(0.55);
    }

    Widget column(LumenPodiumEntry e) {
      final h = barHeight(e.checkinDays);
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Foto no topo da barra
          _LumenAvatar(name: e.name, avatarUrl: e.avatarUrl, radius: 16),
          const SizedBox(height: 6),
          // Nome
          SizedBox(
            width: 70,
            child: Text(
              e.name,
              style: LumenType.mono(size: 10, color: secondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Número de dias
          Text(
            '${e.checkinDays}',
            style: LumenType.mono(
              size: 11,
              color: e.position == 1 ? onSurface : secondary,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          // Barra
          Container(
            width: 44,
            height: h,
            decoration: BoxDecoration(
              color: barColor(e.position),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LumenSpace.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          column(second), // 2º — esquerda
          const SizedBox(width: LumenSpace.lg),
          column(first),  // 1º — centro (mais alto)
          const SizedBox(width: LumenSpace.lg),
          column(third),  // 3º — direita
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALIAS DE MIGRAÇÃO — substituir por LumenTheme após migração completa
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Use [LumenTheme] diretamente.
@Deprecated('Use LumenTheme.light() / LumenTheme.dark()')
abstract final class ReadLogTheme {
  static ThemeData light() => LumenTheme.light();
  static ThemeData dark()  => LumenTheme.dark();
}

/// @deprecated Use [LumenColors] diretamente.
@Deprecated('Use LumenColors.*')
typedef ReadLogColors = LumenColors;

/// @deprecated Use [LumenType] diretamente.
@Deprecated('Use LumenType.*')
typedef ReadLogType = LumenType;
