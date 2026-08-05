import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../widgets/share_stats_sheet.dart';
import '../../../goals/presentation/widgets/goal_achievement_card.dart';

final _dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchDailyStats(),
    sessionRepo.fetchStreak(),
    sessionRepo.fetchHeatmap(days: 365),
    bookRepo.fetchAll(),
    sessionRepo.fetchPeriodStats(period: 'week'),
    sessionRepo.fetchPeriodStats(period: 'month'),
    sessionRepo.fetchPeriodStats(period: 'year'),
    goalRepo.fetchAll(),
  ]);

  return {
    'daily': results[0] as Map<String, dynamic>,
    'streak': (results[1] as num?)?.toInt() ?? 0,
    'heatmap': results[2] as List<Map<String, dynamic>>,
    'books': results[3],
    'week': results[4] as Map<String, dynamic>,
    'month': results[5] as Map<String, dynamic>,
    'year': results[6] as Map<String, dynamic>,
    'goals': results[7] as List<Goal>,
  };
});

final _calendarMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardDataProvider);

    return LumenTexturedBackground(
      child: Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? LumenColors.canvas : ReadLogColors.surface,
      body: data.when(
        loading: () => const SkelScreenList(count: 8),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (d) {
          final daily = d['daily'] as Map<String, dynamic>;
          final streak = d['streak'] as int;
          final heatmap = d['heatmap'] as List<Map<String, dynamic>>;
          final books = d['books'] as List;
          final week = d['week'] as Map<String, dynamic>;
          final month = d['month'] as Map<String, dynamic>;
          final year = d['year'] as Map<String, dynamic>;
          final goals = d['goals'] as List<Goal>;

          final readBooks = books.where((b) {
            try {
              return (b as dynamic).status.dbValue == 'read';
            } catch (_) {
              return false;
            }
          }).length;

          final todayMinutes =
              (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages =
              (daily['total_pages'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            color: ReadLogColors.brass,
            onRefresh: () => ref.refresh(_dashboardDataProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ReadLogPageHeader(
                    kicker: 'PAINEL',
                    title: 'Estatísticas',
                    actions: [
                      IconButton(
                        icon: Icon(Icons.share_rounded,
                            size: 20,
                    color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                        tooltip: 'Compartilhar estatísticas',
                        onPressed: () {
                          final user = ref.read(currentUserProvider);
                          final userName =
                              (user?.userMetadata?['full_name'] as String?) ??
                              user?.email ??
                              '';
                          showShareStatsSheet(
                            context: context,
                            streak: streak,
                            weekMinutes:
                                (week['total_minutes'] as num?)?.toInt() ?? 0,
                            weekPages:
                                (week['total_pages'] as num?)?.toInt() ?? 0,
                            monthMinutes:
                                (month['total_minutes'] as num?)?.toInt() ?? 0,
                            monthPages:
                                (month['total_pages'] as num?)?.toInt() ?? 0,
                            monthBooks: readBooks,
                            totalBooks: readBooks,
                            userName: userName,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Hoje ─────────────────────────────────────────────
                      _SectionLabel(label: 'Hoje'),
                      const SizedBox(height: 12),
                      _SummaryGrid(
                        streak: streak,
                        todayMinutes: todayMinutes,
                        todayPages: todayPages,
                        readBooks: readBooks,
                      ),

                      // ── Missões ────────────────────────────────────────────
                      if (goals.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionLabel(label: 'Missões'),
                        const SizedBox(height: 12),
                        _GoalProgressCard(
                          goals: goals,
                          todayMinutes: todayMinutes,
                          todayPages: todayPages,
                          yearlyBooksRead: readBooks,
                          monthStats: month,
                        ),
                      ],

                      // ── Esta semana ───────────────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Esta semana'),
                      const SizedBox(height: 12),
                      _PeriodStats(data: week, showBooks: false),

                      // ── Este mês ──────────────────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Este mês'),
                      const SizedBox(height: 12),
                      _PeriodStats(
                          data: month, showBooks: true, books: books),

                      // ── Este ano ──────────────────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Este ano'),
                      const SizedBox(height: 12),
                      _PeriodStats(
                          data: year, showBooks: true, books: books),

                      // ── Calendário ────────────────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Calendário de leitura'),
                      const SizedBox(height: 12),
                      _StreakCalendarWidget(
                          heatmap: heatmap, streak: streak),

                      // ── Atividade (heatmap) ───────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Atividade — 365 dias'),
                      const SizedBox(height: 12),
                      ReadLogReadingHeatmap(
                        data: {
                          for (final e in heatmap)
                            (e['date'] as String? ?? ''): (e['minutes'] as num?)?.toInt() ?? 0,
                        },
                      ),

                      // ── Destaques ─────────────────────────────────────────
                      const SizedBox(height: 28),
                      _SectionLabel(label: 'Destaques'),
                      const SizedBox(height: 12),
                      _HighlightsWidget(heatmap: heatmap, year: year),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    )
    );
  }
}

// ── Rótulo de seção ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: ReadLogType.display(
                size: 17, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? LumenColors.hairlineDark
                : LumenColors.hairline,
          ),
        ),
      ],
    );
  }
}

// ── Grid de resumo diário ────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final int streak;
  final int todayMinutes;
  final int todayPages;
  final int readBooks;

  const _SummaryGrid({
    required this.streak,
    required this.todayMinutes,
    required this.todayPages,
    required this.readBooks,
  });

  @override
  Widget build(BuildContext context) {
    final hours = todayMinutes ~/ 60;
    final mins = todayMinutes % 60;
    final timeLabel =
        hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _GridTile(
          label: 'Sequência',
          value: '$streak',
          unit: streak == 1 ? 'dia' : 'dias',
          accentColor: streak > 0 ? ReadLogColors.stamp : ReadLogColors.sage,
        ),
        _GridTile(
          label: 'Hoje',
          value: timeLabel,
          unit: 'lidos',
          accentColor: ReadLogColors.brass,
        ),
        _GridTile(
          label: 'Páginas',
          value: '$todayPages',
          unit: 'hoje',
          accentColor: ReadLogColors.sage,
        ),
        _GridTile(
          label: 'Livros lidos',
          value: '$readBooks',
          unit: 'total',
          accentColor: ReadLogColors.charcoal,
        ),
      ],
    );
  }
}

