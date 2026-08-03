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
          color: ReadLogColors.ink,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: ReadLogColors.brass.withValues(alpha: 0.35),
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
                    size: 16, color: ReadLogColors.brassLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookTitle,
                    style: ReadLogType.display(
                        size: 15, color: ReadLogColors.cream),
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
                    ReadLogType.mono(size: 11, color: ReadLogColors.brassLight),
              ),
            ),
            const SizedBox(height: 10),
            // ── Barra de progresso ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 5,
                backgroundColor: ReadLogColors.cream.withValues(alpha: 0.1),
                color: ReadLogColors.brass,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'p. $currentPage / $totalPages · $_pct%',
              style: ReadLogType.mono(
                  size: 10,
                  color: ReadLogColors.cream.withValues(alpha: 0.55)),
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
                      color: ReadLogColors.brass.withValues(alpha: 0.5),
                      width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$quote"',
                    style: ReadLogType.display(
                      size: 12,
                      color: ReadLogColors.cream.withValues(alpha: 0.8),
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '— $quoteAuthor',
                    style: ReadLogType.mono(
                        size: 10,
                        color: ReadLogColors.brassLight
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
          Icon(icon, size: 13, color: ReadLogColors.sage),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              compact ? value : '$value\n$unit',
              style: ReadLogType.mono(
                  size: 10, color: ReadLogColors.cream.withValues(alpha: 0.8)),
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
      color: ReadLogColors.cream.withValues(alpha: 0.12),
    );
  }
}
