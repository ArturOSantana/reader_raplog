// lumen_compat.dart — Shims de compatibilidade para o período de migração.
//
// Este arquivo expõe aliases e widgets stub para que o código existente compile
// enquanto cada tela é migrada individualmente para os tokens Lumen canônicos.
//
// ⚠️  NADA NESTE ARQUIVO deve ser usado em código novo. ⚠️
// Todos os símbolos aqui são @deprecated e serão deletados junto com este
// arquivo ao final do passo 0-d da migração.
//
// Mapa de substituição:
//   AppColors.*         → LumenColors.*
//   AppTextStyles.*     → use LumenType.* ou Theme.of(ctx).textTheme
//   ReadLogPageHeader   → reescrever como AppBar + título editorial
//   ReadLogCatalogCard  → LumenBookRow (lista) ou LumenBookHero (hero único)
//   ReadLogChip         → tab-texto + sublinhado (nunca chip colorido)
//   ReadLogEventStamp   → texto inline (variant badge/challenge: remover)
//   ReadLogLeaderRow    → par label+value em Row separado por Divider
//   ReadLogStamp        → remover (gamificação proibida)
//   ReadLogReadingHeatmap → exibição textual + linha fina monocromática
//   ReadLogNotificationTile → LumenNotificationRow (a criar)

library;

import 'package:flutter/material.dart';
import 'lumen_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppColors — shim sobre LumenColors
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Use [LumenColors] diretamente.
@Deprecated('Use LumenColors.*')
abstract final class AppColors {
  AppColors._();

  static const forestGreen      = LumenColors.read;
  static const forestGreenLight = LumenColors.readLight;
  static const warmGold         = LumenColors.read;
  static const warmGoldLight    = LumenColors.readLight;
  static const offWhite         = LumenColors.surface;
  static const surface          = LumenColors.surface;
  static const surfaceVariant   = LumenColors.surfaceVariant;
  static const border           = LumenColors.hairline;
  static const textPrimary      = LumenColors.ink;
  static const textSecondary    = Color(0xFF5C5C4A);
  static const textMuted        = Color(0xFF9C9C8A);
  static const success          = LumenColors.read;
  static const error            = LumenColors.danger;
  static const warning          = LumenColors.warning;
  static const darkBackground   = LumenColors.canvas;
  static const darkSurface      = LumenColors.canvasVariant;
  static const darkSurfaceVariant = Color(0xFF243B2D);
  static const darkBorder       = Color(0xFF2E4A38);
  static const darkTextPrimary  = LumenColors.inkInverse;
  static const darkTextSecondary = LumenColors.readLight;
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextStyles — shim delegando para LumenType
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Use [LumenType] diretamente.
@Deprecated('Use LumenType.*')
abstract final class AppTextStyles {
  AppTextStyles._();

