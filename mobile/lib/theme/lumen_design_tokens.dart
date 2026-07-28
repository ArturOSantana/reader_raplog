/// Design System Tokens — Lumen Platform
///
/// Este arquivo centraliza todos os tokens de design que complementam
/// [ReadLogColors] e [ReadLogType] do readlog_theme.dart:
///
/// - [LumenSpacing]    — escala de espaçamento (4px grid)
/// - [LumenRadius]     — raios de borda
/// - [LumenElevation]  — shadows e elevação
/// - [LumenMotion]     — durações e curvas de animação
/// - [LumenBreakpoint] — breakpoints responsivos
/// - [LumenA11y]       — constantes de acessibilidade
/// - [LumenZIndex]     — z-index semântico (para web)
library;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESPAÇAMENTO — escala 4px
// ─────────────────────────────────────────────────────────────────────────────

/// Escala de espaçamento baseada em múltiplos de 4px.
///
/// ```dart
/// Padding(padding: EdgeInsets.all(LumenSpacing.md)) // 16px
/// ```
abstract final class LumenSpacing {
  LumenSpacing._();

  /// 2px — separador mínimo, bordas internas
  static const double xxs = 2;

  /// 4px — espaço mínimo entre elementos
  static const double xs = 4;

  /// 8px — espaço pequeno (icon + texto, chips)
  static const double sm = 8;

  /// 12px — espaço compacto (padding de lista, gap interno)
  static const double mdSm = 12;

  /// 16px — espaço padrão (padding de container, gap de card)
  static const double md = 16;

  /// 20px — padding de seção
  static const double mdLg = 20;

  /// 24px — padding de página, gap entre seções
  static const double lg = 24;

  /// 32px — separação entre blocos
  static const double xl = 32;

  /// 40px — separação grande
  static const double xxl = 40;

  /// 48px — espaço de header, top safe area
  static const double xxxl = 48;

  /// 64px — espaço de hero section
  static const double huge = 64;

  // ── Helpers de EdgeInsets ────────────────────────────────────────────────

  /// Padding horizontal padrão de página (24px cada lado)
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: lg);

  /// Padding padrão de card (16px todos os lados)
  static const EdgeInsets cardPadding =
      EdgeInsets.all(md);

  /// Padding de item de lista (horizontal 24, vertical 12)
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: mdSm);

  /// Padding interno de chip/tag (horizontal 8, vertical 4)
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: sm, vertical: xs);
}

// ─────────────────────────────────────────────────────────────────────────────
// RAIOS DE BORDA
// ─────────────────────────────────────────────────────────────────────────────

/// Raios de borda padronizados da plataforma.
///
/// O design do Lumen usa bordas sutis — nunca píldulas ou círculos em cards.
abstract final class LumenRadius {
  LumenRadius._();

  /// 2px — bordas quase retas (input de código, badges mono)
  static const double sharp = 2;

  /// 4px — padrão de botões e inputs
  static const double sm = 4;

  /// 6px — cards compactos
  static const double md = 6;

  /// 8px — cards padrão, dialogs
  static const double lg = 8;

  /// 12px — bottom sheets, modals
  static const double xl = 12;

  /// 16px — avatares, imagens de capa
  static const double xxl = 16;

  /// 999px — círculo perfeito (ícones, avatares)
  static const double full = 999;

  // ── BorderRadius helpers ─────────────────────────────────────────────────

  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  /// Apenas cantos superiores arredondados (bottom sheets)
  static const BorderRadius topXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ELEVATION / SHADOW
// ─────────────────────────────────────────────────────────────────────────────

/// Sombras padronizadas.
///
/// O Lumen usa elevação mínima — a hierarquia vem de cor e borda, não de sombra.
/// As sombras são reservadas para tooltips, popovers e modais.
abstract final class LumenElevation {
  LumenElevation._();

  /// Sem sombra — padrão para cards e surfaces
  static const List<BoxShadow> none = [];

  /// Sombra leve — hover state, cards interativos
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A1A1918),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Sombra padrão — dropdowns, popovers
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x141A1918),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A1A1918),
      blurRadius: 2,
      offset: Offset(0, 0),
    ),
  ];

  /// Sombra forte — modais, dialogs, menus
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1E1A1918),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A1A1918),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTION — duração e curvas
// ─────────────────────────────────────────────────────────────────────────────

