// ReadLog — Novos Componentes do Design System v2
//
// Contém todos os novos widgets introduzidos no redesign:
//   • ReadLogPageHeader  — cabeçalho de capítulo (substitui AppBars)
//   • ReadLogChip        — chip genérico com variantes
//   • ReadLogEventStamp  — stamp contextual com variantes de evento
//   • ReadLogFeedCard    — card de atividade social
//   • ReadLogClubCard    — card de clube na listagem
//   • ReadLogSessionRibbon — fita de sessão ativa (global)
//   • ReadLogStoryStrip  — faixa de stories de leitura
//   • ReadLogReadingHeatmap — heatmap estilo GitHub
//   • ReadLogSectionRail — grade de seções do clube (tiles 4×N)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'readlog_theme.dart';

// Referência ao ScaffoldKey global — populada pelo main_shell ao inicializar.
// Evita dependência circular entre readlog_components e main_shell.
GlobalKey<ScaffoldState>? _appScaffoldKey;

/// Registra o ScaffoldKey do MainShell para uso pelo ReadLogPageHeader.
void registerAppScaffoldKey(GlobalKey<ScaffoldState> key) {
  _appScaffoldKey = key;
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG PAGE HEADER
// ─────────────────────────────────────────────────────────────────────────────

/// Cabeçalho de tela que imita cabeçalho de capítulo de livro.
/// Substitui o AppBar padrão nas telas de conteúdo.
///
/// Uso:
/// ```dart
/// ReadLogPageHeader(
///   kicker: 'SEÇÃO',
///   title: 'Clubes',
///   dark: false,
///   actions: [IconButton(...)],
/// )
/// ```
class ReadLogPageHeader extends StatelessWidget {
  final String kicker;
  final String title;

  /// true = fundo ink (dark), false = fundo paper (light)
  final bool dark;

  /// Widgets de ação exibidos no canto direito.
  final List<Widget> actions;

  /// Exibe o ícone de menu (≡) no canto esquerdo, abrindo o Drawer global.
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
    final bg     = dark ? ReadLogColors.ink   : ReadLogColors.paper;
    final fg     = dark ? ReadLogColors.cream  : ReadLogColors.charcoal;
    final accent = dark ? ReadLogColors.brass  : ReadLogColors.brass;
    final lineC  = dark ? ReadLogColors.inkLine : ReadLogColors.paperLine;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMenuButton) ...[
                GestureDetector(
                  onTap: () => _appScaffoldKey?.currentState?.openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 1),
                    child: Icon(Icons.menu, size: 20, color: fg.withValues(alpha: 0.75)),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  kicker.toUpperCase(),
                  style: ReadLogType.mono(
                    size: 10,
                    color: accent,
                  ).copyWith(letterSpacing: 2),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: ReadLogType.display(size: 28, color: fg, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 1,
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DottedLine(color: lineC),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends CustomPainter {
  final Color color;
  const _DottedLine({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const w = 2.0;
    const sp = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + w, 0), p);
      x += w + sp;
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG CHIP
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogChipVariant { defaults, selected, outline, stamp }

/// Chip genérico — substitui _GoalChip e chips de filtro por todo o app.
///
/// Animação 180ms cross-fade de bg + border ao mudar [isSelected].
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
    final sel = isSelected || variant == ReadLogChipVariant.selected;
    final isStamp = variant == ReadLogChipVariant.stamp;
    final isOutline = variant == ReadLogChipVariant.outline;

    final Color bg = isStamp
        ? (sel ? ReadLogColors.stamp : ReadLogColors.stamp.withValues(alpha: 0.12))
        : sel
            ? ReadLogColors.charcoal
            : Colors.transparent;

    final Color border = isStamp
        ? ReadLogColors.stamp
        : isOutline
            ? ReadLogColors.paperDeep
            : sel
                ? ReadLogColors.charcoal
                : ReadLogColors.paperDeep;

    final Color fg = isStamp
        ? ReadLogColors.cream
        : sel
            ? ReadLogColors.cream
            : ReadLogColors.charcoal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(3),
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
              style: ReadLogType.mono(size: 12, color: fg, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG EVENT STAMP
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogEventStampVariant { checkIn, finished, milestone, badge, challenge }

/// Stamp contextual com variantes de evento.
/// Extensão do ReadLogStamp original — adiciona ícone central + cor por variante.
///
/// [size]: 40 (feed inline), 64 (grade conquistas), 96 (destaque).
/// [seedHash]: int para rotação pseudoaleatória ±8° (ex: event.id.hashCode).
class ReadLogEventStamp extends StatelessWidget {
  final ReadLogEventStampVariant variant;
  final double size;
  final int seedHash;

  /// Sobrescreve o label padrão da variante.
  final String? labelOverride;

  /// Sobrescreve o valor central (milestone: "75%", badge: "🏆").
  final String? valueOverride;

  const ReadLogEventStamp({
    super.key,
    required this.variant,
    this.size = 64,
    this.seedHash = 0,
    this.labelOverride,
    this.valueOverride,
  });

  static const _configs = <ReadLogEventStampVariant, _StampConfig>{
    ReadLogEventStampVariant.checkIn:   _StampConfig(Icons.bookmark_added_outlined, 'SESSÃO',    ReadLogColors.sage),
    ReadLogEventStampVariant.finished:  _StampConfig(Icons.check,                  'CONCLUÍDO', ReadLogColors.stamp),
    ReadLogEventStampVariant.milestone: _StampConfig(Icons.flag_outlined,          'MARCO',     ReadLogColors.brass),
    ReadLogEventStampVariant.badge:     _StampConfig(Icons.emoji_events_outlined,  'SELO',      ReadLogColors.stamp),
    ReadLogEventStampVariant.challenge: _StampConfig(Icons.local_fire_department_outlined, 'DESAFIO', ReadLogColors.warning),
  };

  double get _rotation {
    final rng = math.Random(seedHash);
    return (rng.nextDouble() * 16 - 8); // ±8°
  }

  @override
  Widget build(BuildContext context) {
    final cfg   = _configs[variant]!;
    final color = cfg.color;
    final label = (labelOverride ?? cfg.label).toUpperCase();
    final value = valueOverride;

    return Transform.rotate(
      angle: _rotation * math.pi / 180,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _StampRingPainter(color: color),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cfg.icon, size: size * 0.28, color: color),
                if (value != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: ReadLogType.stampLabel(size: size * 0.13, color: color),
                  ),
                ],
                const SizedBox(height: 1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: ReadLogType.stampLabel(size: size * 0.10, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StampConfig {
  final IconData icon;
  final String label;
  final Color color;
  const _StampConfig(this.icon, this.label, this.color);
}

class _StampRingPainter extends CustomPainter {
  final Color color;
  const _StampRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1.5, solid);

    final dashed = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const n = 32;
    const step = 2 * math.pi / n;
    final inner = radius - 7;
    for (int i = 0; i < n; i++) {
      final a = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: inner),
        a, step * 0.5, false, dashed,
      );
    }
  }

  @override
  bool shouldRepaint(_StampRingPainter o) => o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG FEED CARD
// ─────────────────────────────────────────────────────────────────────────────

/// Card de atividade social (check-in, marco, selo, story).
/// Aba lateral de 6px colorida pelo tipo de evento.
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

  static const _tabColors = <ReadLogEventStampVariant, Color>{
    ReadLogEventStampVariant.checkIn:   ReadLogColors.sage,
    ReadLogEventStampVariant.finished:  ReadLogColors.stamp,
    ReadLogEventStampVariant.milestone: ReadLogColors.brass,
    ReadLogEventStampVariant.badge:     ReadLogColors.stamp,
    ReadLogEventStampVariant.challenge: ReadLogColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final tabColor = _tabColors[eventVariant] ?? ReadLogColors.brass;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: ReadLogColors.paper,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              // Aba lateral esquerda
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: tabColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              // Conteúdo
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stamp sobreposto (translate negativo via Transform)
                        Transform.translate(
                          offset: const Offset(-6, -6),
                          child: ReadLogEventStamp(
                            variant: eventVariant,
                            size: 40,
                            seedHash: seedHash,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: ReadLogType.mono(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: ReadLogColors.charcoal,
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: ReadLogType.mono(
                                  size: 10,
                                  color: ReadLogColors.charcoal.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Texto principal
                    Text(
                      text,
                      style: ReadLogType.display(
                        size: 15,
                        weight: FontWeight.w600,
                        color: ReadLogColors.charcoal,
                      ),
                    ),
                    // Citação opcional
                    if (quote != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: ReadLogColors.paperDeep, width: 2),
                          ),
                        ),
                        child: Text(
                          '\u201c$quote\u201d',
                          style: ReadLogType.quote(
                            size: 13,
                            color: ReadLogColors.charcoal.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                    // Rodapé de reações
                    if (likes != null || comments != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (likes != null) _Reaction('❤', likes!),
                          if (likes != null) const SizedBox(width: 12),
                          if (comments != null) _Reaction('💬', comments!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reaction extends StatelessWidget {
  final String emoji;
  final int count;
  const _Reaction(this.emoji, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: ReadLogType.mono(
            size: 11,
            color: ReadLogColors.charcoal.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG CLUB CARD
// ─────────────────────────────────────────────────────────────────────────────

enum ReadLogClubStatus { active, vacation, archived }

/// Card de clube na lista /clubs.
class ReadLogClubCard extends StatelessWidget {
  final String clubName;
  final String currentBookTitle;
  final String currentBookAuthor;
  final double progress; // 0..1
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

  Color get _tabColor {
    switch (status) {
      case ReadLogClubStatus.active:   return ReadLogColors.sage;
      case ReadLogClubStatus.vacation: return ReadLogColors.brass;
      case ReadLogClubStatus.archived: return ReadLogColors.charcoal.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg      = isDark ? ReadLogColors.inkAlt  : ReadLogColors.paper;
    final coverBg     = isDark ? ReadLogColors.ink      : ReadLogColors.paperDeep;
    final onCard      = isDark ? ReadLogColors.cream    : ReadLogColors.charcoal;
    final onCardMuted = onCard.withValues(alpha: 0.65);
    final progressBg  = isDark
        ? ReadLogColors.cream.withValues(alpha: 0.12)
        : ReadLogColors.paperDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(3),
        elevation: 2,
        shadowColor: ReadLogColors.paperShadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              // Aba lateral
              Container(
                width: 6,
                height: 112,
                decoration: BoxDecoration(
                  color: _tabColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3),
                  ),
                ),
              ),
              // Capa placeholder (72×112)
              Container(
                width: 72,
                height: 112,
                color: coverBg,
                child: Center(
                  child: Icon(Icons.menu_book_outlined,
                      size: 28, color: onCard.withValues(alpha: 0.55)),
                ),
              ),
              // Conteúdo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              clubName,
                              style: ReadLogType.display(
                                size: 15,
                                weight: FontWeight.w600,
                                color: onCard,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOwner)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.workspace_premium,
                                  size: 12, color: ReadLogColors.brass),
                            ),
                        ],
                      ),
                      Text(
                        '$currentBookTitle · $currentBookAuthor',
                        style: ReadLogType.mono(
                          size: 10,
                          color: onCardMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: progressBg,
                          color: ReadLogColors.stamp,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.group_outlined,
                              size: 11, color: onCardMuted),
                          const SizedBox(width: 3),
                          Text(
                            '$memberCount',
                            style: ReadLogType.mono(size: 10, color: onCardMuted),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.local_fire_department_outlined,
                              size: 11, color: ReadLogColors.stamp),
                          const SizedBox(width: 3),
                          Text(
                            '$streakDays d',
                            style: ReadLogType.mono(size: 10, color: onCardMuted),
                          ),
                          if (nextMeeting != null) ...[
                            const Spacer(),
                            Text(
                              nextMeeting!,
                              style: ReadLogType.mono(
                                size: 10,
                                color: ReadLogColors.sageDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG SESSION RIBBON
// ─────────────────────────────────────────────────────────────────────────────

/// Fita horizontal que aparece no topo de qualquer tela com sessão ativa.
/// Altura 36px, background ink, texto cream.
/// O ponto sage pulsa. Toque leva para /session.
class ReadLogSessionRibbon extends StatefulWidget {
  final String bookTitle;
  final String elapsed; // ex: "00:24:17"
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
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.bookTitle.length > 20
        ? '${widget.bookTitle.substring(0, 18)}…'
        : widget.bookTitle;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 36,
        color: ReadLogColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            FadeTransition(
              opacity: _ctrl,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: ReadLogColors.sage,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$short · ${widget.elapsed}',
                style: ReadLogType.mono(
                  size: 11,
                  color: ReadLogColors.cream,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'ABRIR →',
              style: ReadLogType.stampLabel(
                size: 10,
                color: ReadLogColors.brassLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG STORY STRIP
// ─────────────────────────────────────────────────────────────────────────────

/// Uma story na faixa.
class ReadLogStoryItem {
  final String label;
  final bool seen;
  final bool isSelf;
  /// ID do clube associado (null quando isSelf == true).
  final String? clubId;
  /// Quantidade de stories ativos no clube.
  final int storyCount;

  const ReadLogStoryItem({
    required this.label,
    this.seen = false,
    this.isSelf = false,
    this.clubId,
    this.storyCount = 0,
  });
}

/// Faixa horizontal de stories de leitura (24h).
/// Height 96px, retângulos 64×88 proporção de lombada.
class ReadLogStoryStrip extends StatelessWidget {
  final List<ReadLogStoryItem> items;
  final VoidCallback? onAddStory;
  final void Function(int index)? onStoryTap;

  const ReadLogStoryStrip({
    super.key,
    required this.items,
    this.onAddStory,
    this.onStoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: item.isSelf ? onAddStory : () => onStoryTap?.call(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 88,
                      decoration: BoxDecoration(
                        color: item.isSelf
                            ? ReadLogColors.cream.withValues(alpha: 0.12)
                            : ReadLogColors.inkAlt,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: item.isSelf
                              ? ReadLogColors.cream.withValues(alpha: 0.3)
                              : item.seen
                                  ? ReadLogColors.paperDeep
                                  : ReadLogColors.stamp,
                          width: 1.5,
                        ),
                      ),
                      child: item.isSelf
                          ? const Center(
                              child: Icon(Icons.add,
                                  size: 24, color: ReadLogColors.cream),
                            )
                          : item.storyCount > 0
                              ? Center(
                                  child: Text(
                                    '${item.storyCount}',
                                    style: ReadLogType.mono(
                                      size: 22,
                                      color: ReadLogColors.cream
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.auto_stories_outlined,
                                    size: 22,
                                    color: ReadLogColors.cream
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                    ),
                    // Ponto de notificação quando há stories não vistos
                    if (!item.isSelf && !item.seen && item.storyCount > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: ReadLogColors.stamp,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ReadLogColors.ink,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 64,
                  child: Text(
                    item.label.toUpperCase(),
                    style: ReadLogType.mono(
                      size: 9,
                      color: ReadLogColors.cream.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG READING HEATMAP
// ─────────────────────────────────────────────────────────────────────────────

/// Heatmap tipo GitHub para /profile e /dashboard.
/// 7 linhas × [weeks] colunas. Cada célula 10×10, gap 2, radius 1px.
class ReadLogReadingHeatmap extends StatelessWidget {
  /// Map de data (yyyy-MM-dd) → número de minutos lidos.
  final Map<String, int> data;

  /// Número de semanas exibidas (padrão 26 = 6 meses).
  final int weeks;

  const ReadLogReadingHeatmap({
    super.key,
    required this.data,
    this.weeks = 26,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Domingo da semana mais recente
    final endSunday = now.subtract(Duration(days: now.weekday % 7));
    final startDay = endSunday.subtract(Duration(days: weeks * 7 - 1));

    // Máximo para normalização
    final maxMinutes = data.values.fold(0, math.max);

    const cellSize = 10.0;
    const gap = 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 7 * (cellSize + gap) - gap,
          width: weeks * (cellSize + gap) - gap,
          child: CustomPaint(
            painter: _HeatmapPainter(
              startDay: startDay,
              weeks: weeks,
              data: data,
              maxMinutes: maxMinutes,
              cellSize: cellSize,
              gap: gap,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('menos',
                style: ReadLogType.mono(
                    size: 9,
                    color: ReadLogColors.charcoal.withValues(alpha: 0.5))),
            const SizedBox(width: 4),
            ...List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: _cellColor(i / 4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )),
            const SizedBox(width: 4),
            Text('mais',
                style: ReadLogType.mono(
                    size: 9,
                    color: ReadLogColors.charcoal.withValues(alpha: 0.5))),
          ],
        ),
      ],
    );
  }

  static Color _cellColor(double norm) {
    if (norm <= 0) return ReadLogColors.paperDeep;
    if (norm < 0.25) return ReadLogColors.brass.withValues(alpha: 0.4);
    if (norm < 0.5)  return ReadLogColors.brass.withValues(alpha: 0.7);
    if (norm < 0.75) return ReadLogColors.stamp.withValues(alpha: 0.7);
    return ReadLogColors.stamp;
  }
}

class _HeatmapPainter extends CustomPainter {
  final DateTime startDay;
  final int weeks;
  final Map<String, int> data;
  final int maxMinutes;
  final double cellSize;
  final double gap;

  const _HeatmapPainter({
    required this.startDay,
    required this.weeks,
    required this.data,
    required this.maxMinutes,
    required this.cellSize,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        final day = startDay.add(Duration(days: w * 7 + d));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final minutes = data[key] ?? 0;
        final norm = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
        final color = ReadLogReadingHeatmap._cellColor(norm);

        final rect = Rect.fromLTWH(
          w * (cellSize + gap),
          d * (cellSize + gap),
          cellSize,
          cellSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1)),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter o) =>
      o.data != data || o.maxMinutes != maxMinutes;
}

// ─────────────────────────────────────────────────────────────────────────────
// READ LOG SECTION RAIL
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

/// Grade 4×N de tiles. Usada em /clubs/:id como "EXPLORAR".
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
    final bg     = dark ? ReadLogColors.inkAlt   : ReadLogColors.paper;
    final fg     = dark ? ReadLogColors.cream     : ReadLogColors.charcoal;
    final border = dark ? ReadLogColors.inkLine   : ReadLogColors.paperLine;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
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
                  borderRadius: BorderRadius.circular(3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(t.icon, size: 24, color: fg.withValues(alpha: 0.85)),
                    const SizedBox(height: 8),
                    Text(
                      t.label.toUpperCase(),
                      style: ReadLogType.mono(
                        size: 9,
                        color: fg.withValues(alpha: 0.7),
                        weight: FontWeight.w500,
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
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: ReadLogColors.stamp,
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
