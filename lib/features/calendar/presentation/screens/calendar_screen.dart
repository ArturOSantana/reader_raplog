import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _calendarMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);

final _calendarDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final clubRepo = ref.watch(bookClubRepositoryProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchHeatmap(days: 90),
    sessionRepo.fetchStreak(),
    clubRepo.listUpcomingMeetings(),
    goalRepo.fetchAll(),
  ]);

  return {
    'heatmap': results[0] as List<Map<String, dynamic>>,
    'streak': results[1] as int,
    'meetings': results[2] as List<BookClubMeeting>,
    'goals': results[3] as List<Goal>,
  };
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_calendarDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        automaticallyImplyLeading: false,
      ),
      body: data.when(
        loading: () => const SkelScreenList(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (d) {
          final heatmap = d['heatmap'] as List<Map<String, dynamic>>;
          final streak = d['streak'] as int;
          final meetings = d['meetings'] as List<BookClubMeeting>;
          final goals = d['goals'] as List<Goal>;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_calendarDataProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Streak banner ────────────────────────────────────────
                _StreakBanner(streak: streak),
                const SizedBox(height: 20),
                // ── Calendário mensal com ofensivas ──────────────────────
                _MonthCalendar(
                  heatmap: heatmap,
                  meetings: meetings,
                  streak: streak,
                ),
                const SizedBox(height: 24),
                // ── Próximos encontros ───────────────────────────────────
                if (meetings.isNotEmpty) ...[
                  Text('Próximos encontros',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 12),
                  ...meetings.take(5).map((m) => _MeetingCard(meeting: m)),
                  const SizedBox(height: 24),
                ],
                // ── Missões ────────────────────────────────────────────────
                if (goals.isNotEmpty) ...[
                  Text('Missões ativas', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 12),
                  ...goals.map((g) => _GoalChip(goal: g)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Streak Banner ─────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;

  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.forestGreen : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            isActive ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.local_fire_department_rounded,
                size: isActive ? 26 : 22,
                color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.5),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? '$streak ${streak == 1 ? 'dia' : 'dias'} de ofensiva!'
                      : 'Sem ofensiva ativa',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isActive ? Colors.white : AppColors.textPrimary,
                    fontFamily: 'Fraunces',
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Continue lendo hoje para manter a sequência.'
                      : 'Leia hoje para começar uma nova sequência.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendário Mensal ─────────────────────────────────────────────────────────

class _MonthCalendar extends ConsumerWidget {
  final List<Map<String, dynamic>> heatmap;
  final List<BookClubMeeting> meetings;
  final int streak;

  const _MonthCalendar({
    required this.heatmap,
    required this.meetings,
    required this.streak,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(_calendarMonthProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Mapas auxiliares
    final Map<String, int> readMinutesByDay = {};
    for (final row in heatmap) {
      final date = row['date'] as String?;
      final mins = (row['total_minutes'] as num?)?.toInt() ?? 0;
      if (date != null) readMinutesByDay[date] = mins;
    }

    // Calcula quais dias fazem parte da streak atual
    final Set<String> streakDays = {};
    if (streak > 0) {
      final today = DateTime.now();
      for (int i = 0; i < streak; i++) {
        final d = today.subtract(Duration(days: i));
        streakDays.add(_dateKey(d));
      }
    }
    final Map<String, List<BookClubMeeting>> meetingsByDay = {};
    for (final m in meetings) {
      final key = _dateKey(m.scheduledAt);
      meetingsByDay.putIfAbsent(key, () => []).add(m);
    }

    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    final startWeekday = firstDay.weekday % 7; // 0 = domingo

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header do mês
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthLabel(selectedMonth),
              style: AppTextStyles.headlineMedium,
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref
                      .read(_calendarMonthProvider.notifier)
                      .state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month - 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => ref
                      .read(_calendarMonthProvider.notifier)
                      .state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month + 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Labels dos dias da semana
        Row(
          children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Grade de dias
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < startWeekday) return const SizedBox.shrink();
            final day = index - startWeekday + 1;
            final date =
                DateTime(selectedMonth.year, selectedMonth.month, day);
            final key = _dateKey(date);
            final mins = readMinutesByDay[key] ?? 0;
            final hasMeeting = meetingsByDay.containsKey(key);
            final isToday = _dateKey(DateTime.now()) == key;

            return _DayCell(
              day: day,
              minutes: mins,
              hasMeeting: hasMeeting,
              isToday: isToday,
              isStreakDay: streakDays.contains(key),
              colorScheme: colorScheme,
              onTap: hasMeeting
                  ? () => _showDaySheet(
                        context,
                        date,
                        meetingsByDay[key] ?? [],
                        mins,
                      )
                  : mins > 0
                      ? () => _showDaySheet(context, date, [], mins)
                      : null,
            );
          },
        ),
        const SizedBox(height: 12),
        // Legenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: AppColors.forestGreen, label: 'Leitura'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.warmGold, label: 'Encontro'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.border, label: 'Sem atividade'),
          ],
        ),
      ],
    );
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<BookClubMeeting> dayMeetings,
    int minutes,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayDetailSheet(
        date: date,
        meetings: dayMeetings,
        minutes: minutes,
      ),
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int minutes;
  final bool hasMeeting;
  final bool isToday;
  final bool isStreakDay;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.minutes,
    required this.hasMeeting,
    required this.isToday,
    required this.isStreakDay,
    required this.colorScheme,
    this.onTap,
  });

  Color _bgColor() {
    if (hasMeeting) return AppColors.warmGold.withValues(alpha: 0.2);
    if (minutes >= 60) return AppColors.forestGreen.withValues(alpha: 0.8);
    if (minutes >= 20) return AppColors.forestGreen.withValues(alpha: 0.45);
    if (minutes > 0) return AppColors.forestGreen.withValues(alpha: 0.18);
    return AppColors.surfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(6),
          border: isToday
              ? Border.all(color: AppColors.forestGreen, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: minutes >= 60 && !hasMeeting
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            if (hasMeeting)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.warmGold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isStreakDay && minutes > 0)
              const Positioned(
                top: 1,
                right: 1,
                child: Icon(Icons.local_fire_department_rounded, size: 8),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelMedium),
      ],
    );
  }
}

