import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// Atividade do clube ao longo do tempo — sem grade colorida estilo GitHub.
/// Os dados aparecem como texto: número grande + lista dos dias mais ativos.
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
              'Atividade do clube',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              clubName,
              style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
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
            'Não foi possível carregar os dados.',
            style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
          ),
        ),
        data: (days) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(clubSocialHeatmapProvider(clubId)),
          child: _HeatmapBody(days: days),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HeatmapBody extends StatelessWidget {
  final List<ClubHeatmapDay> days;

  const _HeatmapBody({required this.days});

  @override
  Widget build(BuildContext context) {
    final totalPages = days.fold<int>(0, (a, b) => a + b.totalPages);
    final totalMinutes = days.fold<int>(0, (a, b) => a + b.totalMinutes);
    final activeDays = days.where((d) => d.totalPages > 0).length;
    final fmt = NumberFormat.decimalPattern('pt_BR');

    // Dias mais ativos — ordena desc, toma top 5
    final topDays = days.where((d) => d.totalPages > 0).toList()
      ..sort((a, b) => b.totalPages.compareTo(a.totalPages));
    final top = topDays.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Resumo do período ─────────────────────────────────────────────
        Text(
          fmt.format(totalPages),
          style: ReadLogType.display(
            size: 42,
            color: ReadLogColors.ink,
            weight: FontWeight.w400,
          ),
        ),
        Text(
          'páginas nos últimos 30 dias',
          style: ReadLogType.mono(
            size: 11,
            color: ReadLogColors.inkMuted,
          ).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${totalMinutes ~/ 60}h',
              style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.inkMuted,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              '  ·  ',
              style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.inkGhost,
              ),
            ),
            Text(
              '$activeDays ${activeDays == 1 ? 'dia ativo' : 'dias ativos'} de ${days.length}',
              style: ReadLogType.mono(size: 12, color: ReadLogColors.inkGhost),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // ── Dias mais ativos ──────────────────────────────────────────────
        if (top.isEmpty)
          Text(
            'Nenhum dia com leitura registrada ainda.',
            style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
          )
        else ...[
          Text(
            'DIAS MAIS ATIVOS',
            style: ReadLogType.mono(
              size: 10,
              color: ReadLogColors.inkGhost,
            ).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 12),
          ...top.expand((d) => [
                _TopDayRow(day: d),
                const Divider(height: 1, color: ReadLogColors.hairline),
              ]),
        ],
      ],
    );
  }
}

// ── Linha de dia ──────────────────────────────────────────────────────────────

class _TopDayRow extends StatelessWidget {
  final ClubHeatmapDay day;

  const _TopDayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat("d 'de' MMM", 'pt_BR');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            fmtDate.format(day.day),
            style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
          ),
          Row(
            children: [
              Text(
                '${day.totalPages} pág',
                style: ReadLogType.mono(
                  size: 12,
                  color: ReadLogColors.progress,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${day.activeMembers} ${day.activeMembers == 1 ? 'leitor' : 'leitores'}',
                style: ReadLogType.mono(
                  size: 11,
                  color: ReadLogColors.inkGhost,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
