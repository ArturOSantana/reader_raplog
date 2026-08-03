import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

/// Card "Vocês já leram juntos" — métricas coletivas do clube.
/// Sem pílulas coloridas — dados como linhas separadas por Divider.
class ClubCollectiveStatsCard extends ConsumerWidget {
  final String clubId;

  const ClubCollectiveStatsCard({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(clubCollectiveStatsProvider(clubId));

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats == null || stats.totalSessions == 0) {
          return const SizedBox.shrink();
        }
        return _StatsBody(stats: stats);
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  final ClubCollectiveStats stats;

  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final myPct = stats.myPagesPct.toStringAsFixed(1);
    final hasContribution = stats.myPagesPct > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOCÊS JÁ LERAM JUNTOS',
          style: ReadLogType.mono(
            size: 10,
            color: ReadLogColors.inkGhost,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 12),

        // Número grande de páginas
        Text(
          stats.pagesFormatted,
          style: ReadLogType.display(
            size: 36,
            color: ReadLogColors.ink,
            weight: FontWeight.w400,
          ),
        ),
        Text(
          'páginas',
          style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
        ),
        const SizedBox(height: 16),

        // Linhas de detalhe — sem pílulas, sem cor
        const Divider(height: 1, color: ReadLogColors.hairline),
        _StatRow(label: 'Sessões', value: _fmt(stats.totalSessions)),
        const Divider(height: 1, color: ReadLogColors.hairline),
        _StatRow(label: 'Livros lidos', value: _fmt(stats.totalBooksRead)),
        const Divider(height: 1, color: ReadLogColors.hairline),
        _StatRow(label: 'Horas de leitura', value: '${stats.minutesToHours}h'),

        if (hasContribution) ...[
          const Divider(height: 1, color: ReadLogColors.hairline),
          _StatRow(
            label: 'Sua contribuição',
            value: '$myPct%',
            highlightValue: true,
          ),
        ],
      ],
    );
  }

  String _fmt(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlightValue;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlightValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
          ),
          Text(
            value,
            style: ReadLogType.mono(
              size: 12,
              color: highlightValue ? ReadLogColors.progress : ReadLogColors.ink,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