// ── Day detail sheet ──────────────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<BookClubMeeting> meetings;
  final int minutes;

  const _DayDetailSheet({
    required this.date,
    required this.meetings,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeLabel =
        hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmt.format(date),
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (minutes > 0) ...[
            _SheetRow(
              icon: Icons.menu_book_outlined,
              color: AppColors.forestGreen,
              title: 'Leitura',
              subtitle: '$timeLabel lidos',
            ),
            const SizedBox(height: 10),
          ],
          ...meetings.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SheetRow(
                  icon: Icons.people_outlined,
                  color: AppColors.warmGold,
                  title: m.clubName,
                  subtitle: m.title,
                  trailing: DateFormat('HH:mm').format(m.scheduledAt),
                ),
              )),
          if (minutes == 0 && meetings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma atividade neste dia.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;

  const _SheetRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              Text(subtitle, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: AppTextStyles.labelMedium),
      ],
    );
  }
}

// ── Meeting Card ──────────────────────────────────────────────────────────────

class _MeetingCard extends ConsumerWidget {
  final BookClubMeeting meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = _formatDate(meeting.scheduledAt);

    return GestureDetector(
      onTap: () => context.push('/clubs/${meeting.clubId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_outlined,
                  color: AppColors.warmGold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meeting.clubName, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(meeting.title, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(dateLabel, style: AppTextStyles.labelMedium),
                      if (meeting.location != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.place_outlined,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(meeting.location!,
                              style: AppTextStyles.labelMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _RsvpBadge(rsvp: meeting.myRsvp),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
    final time = DateFormat('HH:mm').format(dt);
    if (diff == 0) return 'Hoje às $time';
    if (diff == 1) return 'Amanhã às $time';
    return DateFormat("d MMM 'às' HH:mm", 'pt_BR').format(dt);
  }
}

class _RsvpBadge extends StatelessWidget {
  final MeetingRsvp rsvp;

  const _RsvpBadge({required this.rsvp});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (rsvp) {
      case MeetingRsvp.going:
        color = AppColors.forestGreen;
        icon = Icons.check_circle_outline;
      case MeetingRsvp.maybe:
        color = AppColors.warmGold;
        icon = Icons.help_outline;
      case MeetingRsvp.notGoing:
        color = AppColors.error;
        icon = Icons.cancel_outlined;
      case MeetingRsvp.noResponse:
        color = AppColors.textMuted;
        icon = Icons.circle_outlined;
    }
    return Icon(icon, color: color, size: 20);
  }
}

// ── Goal Chip ─────────────────────────────────────────────────────────────────

class _GoalChip extends StatelessWidget {
  final Goal goal;

  const _GoalChip({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded,
              color: AppColors.forestGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${goal.type.label}: ${goal.targetValue} ${goal.type.unit}',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