// ── Tile de estatística ───────────────────────────────────────────────────────

class _GridTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;

  const _GridTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? LumenColors.canvasElevated : LumenColors.surface,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: isDark ? LumenColors.hairlineDark : LumenColors.hairline,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Aba de cor no topo
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: ReadLogType.mono(
                      size: 20,
                      weight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal)),
              Text(
                '$label · $unit',
                style: ReadLogType.mono(
                    size: 9,
                    color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkMutedInverse : LumenColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Cards de meta ────────────────────────────────────────────────────────────

class _GoalProgressCard extends StatelessWidget {
  final List<Goal> goals;
  final int todayMinutes;
  final int todayPages;
  final int yearlyBooksRead;
  final Map<String, dynamic> monthStats;

  const _GoalProgressCard({
    required this.goals,
    required this.todayMinutes,
    required this.todayPages,
    required this.yearlyBooksRead,
    required this.monthStats,
  });

  int _current(Goal goal) {
    switch (goal.type) {
      case GoalType.dailyMinutes:
        return todayMinutes;
      case GoalType.dailyPages:
        return todayPages;
      case GoalType.yearlyBooks:
        return yearlyBooksRead;
      case GoalType.monthlyPages:
        return (monthStats['total_pages'] as num?)?.toInt() ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: goals.map((goal) {
        final current = _current(goal);
        final target = goal.targetValue;
        final progress = (current / target).clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final done = current >= target;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? LumenColors.canvasElevated : LumenColors.surface,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: isDark ? LumenColors.hairlineDark : LumenColors.hairline,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Aba lateral — stamp se feita, sage se em progresso
              Container(
                width: 5,
                height: 72,
                decoration: BoxDecoration(
                  color: done ? ReadLogColors.stamp : ReadLogColors.sage,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.type.label,
                              style: ReadLogType.display(
                                  size: 13, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                            ),
                          ),
                          if (done)
                            _ShareGoalButton(
                                goal: goal, currentValue: current)
                          else
                            Text(
                              '$current / $target ${goal.type.unit}',
                              style: ReadLogType.mono(
                                  size: 10,
                                  color: isDark
                                      ? LumenColors.inkMutedInverse
                                      : ReadLogColors.charcoal
                                          .withValues(alpha: 0.55)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? LumenColors.canvasVariant
                              : LumenColors.surfaceSubtle,
                          color: done
                              ? ReadLogColors.stamp
                              : ReadLogColors.brass,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            done
                                ? '✓ Missão concluída!'
                                : '$percent% concluído',
                            style: ReadLogType.mono(
                              size: 9,
                              color: done
                                  ? ReadLogColors.stamp
                                  : ReadLogColors.sage,
                            ),
                          ),
                          if (!done)
                            Text(
                              'Faltam ${target - current} ${goal.type.unit}',
                              style: ReadLogType.mono(
                                  size: 9,
                                  color: isDark
                                      ? LumenColors.inkGhostInverse
                                      : ReadLogColors.charcoal
                                          .withValues(alpha: 0.4)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Botão de compartilhar meta ────────────────────────────────────────────────

class _ShareGoalButton extends StatelessWidget {
  final Goal goal;
  final int currentValue;

  const _ShareGoalButton(
      {required this.goal, required this.currentValue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShareSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: LumenColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
              color: ReadLogColors.stamp.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: ReadLogColors.stamp),
            const SizedBox(width: 4),
            Text(
              'Concluída',
              style: ReadLogType.mono(
                size: 10,
                weight: FontWeight.w600,
                color: ReadLogColors.stamp,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.share_outlined,
                size: 12, color: ReadLogColors.stamp),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _GoalShareSheet(goal: goal, currentValue: currentValue),
    );
  }
}

class _GoalShareSheet extends StatefulWidget {
  final Goal goal;
  final int currentValue;

  const _GoalShareSheet(
      {required this.goal, required this.currentValue});

  @override
  State<_GoalShareSheet> createState() => _GoalShareSheetState();
}

class _GoalShareSheetState extends State<_GoalShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(pngBytes,
          name: 'readlog_meta.png', mimeType: 'image/png');

      final goalLabel = widget.goal.type.label.toLowerCase();
      final unit = widget.goal.type.unit;

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Atingi minha meta de $goalLabel: '
              '${widget.currentValue} $unit — registrado no ReadLog!',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ReadLogColors.ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding:
          const EdgeInsets.only(top: 16, bottom: 32, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: ReadLogColors.brassLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Compartilhar conquista',
            style: ReadLogType.display(
                size: 20, color: ReadLogColors.cream),
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            key: _cardKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: GoalAchievementCard(
                goal: widget.goal,
                currentValue: widget.currentValue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _shareAsImage,
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ReadLogColors.cream),
                    )
                  : const Icon(Icons.share_outlined, size: 18),
              label: Text(
                  _sharing ? 'Compartilhando…' : 'Compartilhar como imagem'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estatísticas de período ──────────────────────────────────────────────────

class _PeriodStats extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showBooks;
  final List<dynamic> books;

  const _PeriodStats({
    required this.data,
    this.showBooks = false,
    this.books = const [],
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (data['total_minutes'] as num?)?.toInt() ?? 0;
    final pages = (data['total_pages'] as num?)?.toInt() ?? 0;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeLabel =
        hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    int? readBooks;
    int? startedBooks;
    if (showBooks && books.isNotEmpty) {
      readBooks = books.where((b) {
        try {
          return (b as dynamic).status.dbValue == 'read';
        } catch (_) {
          return false;
        }
      }).length;
      startedBooks = books.where((b) {
        try {
          final s = (b as dynamic).status.dbValue as String;
          return s == 'reading' || s == 'read' || s == 'abandoned';
        } catch (_) {
          return false;
        }
      }).length;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _GridTile(
            label: 'Tempo',
            value: timeLabel,
            unit: 'total',
            accentColor: ReadLogColors.brass),
        _GridTile(
            label: 'Páginas',
            value: '$pages',
            unit: 'lidas',
            accentColor: ReadLogColors.sage),
        if (showBooks && readBooks != null)
          _GridTile(
              label: 'Concluídos',
              value: '$readBooks',
              unit: 'livros',
              accentColor: ReadLogColors.stamp),
        if (showBooks && startedBooks != null)
          _GridTile(
              label: 'Iniciados',
              value: '$startedBooks',
              unit: 'livros',
              accentColor: ReadLogColors.charcoal),
      ],
    );
  }
}

// ── Calendário de leitura ────────────────────────────────────────────────────

class _StreakCalendarWidget extends ConsumerWidget {
  final List<Map<String, dynamic>> heatmap;
  final int streak;

  const _StreakCalendarWidget(
      {required this.heatmap, required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_calendarMonthProvider);
    final activeDays = <String>{};
    for (final d in heatmap) {
      final date = d['date'] as String?;
      final mins = (d['total_minutes'] as num?)?.toInt() ?? 0;
      if (date != null && mins > 0) { activeDays.add(date); }
    }

    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    final startOffset = (firstDay.weekday - 1) % 7;
    final monthLabel = '${_monthName(month.month)} ${month.year}';

    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final readDaysThisMonth =
        activeDays.where((d) => d.startsWith(monthStr)).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? LumenColors.canvasElevated : LumenColors.surface,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: isDark ? LumenColors.hairlineDark : LumenColors.hairline,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navegação de mês
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkMutedInverse : LumenColors.inkMuted,
                onPressed: () {
                  ref.read(_calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1);
                },
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: ReadLogType.display(
                      size: 14, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: (month.year == today.year &&
                        month.month == today.month)
                    ? LumenColors.hairline
                    : LumenColors.inkMuted,
                onPressed: month.year == today.year &&
                        month.month == today.month
                    ? null
                    : () {
                        ref.read(_calendarMonthProvider.notifier).state =
                            DateTime(month.year, month.month + 1);
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cabeçalho dos dias da semana
          Row(
            children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: ReadLogType.mono(
                              size: 10,
                              weight: FontWeight.w600,
                              color: isDark
                                  ? LumenColors.inkMutedInverse
                                  : LumenColors.ink.withValues(alpha: 0.4)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startOffset) { return const SizedBox(); }
              final day = index - startOffset + 1;
              final dateStr =
                  '$monthStr-${day.toString().padLeft(2, '0')}';
              final isActive = activeDays.contains(dateStr);
              final isToday = today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              final isFuture =
                  DateTime(month.year, month.month, day).isAfter(today);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? ReadLogColors.stamp
                      : isFuture
                          ? Colors.transparent
                          : isDark
                              ? LumenColors.canvasVariant
                              : LumenColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: ReadLogColors.brass, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: ReadLogType.mono(
                      size: 11,
                      weight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? LumenColors.inkInverse
                          : isFuture
                              ? isDark
                                  ? LumenColors.hairlineDark
                                  : LumenColors.hairline
                              : isDark
                                  ? LumenColors.inkMutedInverse
                                  : LumenColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          // Rodapé: chips de resumo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalendarChip(
                icon: Icons.calendar_today_outlined,
                label:
                    '$readDaysThisMonth ${readDaysThisMonth == 1 ? 'dia' : 'dias'} lidos',
              ),
              _CalendarChip(
                icon: Icons.local_fire_department,
                label:
                    '$streak ${streak == 1 ? 'dia' : 'dias'} seguidos',
                highlight: streak > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ][month - 1];
}

class _CalendarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _CalendarChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? ReadLogColors.stamp
        : Theme.of(context).brightness == Brightness.dark
            ? LumenColors.inkMutedInverse
            : LumenColors.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: ReadLogType.mono(size: 10, color: color)),
      ],
    );
  }
}

// ── Destaques do período ──────────────────────────────────────────────────────

class _HighlightsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> heatmap;
  final Map<String, dynamic> year;

  const _HighlightsWidget(
      {required this.heatmap, required this.year});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? bestDay;
    for (final d in heatmap) {
      final mins = (d['total_minutes'] as num?)?.toInt() ?? 0;
      if (bestDay == null ||
          mins > ((bestDay['total_minutes'] as num?)?.toInt() ?? 0)) {
        bestDay = d;
      }
    }

    final activeDays = heatmap
        .where(
            (d) => ((d['total_minutes'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final totalMinutes = (year['total_minutes'] as num?)?.toInt() ?? 0;
    final avgMinutes =
        activeDays > 0 ? (totalMinutes / activeDays).round() : 0;

    final bestMins = (bestDay?['total_minutes'] as num?)?.toInt() ?? 0;
    final bestHours = bestMins ~/ 60;
    final bestMinsRem = bestMins % 60;
    final bestLabel = bestHours > 0
        ? '${bestHours}h ${bestMinsRem}min'
        : '${bestMinsRem}min';

    final avgHours = avgMinutes ~/ 60;
    final avgMinsRem = avgMinutes % 60;
    final avgLabel = avgHours > 0
        ? '${avgHours}h ${avgMinsRem}min'
        : '${avgMinsRem}min';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? LumenColors.canvasElevated : LumenColors.surface,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: isDark ? LumenColors.hairlineDark : LumenColors.hairline,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _HighlightRow(
            icon: Icons.emoji_events_outlined,
            label: 'Melhor dia',
            value: bestDay != null
                ? '$bestLabel (${bestDay['date']})'
                : '—',
            isFirst: true,
          ),
          _HighlightRow(
            icon: Icons.trending_up_outlined,
            label: 'Média por dia ativo',
            value: activeDays > 0 ? avgLabel : '—',
          ),
          _HighlightRow(
            icon: Icons.check_circle_outline,
            label: 'Dias com leitura (ano)',
            value:
                '$activeDays ${activeDays == 1 ? 'dia' : 'dias'}',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 16, color: ReadLogColors.brass),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: ReadLogType.mono(
                        size: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? LumenColors.inkMutedInverse
                            : LumenColors.ink.withValues(alpha: 0.7))),
              ),
              Text(value,
                  style: ReadLogType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal)),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? LumenColors.hairlineDark
                  : LumenColors.hairline,
              indent: 16,
              endIndent: 16),
      ],
    );
  }
}

