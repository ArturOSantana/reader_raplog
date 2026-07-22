import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

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
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(20),
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
                  color: AppColors.warmGold,
                  borderRadius: BorderRadius.circular(8),
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
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Minhas estatísticas · ReadLog',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xAAFFFFFF),
                        height: 1.3,
                      ),
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
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆 ', style: TextStyle(fontSize: 14)),
                Text(
                  '$totalBooks ${totalBooks == 1 ? 'livro lido' : 'livros lidos'} no total',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
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
        color: AppColors.warmGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            '$streak ${streak == 1 ? 'dia' : 'dias'} de sequência!',
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A18),
              height: 1.2,
            ),
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xAAFFFFFF),
              letterSpacing: 0.3,
            ),
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
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