/// Tokens de animação da plataforma.
///
/// Princípio: animações funcionais, nunca decorativas.
/// Curtas para micro-interações, médias para transições de estado.
abstract final class LumenMotion {
  LumenMotion._();

  // ── Durações ─────────────────────────────────────────────────────────────

  /// 80ms — micro-interações instantâneas (hover, press feedback)
  static const Duration instant = Duration(milliseconds: 80);

  /// 120ms — transições de estado rápido (toggle, badge, chip)
  static const Duration fast = Duration(milliseconds: 120);

  /// 200ms — padrão de componente (botão, input focus)
  static const Duration normal = Duration(milliseconds: 200);

  /// 300ms — transições de container (card expand, accordion)
  static const Duration medium = Duration(milliseconds: 300);

  /// 400ms — transições de página, modais
  static const Duration slow = Duration(milliseconds: 400);

  // ── Curvas ───────────────────────────────────────────────────────────────

  /// Easing padrão — entradas e saídas suaves
  static const Curve standard = Curves.easeInOut;

  /// Entrar em cena (slide in, fade in)
  static const Curve enter = Curves.easeOut;

  /// Sair de cena (slide out, fade out)
  static const Curve exit = Curves.easeIn;

  /// Efeito de mola — feedback de ação (success, error)
  static const Curve spring = Curves.elasticOut;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Transição padrão para animações de container.
  static AnimatedSwitcherTransitionBuilder get fadeTransition =>
      AnimatedSwitcher.defaultTransitionBuilder;
}

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS — responsividade
// ─────────────────────────────────────────────────────────────────────────────

/// Breakpoints de largura de tela da plataforma.
///
/// ```dart
/// final isDesktop = MediaQuery.of(context).size.width >= LumenBreakpoint.desktop;
/// ```
abstract final class LumenBreakpoint {
  LumenBreakpoint._();

  /// < 480px — mobile pequeno
  static const double mobileSmall = 480;

  /// < 768px — mobile padrão
  static const double mobile = 768;

  /// >= 768px — tablet / iPad
  static const double tablet = 768;

  /// >= 1024px — desktop / laptop
  static const double desktop = 1024;

  /// >= 1280px — desktop largo
  static const double desktopWide = 1280;

  /// Largura máxima de conteúdo centralizado
  static const double contentMaxWidth = 760;

  /// Largura máxima do painel admin
  static const double adminMaxWidth = 1100;
}

// ─────────────────────────────────────────────────────────────────────────────
// ACESSIBILIDADE
// ─────────────────────────────────────────────────────────────────────────────

/// Constantes de acessibilidade da plataforma (WCAG 2.1 AA).
abstract final class LumenA11y {
  LumenA11y._();

  /// Tamanho mínimo de área tocável (44x44px — Apple HIG / Material)
  static const double minTapTarget = 44;

  /// Tamanho mínimo de área tocável compacta (36x36px — usado com padding externo)
  static const double minTapTargetCompact = 36;

  /// Duração mínima para considerar um toque longo (acessibilidade)
  static const Duration longPressThreshold = Duration(milliseconds: 500);

  /// Escala de fonte mínima aceita pelo app (além disso, truncar com elegância)
  static const double minFontScale = 0.85;

  /// Escala de fonte máxima aceita pelo app sem quebrar layout
  static const double maxFontScale = 1.4;

  /// Contraste mínimo de cor (ratio 4.5:1 para texto normal — WCAG AA)
  /// Referência: usar ReadLogColors.ink sobre ReadLogColors.surface = ~14:1 ✓
  static const double minContrastRatio = 4.5;
}

// ─────────────────────────────────────────────────────────────────────────────
// Z-INDEX semântico (web / overlay stack)
// ─────────────────────────────────────────────────────────────────────────────

/// Z-order semântico para web e overlays.
///
/// Evita números mágicos espalhados pelo código.
abstract final class LumenZIndex {
  LumenZIndex._();

  static const int base      = 0;
  static const int elevated  = 10;
  static const int sticky    = 100;
  static const int overlay   = 200;
  static const int modal     = 300;
  static const int tooltip   = 400;
  static const int toast     = 500;
}
