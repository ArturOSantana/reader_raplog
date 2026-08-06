import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';

/// Card visual gerado para compartilhamento de estatísticas de leitura.
/// Deve ser envolvido em um [RepaintBoundary] identificado com [repaintKey]
/// para que o screenshot funcione.
class ShareStatsCard extends StatelessWidget {
  final int streak;
  final int weekMinutes;
  final int weekPages;
  final int monthMinutes;
  final int monthPages;
  final int monthBooks;
  final int totalBooks;
  final String userName;

  const ShareStatsCard({
    super.key,
    required this.streak,
    required this.weekMinutes,
    required this.weekPages,
    required this.monthMinutes,
    required this.monthPages,
    required this.monthBooks,
    required this.totalBooks,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LumenColors.ink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: LumenColors.brass,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Center(
                  child: Icon(Icons.menu_book_rounded, size: 18, color: LumenColors.paper),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty ? userName : 'Leitor',
                      style: LumenType.display(
                          size: 14, color: LumenColors.cream),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Minhas estatísticas · ReadLog',
                      style: LumenType.mono(
                          size: 10,
                          color: LumenColors.cream.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Streak em destaque
          _StreakBanner(streak: streak),

          const SizedBox(height: 16),

          // Grid de estatísticas
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Esta semana',
                  rows: [
                    _StatRow(icon: '◷', text: _fmtTime(weekMinutes)),
                    _StatRow(icon: '▪', text: '$weekPages pág.'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBlock(
                  label: 'Este mês',
                  rows: [
                    _StatRow(icon: '◷', text: _fmtTime(monthMinutes)),
                    _StatRow(icon: '▪', text: '$monthPages pág.'),
                    _StatRow(icon: '▸', text: '$monthBooks lidos'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Rodapé: total de livros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: LumenColors.cream.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                  color: LumenColors.cream.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$totalBooks ${totalBooks == 1 ? 'livro lido' : 'livros lidos'} no total',
                  style: LumenType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: LumenColors.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LumenColors.brass.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: LumenColors.brass.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 4),
          Text(
            '$streak ${streak == 1 ? 'dia' : 'dias'} de sequência',
            style: LumenType.display(
                size: 17, color: LumenColors.brassLight),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final List<_StatRow> rows;

  const _StatBlock({required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LumenColors.cream.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: LumenType.mono(
                size: 10,
                color: LumenColors.cream.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: r,
              )),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon;
  final String text;
  const _StatRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: LumenType.mono(
                size: 13,
                weight: FontWeight.w500,
                color: LumenColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
