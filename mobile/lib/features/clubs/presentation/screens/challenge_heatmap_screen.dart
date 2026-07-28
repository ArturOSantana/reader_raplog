import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _heatmapProvider =
    FutureProvider.family<Map<String, int>, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchChallengeHeatmap(challengeId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengeHeatmapScreen extends ConsumerWidget {
  final ClubChallenge challenge;

  const ChallengeHeatmapScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final heatmapAsync = ref.watch(_heatmapProvider(challenge.id));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.title,
              style: AppTextStyles.titleMedium
                  .copyWith(color: cs.onSurface, fontSize: 15),
            ),
            Text(
              'Heatmap de leitura',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_heatmapProvider(challenge.id)),
        child: heatmapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (heatmap) => _HeatmapBody(
            challenge: challenge,
            heatmap: heatmap,
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
    // Gera todos os dias do desafio
    final days = _allDays(challenge.startsAt, challenge.endsAt);
    final maxVal = heatmap.values.fold(0, (a, b) => b > a ? b : a);

    // Série para o gráfico de linhas: páginas acumuladas
    final cumulativeSeries = _cumulativeSeries(days, heatmap);

    // Total de dias e dias com leitura
    final daysWithReading = days.where((d) {
      final k = _key(d);
      return (heatmap[k] ?? 0) > 0;
    }).length;
    final totalPages = heatmap.values.fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Estatísticas rápidas ──────────────────────────────────────────
        _StatsRow(
          totalDays: days.length,
          activeDays: daysWithReading,
          totalPages: totalPages,
          goalValue: challenge.goalValue,
          unit: challenge.goalType.unit,
        ),
        const SizedBox(height: 24),

        // ── Heatmap de quadradinhos ───────────────────────────────────────
        _SectionTitle(title: 'Calendário de leitura', icon: Icons.grid_view_outlined),
        const SizedBox(height: 12),
        _HeatmapGrid(days: days, heatmap: heatmap, maxVal: maxVal),
        const SizedBox(height: 8),
        _HeatmapLegend(maxVal: maxVal),
        const SizedBox(height: 28),

        // ── Gráfico de progresso acumulado ────────────────────────────────
        _SectionTitle(title: 'Progresso acumulado', icon: Icons.trending_up),
        const SizedBox(height: 12),
        _CumulativeChart(
          series: cumulativeSeries,
          goalValue: challenge.goalValue,
          totalDays: days.length,
        ),
        const SizedBox(height: 24),
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

  static List<FlSpot> _cumulativeSeries(
      List<DateTime> days, Map<String, int> heatmap) {
    final spots = <FlSpot>[];
    int cum = 0;
    for (int i = 0; i < days.length; i++) {
      final k = _key(days[i]);
      cum += heatmap[k] ?? 0;
      spots.add(FlSpot(i.toDouble(), cum.toDouble()));
    }
    return spots;
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalDays;
  final int activeDays;
  final int totalPages;
  final int goalValue;
  final String unit;

  const _StatsRow({
    required this.totalDays,
    required this.activeDays,
    required this.totalPages,
    required this.goalValue,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Row(
      children: [
        _StatChip(
          label: 'Dias lidos',
          value: '$activeDays/$totalDays',
          color: AppColors.forestGreen,
          surface: surface,
          border: border,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Total $unit',
          value: NumberFormat.compact(locale: 'pt_BR').format(totalPages),
          color: AppColors.warmGold,
          surface: surface,
          border: border,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Meta',
          value: NumberFormat.compact(locale: 'pt_BR').format(goalValue),
          color: AppColors.forestGreen,
          surface: surface,
          border: border,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color surface;
  final Color border;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelMedium.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: cs.onSurface,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Heatmap grid ──────────────────────────────────────────────────────────────

class _HeatmapGrid extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, int> heatmap;
  final int maxVal;

  const _HeatmapGrid({
    required this.days,
    required this.heatmap,
    required this.maxVal,
  });

  Color _cellColor(int val) {
    if (val <= 0) return AppColors.forestGreen.withValues(alpha: 0.08);
    if (maxVal <= 0) return AppColors.forestGreen.withValues(alpha: 0.6);
    final ratio = (val / maxVal).clamp(0.0, 1.0);
    return AppColors.forestGreen.withValues(alpha: 0.15 + ratio * 0.75);
  }

  @override
  Widget build(BuildContext context) {
    const cellSize = 28.0;
    const gap = 4.0;
    final fmt = DateFormat('MMM d', 'pt_BR');

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: days.map((d) {
        final k = DateFormat('yyyy-MM-dd').format(d);
        final val = heatmap[k] ?? 0;
        final isToday = DateUtils.isSameDay(d, DateTime.now());
        return Tooltip(
          message: '${fmt.format(d)}: $val',
          child: Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: _cellColor(val),
              borderRadius: BorderRadius.circular(4),
              border: isToday
                  ? Border.all(color: AppColors.warmGold, width: 1.5)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Legenda do heatmap ────────────────────────────────────────────────────────

class _HeatmapLegend extends StatelessWidget {
  final int maxVal;

  const _HeatmapLegend({required this.maxVal});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Menos', style: AppTextStyles.labelMedium.copyWith(fontSize: 10)),
        const SizedBox(width: 4),
        ...List.generate(5, (i) {
          final ratio = i / 4.0;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.forestGreen
                    .withValues(alpha: 0.08 + ratio * 0.82),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text('Mais', style: AppTextStyles.labelMedium.copyWith(fontSize: 10)),
      ],
    );
  }
}

// ── Gráfico de linha acumulada ────────────────────────────────────────────────

class _CumulativeChart extends StatelessWidget {
  final List<FlSpot> series;
  final int goalValue;
  final int totalDays;

  const _CumulativeChart({
    required this.series,
    required this.goalValue,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final maxY = (goalValue * 1.1).ceilToDouble();

    // Linha de meta (linha reta do zero ao goalValue)
    final goalLine = [
      FlSpot(0, 0),
      FlSpot((totalDays - 1).toDouble(), goalValue.toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (totalDays - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  NumberFormat.compact(locale: 'pt_BR').format(v),
                  style: AppTextStyles.labelMedium.copyWith(fontSize: 9),
                ),
              ),
            ),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            // Linha de meta (referência)
            LineChartBarData(
              spots: goalLine,
              isCurved: false,
              color: AppColors.warmGold.withValues(alpha: 0.6),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
            // Progresso real
            LineChartBarData(
              spots: series,
              isCurved: true,
              color: AppColors.forestGreen,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.forestGreen.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
