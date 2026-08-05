import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ignore_for_file: deprecated_member_use

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor    = isDark ? LumenColors.inkInverse      : LumenColors.ink;
    final mutedColor  = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final ghostColor  = isDark ? LumenColors.inkGhostInverse : LumenColors.inkGhost;
    final hairline    = isDark ? LumenColors.hairlineDark    : LumenColors.hairline;

    final myPct = stats.myPagesPct.toStringAsFixed(1);
    final hasContribution = stats.myPagesPct > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOCÊS JÁ LERAM JUNTOS',
          style: ReadLogType.mono(
            size: 10,
            color: ghostColor,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 12),

        // Número grande de páginas
        Text(
          stats.pagesFormatted,
          style: ReadLogType.display(
            size: 36,
            color: inkColor,
            weight: FontWeight.w400,
          ),
        ),
        Text(
          'páginas',
          style: ReadLogType.mono(size: 11, color: mutedColor),
        ),
        const SizedBox(height: 16),

        // Linhas de detalhe — sem pílulas, sem cor
        Divider(height: 1, color: hairline),
        _StatRow(label: 'Sessões', value: _fmt(stats.totalSessions), isDark: isDark),
        Divider(height: 1, color: hairline),
        _StatRow(label: 'Livros lidos', value: _fmt(stats.totalBooksRead), isDark: isDark),
        Divider(height: 1, color: hairline),
        _StatRow(label: 'Horas de leitura', value: '${stats.minutesToHours}h', isDark: isDark),

        if (hasContribution) ...[
          Divider(height: 1, color: hairline),
          _StatRow(
            label: 'Sua contribuição',
            value: '$myPct%',
            highlightValue: true,
            isDark: isDark,
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
  final bool isDark;

  const _StatRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.highlightValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final inkColor   = isDark ? LumenColors.inkInverse      : LumenColors.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: ReadLogType.mono(size: 12, color: mutedColor),
          ),
          Text(
            value,
            style: ReadLogType.mono(
              size: 12,
              color: highlightValue ? LumenColors.read : inkColor,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
