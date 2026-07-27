import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../theme/readlog_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

// Mantém o índice do dia selecionado localmente
final _selectedDayProvider =
    StateProvider.family.autoDispose<int?, String>((ref, clubId) => null);

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubSocialHeatmapScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubSocialHeatmapScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(clubSocialHeatmapProvider(clubId));

    return Scaffold(
      backgroundColor: ReadLogColors.surface,
      appBar: AppBar(
        backgroundColor: ReadLogColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heatmap do clube',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              clubName,
              style: ReadLogType.mono(
                size: 11,
                color: ReadLogColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
      body: heatmapAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.progress),
        ),
        error: (e, _) => Center(
          child: Text(
            'Não foi possível carregar o heatmap.',
            style: ReadLogType.mono(
              size: 13,
              color: ReadLogColors.inkMuted,
            ),
          ),
        ),
        data: (days) => RefreshIndicator(
          color: ReadLogColors.progress,
          onRefresh: () async =>
              ref.invalidate(clubSocialHeatmapProvider(clubId)),
          child: _HeatmapBody(clubId: clubId, days: days),
        ),
      ),
    );
  }
}

// ── Corpo principal ───────────────────────────────────────────────────────────

class _HeatmapBody extends ConsumerWidget {
  final String clubId;
  final List<ClubHeatmapDay> days;

