// ReadLog — Design System v3 · Componentes
//
// Componentes de interface editorial:
//   • ReadLogPageHeader       — cabeçalho limpo, tipografia protagonista
//   • ReadLogChip             — chip minimal sem decoração
//   • ReadLogEventStamp       — indicador de evento (simplificado)
//   • ReadLogFeedCard         — card de atividade social limpo
//   • ReadLogClubCard         — card de clube editorial
//   • ReadLogSessionRibbon    — fita de sessão ativa
//   • ReadLogReadingHeatmap   — heatmap refinado
//   • ReadLogSectionRail      — grade de seções

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'readlog_theme.dart';

// Referência ao ScaffoldKey global
GlobalKey<ScaffoldState>? _appScaffoldKey;

void registerAppScaffoldKey(GlobalKey<ScaffoldState> key) {
  _appScaffoldKey = key;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE HEADER
// Cabeçalho de capítulo. Kicker overline + título Fraunces + linha divisória.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogPageHeader extends StatelessWidget {
  final String kicker;
  final String title;

  /// true = fundo canvas (dark), false = fundo surface (light)
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final useDark = dark || isDarkMode;

    final bg  = useDark ? ReadLogColors.canvas  : ReadLogColors.surface;
    final fg  = useDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fgM = useDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showMenuButton) ...[
                GestureDetector(
                  onTap: () => _appScaffoldKey?.currentState?.openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 1),
                    child: Icon(Icons.menu, size: 20, color: fgM),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  kicker.toUpperCase(),
                  style: ReadLogType.kicker(size: 10, color: fgM),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: ReadLogType.bookTitle(
              size: 28,
              weight: FontWeight.w500,
              color: fg,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: fg.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP
// Chip minimal — sem sombra, sem excesso de padding.
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogChipVariant { defaults, selected, outline, stamp }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel    = isSelected || variant == ReadLogChipVariant.selected;

    final fg = isDark
        ? (sel ? ReadLogColors.canvas : ReadLogColors.inkInverse)
        : (sel ? ReadLogColors.surface : ReadLogColors.ink);

    final bg = isDark
        ? (sel ? ReadLogColors.inkInverse : Colors.transparent)
        : (sel ? ReadLogColors.ink : Colors.transparent);

    final borderColor = isDark ? ReadLogColors.dividerDark : ReadLogColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: sel ? Colors.transparent : borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT INDICATOR
// Substitui o stamp por um indicador limpo: ícone + label inline.
// Mantém o tipo ReadLogEventStamp por compatibilidade.
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogEventStampVariant { checkIn, finished, milestone, badge, challenge }

class ReadLogEventStamp extends StatelessWidget {
  final ReadLogEventStampVariant variant;
  final double size;
  final int seedHash;
  final String? labelOverride;
  final String? valueOverride;

  const ReadLogEventStamp({
    super.key,
    required this.variant,
    this.size = 36,
    this.seedHash = 0,
    this.labelOverride,
    this.valueOverride,
  });

  static const _configs = <ReadLogEventStampVariant, _EventConfig>{
    ReadLogEventStampVariant.checkIn:
        _EventConfig(Icons.bookmark_outline, 'Sessão', ReadLogColors.progress),
    ReadLogEventStampVariant.finished:
        _EventConfig(Icons.check_circle_outline, 'Concluído', ReadLogColors.success),
    ReadLogEventStampVariant.milestone:
        _EventConfig(Icons.flag_outlined, 'Marco', ReadLogColors.inkMuted),
    ReadLogEventStampVariant.badge:
        _EventConfig(Icons.workspace_premium_outlined, 'Conquista', ReadLogColors.inkMuted),
    ReadLogEventStampVariant.challenge:
        _EventConfig(Icons.bolt_outlined, 'Desafio', ReadLogColors.warning),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg    = _configs[variant]!;
    final color  = isDark && cfg.color == ReadLogColors.progress
        ? ReadLogColors.progressLight
        : cfg.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(cfg.icon, size: size * 0.48, color: color),
      ),
    );
  }
}

class _EventConfig {
  final IconData icon;
  final String label;
  final Color color;
  const _EventConfig(this.icon, this.label, this.color);
}


