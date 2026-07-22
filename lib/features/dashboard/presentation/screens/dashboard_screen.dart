import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import '../../../../core/shell/main_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';
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
    'streak': results[1] as int,
    'heatmap': results[2] as List<Map<String, dynamic>>,
    'books': results[3],
    'week': results[4] as Map<String, dynamic>,
    'month': results[5] as Map<String, dynamic>,
    'year': results[6] as Map<String, dynamic>,
    'goals': results[7] as List<Goal>,
  };
});

// Retorna o mês sendo exibido no calendário (ano, mês).
final _calendarMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
          tooltip: 'Abrir menu',
        ),
        title: const Text('Painel'),
        actions: [
          if (data.hasValue)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Compartilhar estatísticas',
              onPressed: () {
                final d = data.value!;
                final week = d['week'] as Map<String, dynamic>;
                final month = d['month'] as Map<String, dynamic>;
                final books = d['books'] as List;
                final streak = d['streak'] as int;

                final readBooks = books.where((b) {
                  try {
                    return (b as dynamic).status.dbValue == 'read';
                  } catch (_) {
                    return false;
                  }
                }).length;

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
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

          final todayMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;
          final yearlyBooksRead = readBooks;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_dashboardDataProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Hoje', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _SummaryGrid(
                  streak: streak,
                  todayMinutes: todayMinutes,
                  todayPages: todayPages,
                  readBooks: readBooks,
                ),
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Metas', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 12),
                  _GoalProgressCard(
                    goals: goals,
                    todayMinutes: todayMinutes,
                    todayPages: todayPages,
                    yearlyBooksRead: yearlyBooksRead,
                    monthStats: month,
                  ),
                ],
                const SizedBox(height: 28),
                Text('Esta semana', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _PeriodStats(data: week, showBooks: false),
                const SizedBox(height: 28),
                Text('Este mês', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _PeriodStats(data: month, showBooks: true, books: books),
                const SizedBox(height: 28),
                Text('Este ano', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _PeriodStats(data: year, showBooks: true, books: books),
                const SizedBox(height: 28),
                Text('Calendário de leitura', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _StreakCalendarWidget(heatmap: heatmap, streak: streak),
                const SizedBox(height: 28),
                Text('Atividade', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _HeatmapWidget(data: heatmap),
                const SizedBox(height: 28),
                Text('Destaques', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _HighlightsWidget(heatmap: heatmap, year: year),
              ],
            ),
          );
        },
      ),
    );
  }
}


/// Widget que exibe o progresso de cada meta configurada.
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

  /// Retorna o valor atual para comparar com a meta.
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
    return Column(
      children: goals.map((goal) {
        final current = _current(goal);
        final target = goal.targetValue;
        final progress = (current / target).clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final done = current >= target;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? AppColors.forestGreen : AppColors.border,
              width: done ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.type.label, style: AppTextStyles.titleMedium),
                  ),
                  if (done)
                    _ShareGoalButton(goal: goal, currentValue: current)
                  else
                    Text(
                      '$current / $target ${goal.type.unit}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done
                        ? AppColors.forestGreen
                        : AppColors.forestGreen.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    done ? '✓ Meta concluída!' : '$percent% concluído',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: done ? AppColors.forestGreen : AppColors.textMuted,
                      fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (!done)
                    Text(
                      'Faltam ${target - current} ${goal.type.unit}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Botão + sheet de compartilhamento da meta ─────────────────────────────

class _ShareGoalButton extends StatelessWidget {
  final Goal goal;
  final int currentValue;

  const _ShareGoalButton({required this.goal, required this.currentValue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShareSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.forestGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.forestGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.forestGreen),
            const SizedBox(width: 4),
            Text(
              'Concluída',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.share_outlined,
                size: 13, color: AppColors.forestGreen),
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
      builder: (_) => _GoalShareSheet(goal: goal, currentValue: currentValue),
    );
  }
}

class _GoalShareSheet extends StatefulWidget {
  final Goal goal;
  final int currentValue;

  const _GoalShareSheet({required this.goal, required this.currentValue});

  @override
  State<_GoalShareSheet> createState() => _GoalShareSheetState();
}

class _GoalShareSheetState extends State<_GoalShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        name: 'readlog_meta.png',
        mimeType: 'image/png',
      );

      final goalLabel = widget.goal.type.label.toLowerCase();
      final unit = widget.goal.type.unit;

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: '🎯 Atingi minha meta de $goalLabel: '
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
        color: Color(0xFF0F1A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alça
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text(
            'Compartilhar conquista',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Preview capturável
          RepaintBoundary(
            key: _cardKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _sharing ? null : _shareAsImage,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
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
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _GridTile(label: 'Sequência', value: '$streak dias'),
        _GridTile(label: 'Hoje', value: timeLabel),
        _GridTile(label: 'Páginas hoje', value: '$todayPages'),
        _GridTile(label: 'Livros lidos', value: '$readBooks'),
      ],
    );
  }
}

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
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

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
      crossAxisCount: showBooks ? 2 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _GridTile(label: 'Tempo', value: timeLabel),
        _GridTile(label: 'Páginas', value: '$pages'),
        if (showBooks && readBooks != null)
          _GridTile(label: 'Livros concluídos', value: '$readBooks'),
        if (showBooks && startedBooks != null)
          _GridTile(label: 'Livros iniciados', value: '$startedBooks'),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  final String label;
  final String value;

  const _GridTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          Text(value, style: AppTextStyles.displayMedium),
        ],
      ),
    );
  }
}

