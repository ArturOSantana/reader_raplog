import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _calendarScheduleProvider =
    FutureProvider.family<List<ClubReadingScheduleEntry>, String>(
        (ref, clubId) =>
            ref.read(bookClubRepositoryProvider).listReadingSchedule(clubId));

final _calendarMeetingsProvider =
    FutureProvider.family<List<BookClubMeeting>, String>((ref, clubId) =>
        ref.read(bookClubRepositoryProvider).listMeetings(clubId));

final _calendarMilestonesProvider =
    FutureProvider.family<List<ClubMilestone>, String>((ref, clubId) =>
        ref.read(bookClubRepositoryProvider).listMilestones(clubId));

final _calendarChallengesProvider =
    FutureProvider.family<List<ClubChallenge>, String>((ref, clubId) =>
        ref
            .read(bookClubRepositoryProvider)
            .listChallenges(clubId, activeOnly: true));

// ── Modelo unificado de evento de calendário ──────────────────────────────────

enum _CalEventType { schedule, meeting, challenge }

class _CalEvent {
  final _CalEventType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final String emoji;
  final Color color;

  const _CalEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.emoji,
    required this.color,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubCalendarScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubCalendarScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(_calendarScheduleProvider(clubId));
    final meetingsAsync = ref.watch(_calendarMeetingsProvider(clubId));
    final milestonesAsync = ref.watch(_calendarMilestonesProvider(clubId));
    final challengesAsync = ref.watch(_calendarChallengesProvider(clubId));

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;

    // Se qualquer provider está carregando mostra shimmer
    final anyLoading = scheduleAsync.isLoading ||
        meetingsAsync.isLoading ||
        milestonesAsync.isLoading ||
        challengesAsync.isLoading;

    if (anyLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(context, cs, bgColor),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Agrega todos os eventos em uma lista unificada
    final events = <_CalEvent>[];

    // Cronograma de leitura
    for (final s in scheduleAsync.valueOrNull ?? []) {
      if (s.targetDate != null) {
        events.add(_CalEvent(
          type: _CalEventType.schedule,
          title: s.displayTitle,
          subtitle: s.notes ?? 'Ritmo de leitura',
          date: s.targetDate!,
          emoji: '📖',
          color: AppColors.forestGreen,
        ));
      }
    }

    // Encontros
    for (final m in meetingsAsync.valueOrNull ?? []) {
      events.add(_CalEvent(
        type: _CalEventType.meeting,
        title: m.title,
        subtitle: m.location ?? m.onlineLink ?? 'Encontro do clube',
        date: m.scheduledAt,
        emoji: '🗓️',
        color: AppColors.warmGold,
      ));
    }

    // Desafios (data de encerramento)
    for (final c in challengesAsync.valueOrNull ?? []) {
      events.add(_CalEvent(
        type: _CalEventType.challenge,
        title: c.title,
        subtitle: 'Prazo: ${c.daysLeftLabel}',
        date: c.endsAt,
        emoji: '💪',
        color: AppColors.error,
      ));
    }

    // Marcos de progresso (sem data fixa — agrupa por posição no livro)
    // Estes aparecem em uma seção separada, não no calendário cronológico
    final milestones = milestonesAsync.valueOrNull ?? [];

    // Ordena por data
    events.sort((a, b) => a.date.compareTo(b.date));

    // Separa em próximos e passados
    final now = DateTime.now();
    final upcoming = events.where((e) => e.date.isAfter(now)).toList();
    final past = events
        .where((e) => e.date.isBefore(now) || e.date.isAtSameMomentAs(now))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, cs, bgColor),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_calendarScheduleProvider(clubId));
          ref.invalidate(_calendarMeetingsProvider(clubId));
          ref.invalidate(_calendarMilestonesProvider(clubId));
          ref.invalidate(_calendarChallengesProvider(clubId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Marcos de progresso do livro ────────────────────────────
            if (milestones.isNotEmpty) ...[
              _SectionHeader(
                  title: 'Marcos de leitura', emoji: '🏁'),
              const SizedBox(height: 10),
              _MilestonesRow(milestones: milestones),
              const SizedBox(height: 28),
            ],

            // ── Próximos eventos ────────────────────────────────────────
            _SectionHeader(
                title: upcoming.isEmpty
                    ? 'Nenhum evento agendado'
                    : 'Próximos eventos',
                emoji: '⏰'),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              _EmptyEventsCard()
            else
              ...upcoming.map(
                  (e) => _EventCard(event: e, isPast: false)),

            // ── Eventos passados ────────────────────────────────────────
            if (past.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionHeader(title: 'Passados', emoji: '📌'),
              const SizedBox(height: 10),
              ...past.take(10).map((e) => _EventCard(event: e, isPast: true)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, ColorScheme cs, Color bgColor) {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🗓️ Calendário',
            style: AppTextStyles.titleMedium
                .copyWith(color: cs.onSurface, fontSize: 16),
          ),
          Text(
            clubName,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Cabeçalho de seção ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;

  const _SectionHeader({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(emoji),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headlineMedium
              .copyWith(color: cs.onSurface, fontSize: 16),
        ),
      ],
    );
  }
}

// ── Card de evento ────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final _CalEvent event;
  final bool isPast;

  const _EventCard({required this.event, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final fmt = DateFormat('d MMM • HH:mm', 'pt_BR');
    final isToday = DateUtils.isSameDay(event.date, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPast
              ? surfaceColor.withValues(alpha: 0.6)
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? event.color.withValues(alpha: 0.5)
                : borderColor,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Ícone colorido
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: event.color.withValues(alpha: isPast ? 0.06 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(event.emoji,
                      style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            // Título e subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isPast
                          ? AppColors.textMuted
                          : cs.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: AppTextStyles.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Data
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isToday)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: event.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HOJE',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: event.color),
                    ),
                  )
                else
                  Text(
                    fmt.format(event.date),
                    style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de marcos de progresso ───────────────────────────────────────────────

class _MilestonesRow extends StatelessWidget {
  final List<ClubMilestone> milestones;

  const _MilestonesRow({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: milestones
          .map((m) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MilestoneChip(milestone: m),
                ),
              ))
          .toList(),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final ClubMilestone milestone;

  const _MilestoneChip({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locked = !milestone.isUnlocked;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: locked ? surface : AppColors.forestGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: locked
              ? border
              : AppColors.forestGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(milestone.emoji,
              style: TextStyle(
                  fontSize: 18,
                  color: locked ? AppColors.textMuted : null)),
          const SizedBox(height: 4),
          Text(
            '${milestone.milestonePct}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: locked
                  ? AppColors.textMuted
                  : AppColors.forestGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sem eventos ───────────────────────────────────────────────────────────────

class _EmptyEventsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined,
              size: 32, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            'Nenhum evento agendado.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Admins podem adicionar encontros,\ncronograma e desafios.',
            style: AppTextStyles.labelMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
