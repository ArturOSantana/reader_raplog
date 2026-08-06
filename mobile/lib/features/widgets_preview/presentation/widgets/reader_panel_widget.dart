// reader_panel_widget.dart — Widget "Painel do Leitor" (destaque)
// Reúne livro atual, ofensiva, meta diária, próximo evento e frase.

import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';

class ReaderPanelWidget extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final int currentPage;
  final int totalPages;
  final int streakDays;
  final int todayPages;
  final int goalPages;
  final String? nextMeetingLabel; // ex: "Clube amanhã às 20h"
  final String quote;
  final String quoteAuthor;
  final VoidCallback? onTap;

  const ReaderPanelWidget({
    super.key,
    required this.bookTitle,
    required this.bookAuthor,
    required this.currentPage,
    required this.totalPages,
    required this.streakDays,
    required this.todayPages,
    required this.goalPages,
    this.nextMeetingLabel,
    required this.quote,
    required this.quoteAuthor,
    this.onTap,
  });

  double get _progress =>
      totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0;

  int get _pct => (_progress * 100).round();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: LumenColors.ink,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: LumenColors.brass.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Livro ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 16, color: LumenColors.brassLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookTitle,
                    style: LumenType.display(
                        size: 15, color: LumenColors.cream),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                bookAuthor,
                style:
                    LumenType.mono(size: 11, color: LumenColors.brassLight),
              ),
            ),
            const SizedBox(height: 10),
            // ── Barra de progresso ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 5,
                backgroundColor: LumenColors.cream.withValues(alpha: 0.1),
                color: LumenColors.brass,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'p. $currentPage / $totalPages · $_pct%',
              style: LumenType.mono(
                  size: 10,
                  color: LumenColors.cream.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 14),
            // ── Stats row ──────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.local_fire_department_outlined,
                    value: '$streakDays',
                    unit: streakDays == 1 ? 'dia' : 'dias',
                  ),
                  const _VDivider(),
                  _StatChip(
                    icon: Icons.flag_outlined,
                    value: '$todayPages/$goalPages',
                    unit: 'pgs hoje',
                  ),
                  if (nextMeetingLabel != null) ...[
                    const _VDivider(),
                    _StatChip(
                      icon: Icons.groups_outlined,
                      value: nextMeetingLabel!,
                      unit: '',
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Frase ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: LumenColors.brass.withValues(alpha: 0.5),
                      width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$quote"',
                    style: LumenType.display(
                      size: 12,
                      color: LumenColors.cream.withValues(alpha: 0.8),
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '— $quoteAuthor',
                    style: LumenType.mono(
                        size: 10,
                        color: LumenColors.brassLight
                            .withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final bool compact;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.unit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LumenColors.sage),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              compact ? value : '$value\n$unit',
              style: LumenType.mono(
                  size: 10, color: LumenColors.cream.withValues(alpha: 0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: LumenColors.cream.withValues(alpha: 0.12),
    );
  }
}