// ── Streak Calendar ──────────────────────────────────────────────────────────

class _StreakCalendarWidget extends ConsumerWidget {
  final List<Map<String, dynamic>> heatmap;
  final int streak;

  const _StreakCalendarWidget({required this.heatmap, required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_calendarMonthProvider);
    final activeDays = <String>{};
    for (final d in heatmap) {
      final date = d['date'] as String?;
      final mins = (d['total_minutes'] as num?)?.toInt() ?? 0;
      if (date != null && mins > 0) activeDays.add(date);
    }

    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // 0 = Mon … 6 = Sun (weekday - 1)
    final startOffset = (firstDay.weekday - 1) % 7;
    final monthLabel =
        '${_monthName(month.month)} ${month.year}';

    // Conta dias lidos neste mês
    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final readDaysThisMonth =
        activeDays.where((d) => d.startsWith(monthStr)).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header: naveg. de mês + streak badge
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref.read(_calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1);
                },
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
          const SizedBox(height: 8),
          // Dias da semana
          Row(
            children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: AppTextStyles.labelMedium
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startOffset) return const SizedBox();
              final day = index - startOffset + 1;
              final dateStr =
                  '$monthStr-${day.toString().padLeft(2, '0')}';
              final isActive = activeDays.contains(dateStr);
              final isToday = today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              final isFuture = DateTime(month.year, month.month, day)
                  .isAfter(today);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.forestGreen
                      : isFuture
                          ? Colors.transparent
                          : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(
                          color: AppColors.warmGold, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? Colors.white
                          : isFuture
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Rodapé: dias lidos e sequência atual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalendarChip(
                icon: Icons.calendar_today_outlined,
                label: '$readDaysThisMonth ${readDaysThisMonth == 1 ? 'dia' : 'dias'} lidos',
              ),
              _CalendarChip(
                icon: Icons.local_fire_department,
                label: '$streak ${streak == 1 ? 'dia' : 'dias'} seguidos',
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
    final color =
        highlight ? AppColors.warmGold : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.labelMedium.copyWith(color: color)),
      ],
    );
  }
}

// ── Highlights (destaques do período) ────────────────────────────────────────

class _HighlightsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> heatmap;
  final Map<String, dynamic> year;

  const _HighlightsWidget({required this.heatmap, required this.year});

  @override
  Widget build(BuildContext context) {
    // Melhor dia (mais minutos)
    Map<String, dynamic>? bestDay;
    for (final d in heatmap) {
      final mins = (d['total_minutes'] as num?)?.toInt() ?? 0;
      if (bestDay == null ||
          mins > ((bestDay['total_minutes'] as num?)?.toInt() ?? 0)) {
        bestDay = d;
      }
    }

    final activeDays =
        heatmap.where((d) => ((d['total_minutes'] as num?)?.toInt() ?? 0) > 0).length;

    final totalMinutes =
        (year['total_minutes'] as num?)?.toInt() ?? 0;
    final avgMinutes =
        activeDays > 0 ? (totalMinutes / activeDays).round() : 0;

    final bestMins =
        (bestDay?['total_minutes'] as num?)?.toInt() ?? 0;
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _HighlightRow(
            icon: Icons.emoji_events_outlined,
            label: 'Melhor dia',
            value: bestDay != null ? '$bestLabel (${bestDay['date']})' : '—',
          ),
          const Divider(height: 20, color: AppColors.border),
          _HighlightRow(
            icon: Icons.trending_up_outlined,
            label: 'Média por dia ativo',
            value: activeDays > 0 ? avgLabel : '—',
          ),
          const Divider(height: 20, color: AppColors.border),
          _HighlightRow(
            icon: Icons.check_circle_outline,
            label: 'Dias com leitura (ano)',
            value: '$activeDays ${activeDays == 1 ? 'dia' : 'dias'}',
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

  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.forestGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Text(value,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _HeatmapWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _HeatmapWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text('Nenhuma sessão registrada ainda',
              style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final maxMinutes = data
        .map((d) => (d['total_minutes'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(1.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: data.map((d) {
          final minutes = (d['total_minutes'] as num?)?.toDouble() ?? 0.0;
          final intensity = (minutes / maxMinutes).clamp(0.1, 1.0);
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: intensity),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
