import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _heatmapProvider =
    FutureProvider.family<Map<String, int>, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchChallengeHeatmap(challengeId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Heatmap de um desafio — lista os dias mais ativos em texto, sem grid
/// colorido estilo GitHub.
class ChallengeHeatmapScreen extends ConsumerWidget {
  final ClubChallenge challenge;
  final String? coverUrl;

  const ChallengeHeatmapScreen({
    super.key,
    required this.challenge,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(_heatmapProvider(challenge.id));

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: LumenColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.title,
              style: LumenType.display(
                size: 15,
                color: LumenColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              'Leitura diária',
              style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_heatmapProvider(challenge.id)),
        child: heatmapAsync.when(
          loading: () => const Center(
            child: LumenGrainLoader(),
          ),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (heatmap) => _HeatmapBody(
            challenge: challenge,
            heatmap: heatmap,
          ),
        ),
      ),
    ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HeatmapBody extends StatelessWidget {
  final ClubChallenge challenge;
  final Map<String, int> heatmap;

  const _HeatmapBody({required this.challenge, required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final days = _allDays(challenge.startsAt, challenge.endsAt);
    final totalPages = heatmap.values.fold(0, (a, b) => a + b);
    final activeDays = days.where((d) => (heatmap[_key(d)] ?? 0) > 0).length;
    final fmt = NumberFormat.decimalPattern('pt_BR');

    // Dias mais ativos — ordena desc, toma top 10
    final topDays = days
        .where((d) => (heatmap[_key(d)] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (heatmap[_key(b)] ?? 0).compareTo(heatmap[_key(a)] ?? 0));
    final top = topDays.take(10).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Resumo do desafio ─────────────────────────────────────────────
        Text(
          fmt.format(totalPages),
          style: LumenType.display(
            size: 42,
            color: LumenColors.ink,
            weight: FontWeight.w400,
          ),
        ),
        Text(
          '${challenge.goalType.unit} lidos no total',
          style: LumenType.mono(
            size: 11,
            color: LumenColors.inkMuted,
          ).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        Text(
          '$activeDays de ${days.length} dias com leitura',
          style: LumenType.mono(size: 12, color: LumenColors.inkGhost),
        ),
        const SizedBox(height: 36),

        // ── Dias mais ativos ──────────────────────────────────────────────
        if (top.isEmpty)
          Text(
            'Nenhum dia com leitura registrada.',
            style: LumenType.mono(size: 13, color: LumenColors.inkMuted),
          )
        else ...[
          Text(
            'DIAS MAIS ATIVOS',
            style: LumenType.mono(
              size: 10,
              color: LumenColors.inkGhost,
            ).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 12),
          ...top.expand((d) => [
                _DayRow(
                  date: d,
                  value: heatmap[_key(d)] ?? 0,
                  unit: challenge.goalType.unit,
                  maxValue: heatmap[_key(top.first)] ?? 1,
                ),
                const Divider(height: 1, color: LumenColors.hairline),
              ]),
        ],
      ],
    );
  }

  static String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static List<DateTime> _allDays(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var cur = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(endDay)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }
}

// ── Linha de dia ──────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final DateTime date;
  final int value;
  final String unit;
  final int maxValue;

  const _DayRow({
    required this.date,
    required this.value,
    required this.unit,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat("d 'de' MMM", 'pt_BR');
    final fmtNum = NumberFormat.decimalPattern('pt_BR');
    final barWidth = maxValue > 0 ? (value / maxValue) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          // Data
          SizedBox(
            width: 80,
            child: Text(
              fmtDate.format(date),
              style: LumenType.mono(size: 12, color: LumenColors.inkMuted),
            ),
          ),
          // Barra monocromática proporcional
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 2,
                    color: LumenColors.hairline,
                  ),
                  Container(
                    height: 2,
                    width: constraints.maxWidth * barWidth,
                    color: LumenColors.ink,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(width: 12),
          // Valor
          Text(
            '${fmtNum.format(value)} $unit',
            style: LumenType.mono(
              size: 12,
              color: LumenColors.ink,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