// ─────────────────────────────────────────────────────────────────────────────
// FEED CARD
// Card editorial de atividade social. Sem stamp rotacionado, sem aba lateral.
// Hierarquia: avatar + nome + evento / texto / citação / reações.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogFeedCard extends StatelessWidget {
  final ReadLogEventStampVariant eventVariant;
  final String userName;
  final String timeAgo;
  final String text;
  final String? quote;
  final int? likes;
  final int? comments;
  final int seedHash;
  final VoidCallback? onTap;

  const ReadLogFeedCard({
    super.key,
    required this.eventVariant,
    required this.userName,
    required this.timeAgo,
    required this.text,
    this.quote,
    this.likes,
    this.comments,
    this.seedHash = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surface;
    final fg     = isDark ? ReadLogColors.inkInverse    : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabeçalho: indicador + meta ───────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ReadLogEventStamp(
                      variant: eventVariant,
                      size: 32,
                      seedHash: seedHash,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: fgMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Texto principal ───────────────────────────────────
                Text(
                  text,
                  style: ReadLogType.bookTitle(size: 15, color: fg),
                ),

                // ── Citação / trecho ──────────────────────────────────
                if (quote != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? ReadLogColors.canvasElevated
                          : ReadLogColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        left: BorderSide(
                          color: isDark
                              ? ReadLogColors.progressLight.withValues(alpha: 0.4)
                              : ReadLogColors.progress.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      '\u201c$quote\u201d',
                      style: ReadLogType.quote(
                        size: 14,
                        color: fgMut,
                      ),
                    ),
                  ),
                ],

                // ── Reações ──────────────────────────────────────────
                if (likes != null || comments != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (likes != null) ...[
                        Icon(Icons.favorite_border, size: 14, color: fgMut),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: fgMut,
                          ),
                        ),
                      ],
                      if (likes != null && comments != null)
                        const SizedBox(width: 16),
                      if (comments != null) ...[
                        Icon(Icons.chat_bubble_outline, size: 14, color: fgMut),
                        const SizedBox(width: 4),
                        Text(
                          '$comments',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: fgMut,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLUB CARD
// Card de clube — livro atual em destaque, metadados discretos.
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogClubStatus { active, vacation, archived }

class ReadLogClubCard extends StatelessWidget {
  final String clubName;
  final String currentBookTitle;
  final String currentBookAuthor;
  final double progress;
  final int memberCount;
  final int streakDays;
  final String? nextMeeting;
  final ReadLogClubStatus status;
  final bool isOwner;
  final VoidCallback? onTap;

  const ReadLogClubCard({
    super.key,
    required this.clubName,
    required this.currentBookTitle,
    required this.currentBookAuthor,
    required this.progress,
    required this.memberCount,
    required this.streakDays,
    this.nextMeeting,
    this.status = ReadLogClubStatus.active,
    this.isOwner = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surface;
    final fg     = isDark ? ReadLogColors.inkInverse    : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    final isActive = status == ReadLogClubStatus.active;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  clubName,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 14,
                                  color: fgMut,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$currentBookTitle · $currentBookAuthor',
                            style: ReadLogType.authorName(size: 13, color: fgMut),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: fg.withValues(alpha: 0.25),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Barra de progresso do livro atual
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: fg.withValues(alpha: 0.08),
                    color: isActive
                        ? (isDark ? ReadLogColors.progressLight : ReadLogColors.progress)
                        : fg.withValues(alpha: 0.2),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Icon(Icons.group_outlined, size: 13, color: fgMut),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: fgMut,
                      ),
                    ),
                    if (streakDays > 0) ...[
                      const SizedBox(width: 14),
                      Text(
                        '$streakDays dias seguidos',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isActive
                              ? (isDark ? ReadLogColors.progressLight : ReadLogColors.progress)
                              : fgMut,
                        ),
                      ),
                    ],
                    if (nextMeeting != null) ...[
                      const Spacer(),
                      Text(
                        nextMeeting!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: fgMut,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION RIBBON
// Fita horizontal: sessão ativa. Discreta, sem ornamentos.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogSessionRibbon extends StatefulWidget {
  final String bookTitle;
  final String elapsed;
  final VoidCallback onTap;

  const ReadLogSessionRibbon({
    super.key,
    required this.bookTitle,
    required this.elapsed,
    required this.onTap,
  });

  @override
  State<ReadLogSessionRibbon> createState() => _ReadLogSessionRibbonState();
}

class _ReadLogSessionRibbonState extends State<ReadLogSessionRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final fg     = isDark ? ReadLogColors.inkInverse    : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final border = isDark ? ReadLogColors.hairlineDark  : ReadLogColors.hairline;

    final short = widget.bookTitle.length > 24
        ? '${widget.bookTitle.substring(0, 22)}…'
        : widget.bookTitle;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          border: Border(bottom: BorderSide(color: border, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            FadeTransition(
              opacity: _ctrl,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark ? ReadLogColors.progressLight : ReadLogColors.progress,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                short,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              widget.elapsed,
              style: ReadLogType.mono(
                size: 12,
                weight: FontWeight.w500,
                color: fgMut,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Abrir',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? ReadLogColors.progressLight : ReadLogColors.progress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READING HEATMAP
// Heatmap limpo, paleta monocromática baseada no acento de progresso.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogReadingHeatmap extends StatelessWidget {
  final Map<String, int> data;
  final int weeks;

  const ReadLogReadingHeatmap({
    super.key,
    required this.data,
    this.weeks = 26,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final endSunday = now.subtract(Duration(days: now.weekday % 7));
    final startDay  = endSunday.subtract(Duration(days: weeks * 7 - 1));
    final maxMinutes = data.values.fold(0, math.max);

    const cellSize = 10.0;
    const gap = 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 7 * (cellSize + gap) - gap,
          width:  weeks * (cellSize + gap) - gap,
          child: CustomPaint(
            painter: _HeatmapPainter(
              startDay: startDay,
              weeks: weeks,
              data: data,
              maxMinutes: maxMinutes,
              cellSize: cellSize,
              gap: gap,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Menos',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: isDark ? ReadLogColors.inkGhostInverse : ReadLogColors.inkGhost,
              ),
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: _cellColor(i / 4, isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
            const SizedBox(width: 4),
            Text(
              'Mais',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: isDark ? ReadLogColors.inkGhostInverse : ReadLogColors.inkGhost,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _cellColor(double norm, bool isDark) {
    if (norm <= 0) {
      return isDark ? ReadLogColors.canvasElevated : ReadLogColors.surfaceSubtle;
    }
    final base = isDark ? ReadLogColors.progressLight : ReadLogColors.progress;
    if (norm < 0.25) return base.withValues(alpha: 0.25);
    if (norm < 0.5)  return base.withValues(alpha: 0.5);
    if (norm < 0.75) return base.withValues(alpha: 0.75);
    return base;
  }
}

class _HeatmapPainter extends CustomPainter {
  final DateTime startDay;
  final int weeks;
  final Map<String, int> data;
  final int maxMinutes;
  final double cellSize;
  final double gap;
  final bool isDark;

  const _HeatmapPainter({
    required this.startDay,
    required this.weeks,
    required this.data,
    required this.maxMinutes,
    required this.cellSize,
    required this.gap,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        final day = startDay.add(Duration(days: w * 7 + d));
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}'
            '-${day.day.toString().padLeft(2, '0')}';
        final minutes = data[key] ?? 0;
        final norm    = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
        final color   = ReadLogReadingHeatmap._cellColor(norm, isDark);

        final rect = Rect.fromLTWH(
          w * (cellSize + gap),
          d * (cellSize + gap),
          cellSize,
          cellSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter o) =>
      o.data != data || o.maxMinutes != maxMinutes || o.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION RAIL
// Grade de tiles para seções de clube. Visual limpo, sem borda pesada.
// ─────────────────────────────────────────────────────────────────────────────

class ReadLogSectionTile {
  final IconData icon;
  final String label;
  final bool hasBadge;
  final VoidCallback? onTap;

  const ReadLogSectionTile({
    required this.icon,
    required this.label,
    this.hasBadge = false,
    this.onTap,
  });
}

class ReadLogSectionRail extends StatelessWidget {
  final List<ReadLogSectionTile> tiles;
  final bool dark;

  const ReadLogSectionRail({
    super.key,
    required this.tiles,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = dark || Theme.of(context).brightness == Brightness.dark;
    final fgMut   = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final bg      = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final border  = isDark ? ReadLogColors.hairlineDark  : ReadLogColors.hairline;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return GestureDetector(
          onTap: t.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, size: 22, color: fgMut),
                    const SizedBox(height: 6),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: fgMut,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (t.hasBadge)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: ReadLogColors.progress,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
