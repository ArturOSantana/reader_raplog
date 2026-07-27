import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../theme/readlog_theme.dart';

/// Card "Vocês já leram juntos" — métricas coletivas do clube.
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
    final headStyle = ReadLogType.display(
      size: 13,
      color: ReadLogColors.inkMuted,
    );
    final bigStyle = ReadLogType.display(
      size: 28,
      color: ReadLogColors.ink,
      weight: FontWeight.w700,
    );
    final subStyle = ReadLogType.mono(
      size: 11,
      color: ReadLogColors.inkMuted,
    );
    final myPctStyle = ReadLogType.mono(
      size: 12,
      color: ReadLogColors.progress,
      weight: FontWeight.w600,
    );

    final myPct = stats.myPagesPct.toStringAsFixed(1);
    final hasContribution = stats.myPagesPct > 0;

    return Container(
      decoration: BoxDecoration(
        color: ReadLogColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ReadLogColors.hairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kicker
          Text('VOCÊS JÁ LERAM JUNTOS', style: headStyle),
          const SizedBox(height: 16),

          // Linha 1: Páginas
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stats.pagesFormatted, style: bigStyle),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('páginas', style: subStyle),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linha 2: Sessões e livros
          Row(
            children: [
              _StatPill(
                value: _fmt(stats.totalSessions),
                label: 'sessões',
              ),
              const SizedBox(width: 12),
              _StatPill(
                value: _fmt(stats.totalBooksRead),
                label: 'livros',
              ),
              const SizedBox(width: 12),
              _StatPill(
                value: '${stats.minutesToHours}h',
                label: 'de leitura',
              ),
            ],
          ),

          if (hasContribution) ...[
            const SizedBox(height: 14),
            Divider(color: ReadLogColors.hairline, height: 1),
            const SizedBox(height: 12),
            // Contribuição do usuário
            Row(
              children: [
                Text('Você contribuiu com ', style: subStyle),
                Text('$myPct%', style: myPctStyle),
                Text(' disso.', style: subStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;

  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ReadLogColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReadLogColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: ReadLogType.mono(
              size: 12,
              color: ReadLogColors.ink,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: ReadLogType.mono(
              size: 11,
              color: ReadLogColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