  static const displayLarge = TextStyle(
    fontFamily: 'Fraunces', fontSize: 32, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, height: 1.15,
  );
  static const displayMedium = TextStyle(
    fontFamily: 'Fraunces', fontSize: 24, fontWeight: FontWeight.w500,
    letterSpacing: -0.2, height: 1.2,
  );
  static const headlineMedium = TextStyle(
    fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const titleMedium = TextStyle(
    fontFamily: 'IBM Plex Mono', fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const bodyLarge = TextStyle(
    fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.55,
  );
  static const labelMedium = TextStyle(
    fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500,
    letterSpacing: 0.5, height: 1.4,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogChipVariant / ReadLogEventStampVariant — enums de compatibilidade
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Substituir por tab-texto + sublinhado.
@Deprecated('Substituir por tab-texto; ver spec Lumen')
enum ReadLogChipVariant { defaults, selected, outline, stamp }

/// @deprecated Variantes badge/challenge: remover. checkIn/milestone: texto inline.
@Deprecated('Substituir por texto inline; ver spec Lumen')
enum ReadLogEventStampVariant { checkIn, finished, milestone, badge, challenge }

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogPageHeader — stub de compatibilidade
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Reescrever como AppBar + título editorial usando LumenType.
@Deprecated('Reescrever a tela com AppBar padrão + LumenType.bookTitle')
class ReadLogPageHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final bool dark;
  final List<Widget> actions;
  final bool showMenuButton;

  const ReadLogPageHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.dark = false,
    this.actions = const [],
    this.showMenuButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = dark ||
        Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? LumenColors.canvas : LumenColors.surface;
    final fg   = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final muted = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showMenuButton)
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 2),
                child: LumenIcon('home', size: 20, color: fg),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: LumenType.kicker(size: 10, color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: LumenType.bookTitle(size: 24, color: fg),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogChip — stub de compatibilidade
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Substituir por tab-texto + sublinhado. Chips coloridos violam spec.
@Deprecated('Substituir por tab-texto; ver spec Lumen')
class ReadLogChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final ReadLogChipVariant variant;

  const ReadLogChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.variant = ReadLogChipVariant.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final selected = isSelected || variant == ReadLogChipVariant.selected;
    final fg = selected
        ? (isDark ? LumenColors.ink : LumenColors.inkInverse)
        : (isDark ? LumenColors.inkInverse : LumenColors.ink);
    final bg = selected
        ? (isDark ? LumenColors.inkInverse : LumenColors.ink)
        : Colors.transparent;
    final borderColor =
        isDark ? LumenColors.dividerDark : LumenColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LumenMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: selected ? Colors.transparent : borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: LumenType.mono(size: 12, color: fg),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogEventStamp — stub de compatibilidade (sem ícone/cor de gamificação)
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Substituir por texto inline. Variantes badge/challenge: remover.
@Deprecated('Substituir por texto inline; ver spec Lumen')
class ReadLogEventStamp extends StatelessWidget {
  final ReadLogEventStampVariant variant;
  final double size;
  final int seedHash;
  final String? labelOverride;
  final String? valueOverride;

  const ReadLogEventStamp({
    super.key,
    required this.variant,
    this.size = 52,
    this.seedHash = 0,
    this.labelOverride,
    this.valueOverride,
  });

  static const _labels = <ReadLogEventStampVariant, String>{
    ReadLogEventStampVariant.checkIn:   'Check-in',
    ReadLogEventStampVariant.finished:  'Concluído.',
    ReadLogEventStampVariant.milestone: 'Marco',
    ReadLogEventStampVariant.badge:     '',
    ReadLogEventStampVariant.challenge: '',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label  = labelOverride ?? _labels[variant] ?? '';
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label,
      style: LumenType.mono(
        size: 11,
        color: isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogLeaderRow — stub de compatibilidade (já editorial)
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Manter padrão — já é editorial. Renomear para LumenStatRow ao migrar.
@Deprecated('Renomear para LumenStatRow ao migrar a tela')
class ReadLogLeaderRow extends StatelessWidget {
  final String label;
  final String value;

  const ReadLogLeaderRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: LumenType.mono(
              size: 12,
              color: isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted,
            ),
          ),
          Text(
            value,
            style: LumenType.mono(
              size: 12,
              color: isDark ? LumenColors.inkInverse : LumenColors.ink,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogStamp — stub vazio (gamificação proibida)
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated REMOVER. Selos/medalhas violam a spec Lumen.
@Deprecated('REMOVER — gamificação proibida pela spec Lumen')
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
    this.color = LumenColors.ink,
    this.size = 80,
    this.rotationDeg = 0,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogReadingHeatmap — stub vazio (heatmap colorido proibido)
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated REESCREVER como exibição textual + linha fina monocromática.
@Deprecated('Reescrever como exibição textual; heatmap colorido viola spec')
class ReadLogReadingHeatmap extends StatelessWidget {
  final Map<String, int> data;
  final int weeks;

  const ReadLogReadingHeatmap({
    super.key,
    required this.data,
    this.weeks = 16,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogCatalogCard — stub de compatibilidade (migrar para LumenBookRow)
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Migrar para LumenBookRow (lista) ou LumenBookHero (hero único).
@Deprecated('Migrar para LumenBookRow ou LumenBookHero; ver spec Lumen')
class ReadLogCatalogCard extends StatelessWidget {
  final String title;
  final String author;
  final double progress;
  final Color tabColor;
  final VoidCallback? onTap;
  final String? coverUrl;
  final int? currentPage;
  final int? totalPages;

  const ReadLogCatalogCard({
    super.key,
    required this.title,
    required this.author,
    required this.progress,
    this.tabColor = LumenColors.ink,
    this.onTap,
    this.coverUrl,
    this.currentPage,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = progress.clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: LumenType.bookTitle(
                size: 16,
                color: isDark ? LumenColors.inkInverse : LumenColors.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              author,
              style: LumenType.authorName(
                size: 13,
                color: isDark
                    ? LumenColors.inkMutedInverse
                    : LumenColors.inkMuted,
              ),
            ),
            if (p > 0) ...[
              const SizedBox(height: 10),
              LumenReadingProgress(
                progress: p,
                label: currentPage != null && totalPages != null
                    ? 'pág. $currentPage de $totalPages'
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadLogNotificationTile — stub de compatibilidade
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Migrar para LumenNotificationRow ao refatorar a tela.
@Deprecated('Migrar para LumenNotificationRow; ver spec Lumen')
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
    final fg = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final muted = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: BoxDecoration(
                  color: LumenColors.read,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: LumenType.authorName(size: 13, color: fg)
                          .copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: LumenType.authorName(size: 12, color: muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(time, style: LumenType.mono(size: 10, color: muted)),
          ],
        ),
      ),
    );
  }
}