  const _HeatmapBody({required this.clubId, required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIdx = ref.watch(_selectedDayProvider(clubId));
    final selected = (selectedIdx != null && selectedIdx < days.length)
        ? days[selectedIdx]
        : null;

    // Estatísticas resumidas de todo o período
    final totalPages = days.fold<int>(0, (a, b) => a + b.totalPages);
    final totalMinutes = days.fold<int>(0, (a, b) => a + b.totalMinutes);
    final activeDays = days.where((d) => d.totalPages > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ── Resumo do período ─────────────────────────────────────────────
        _PeriodSummary(
          totalPages: totalPages,
          totalMinutes: totalMinutes,
          activeDays: activeDays,
          totalDays: days.length,
        ),
        const SizedBox(height: 24),

        // ── Grade do heatmap ──────────────────────────────────────────────
        Text(
          'ÚLTIMOS 30 DIAS',
          style: ReadLogType.mono(
            size: 9,
            color: ReadLogColors.inkGhost,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        _HeatmapGrid(
          clubId: clubId,
          days: days,
          selectedIdx: selectedIdx,
        ),

        // ── Legenda ───────────────────────────────────────────────────────
        const SizedBox(height: 12),
        _HeatmapLegend(),

        // ── Detalhe do dia selecionado ────────────────────────────────────
        if (selected != null) ...[
          const SizedBox(height: 20),
          _DayDetail(day: selected),
        ],

        // ── Lista dos dias mais ativos ─────────────────────────────────────
        const SizedBox(height: 24),
        Text(
          'DIAS MAIS ATIVOS',
          style: ReadLogType.mono(
            size: 9,
            color: ReadLogColors.inkGhost,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        _TopDaysList(days: days),
      ],
    );
  }
}

// ── Resumo do período ─────────────────────────────────────────────────────────

class _PeriodSummary extends StatelessWidget {
  final int totalPages;
  final int totalMinutes;
  final int activeDays;
  final int totalDays;

  const _PeriodSummary({
    required this.totalPages,
    required this.totalMinutes,
    required this.activeDays,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final pct = totalDays > 0
        ? (activeDays / totalDays * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ReadLogColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ReadLogColors.hairline),
      ),
      child: Row(
        children: [
          _SummaryPill(
            value: NumberFormat('#,###', 'pt_BR').format(totalPages),
            label: 'páginas',
          ),
          const SizedBox(width: 12),
          _SummaryPill(
            value: '${hours}h',
            label: 'de leitura',
          ),
          const SizedBox(width: 12),
          _SummaryPill(
            value: '$pct%',
            label: 'dos dias ativos',
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: ReadLogType.display(
              size: 20,
              color: ReadLogColors.ink,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: ReadLogType.mono(
              size: 10,
              color: ReadLogColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grade do heatmap ──────────────────────────────────────────────────────────

class _HeatmapGrid extends ConsumerWidget {
  final String clubId;
  final List<ClubHeatmapDay> days;
  final int? selectedIdx;

  const _HeatmapGrid({
    required this.clubId,
    required this.days,
    required this.selectedIdx,
  });

  // Paleta light: do quase-transparente ao verde-musgo intenso
  static const _cellColors = [
    Color(0xFFECEBE9), // 0 = sem leitura
    Color(0xFFCCDDD7), // 1
    Color(0xFF9CC2B9), // 2
    Color(0xFF5A9480), // 3
    Color(0xFF3D6B5A), // 4 = máximo
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(days.length, (i) {
        final day = days[i];
        final isSelected = selectedIdx == i;
        final color = _cellColors[day.intensity.clamp(0, 4)];

        return GestureDetector(
          onTap: () {
            final notifier = ref.read(_selectedDayProvider(clubId).notifier);
            notifier.state = isSelected ? null : i;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? ReadLogColors.progress
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Legenda ───────────────────────────────────────────────────────────────────

class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Menos',
          style: ReadLogType.mono(
              size: 10, color: ReadLogColors.inkGhost),
        ),
        const SizedBox(width: 6),
        ...List.generate(5, (i) {
          const colors = [
            Color(0xFFECEBE9),
            Color(0xFFCCDDD7),
            Color(0xFF9CC2B9),
            Color(0xFF5A9480),
            Color(0xFF3D6B5A),
          ];
          return Container(
            margin: const EdgeInsets.only(right: 3),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 6),
        Text(
          'Mais',
          style: ReadLogType.mono(
              size: 10, color: ReadLogColors.inkGhost),
        ),
      ],
    );
  }
}

// ── Detalhe do dia selecionado ────────────────────────────────────────────────

class _DayDetail extends StatelessWidget {
  final ClubHeatmapDay day;
  const _DayDetail({required this.day});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ReadLogColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ReadLogColors.progress.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmt.format(day.day).toUpperCase(),
            style: ReadLogType.mono(
              size: 10,
              color: ReadLogColors.progress,
            ).copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DetailPill(value: '${day.totalPages}', label: 'páginas'),
              const SizedBox(width: 10),
              _DetailPill(
                  value: '${day.totalMinutes ~/ 60}h ${day.totalMinutes % 60}min',
                  label: 'de leitura'),
              const SizedBox(width: 10),
              _DetailPill(
                  value: '${day.activeMembers}',
                  label: day.activeMembers == 1 ? 'leitor' : 'leitores'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final String value;
  final String label;
  const _DetailPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: ReadLogType.display(
            size: 16,
            color: ReadLogColors.ink,
            weight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: ReadLogType.mono(
            size: 10,
            color: ReadLogColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

// ── Lista dos dias mais ativos ────────────────────────────────────────────────

class _TopDaysList extends StatelessWidget {
  final List<ClubHeatmapDay> days;
  const _TopDaysList({required this.days});

  @override
  Widget build(BuildContext context) {
    final sorted = days.where((d) => d.totalPages > 0).toList()
      ..sort((a, b) => b.totalPages.compareTo(a.totalPages));
    final top = sorted.take(5).toList();

    if (top.isEmpty) {
      return Text(
        'Nenhum dia com leitura registrada ainda.',
        style: ReadLogType.mono(
          size: 12,
          color: ReadLogColors.inkMuted,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ReadLogColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ReadLogColors.hairline),
      ),
      child: Column(
        children: List.generate(top.length, (i) {
          final d = top[i];
          final fmt = DateFormat("d 'de' MMM", 'pt_BR');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Posição
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: ReadLogType.mono(
                      size: 12,
                      color: ReadLogColors.inkGhost,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Data
                Expanded(
                  child: Text(
                    fmt.format(d.day),
                    style: ReadLogType.mono(
                      size: 13,
                      color: ReadLogColors.ink,
                    ),
                  ),
                ),
                // Páginas
                Text(
                  '${d.totalPages} pág',
                  style: ReadLogType.mono(
                    size: 12,
                    color: ReadLogColors.progress,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                // Membros
                Text(
                  '${d.activeMembers} ${d.activeMembers == 1 ? 'leitor' : 'leitores'}',
                  style: ReadLogType.mono(
                    size: 11,
                    color: ReadLogColors.inkMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
