import 'package:flutter/material.dart';
import '../../../../theme/readlog_theme.dart';

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
        color: ReadLogColors.ink,
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
                  color: ReadLogColors.brass,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Center(
                  child: Text(
                    '📚',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty ? userName : 'Leitor',
                      style: ReadLogType.display(
                          size: 14, color: ReadLogColors.cream),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Minhas estatísticas · ReadLog',
                      style: ReadLogType.mono(
                          size: 10,
                          color: ReadLogColors.cream.withValues(alpha: 0.55)),
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
                    _StatRow(icon: '⏱', text: _fmtTime(weekMinutes)),
                    _StatRow(icon: '📄', text: '$weekPages pág.'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBlock(
                  label: 'Este mês',
                  rows: [
                    _StatRow(icon: '⏱', text: _fmtTime(monthMinutes)),
                    _StatRow(icon: '📄', text: '$monthPages pág.'),
                    _StatRow(icon: '📖', text: '$monthBooks lidos'),
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
              color: ReadLogColors.cream.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                  color: ReadLogColors.cream.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$totalBooks ${totalBooks == 1 ? 'livro lido' : 'livros lidos'} no total',
                  style: ReadLogType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: ReadLogColors.cream),
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
        color: ReadLogColors.brass.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: ReadLogColors.brass.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 4),
          Text(
            '$streak ${streak == 1 ? 'dia' : 'dias'} de sequência',
            style: ReadLogType.display(
                size: 17, color: ReadLogColors.brassLight),
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
        color: ReadLogColors.cream.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ReadLogType.mono(
                size: 10,
                color: ReadLogColors.cream.withValues(alpha: 0.55)),
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
            style: ReadLogType.mono(
                size: 13,
                weight: FontWeight.w500,
                color: ReadLogColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
