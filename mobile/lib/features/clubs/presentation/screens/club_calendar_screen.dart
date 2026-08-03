import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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

  const _CalEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

// ── Utilitário Google Calendar ────────────────────────────────────────────────

Future<void> _addToGoogleCalendar(_CalEvent event) async {
  final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
  final start = fmt.format(event.date.toUtc());
  final endDate = event.date.add(
    event.type == _CalEventType.schedule
        ? const Duration(minutes: 30)
        : const Duration(hours: 1),
  );
  final end = fmt.format(endDate.toUtc());

  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': event.title,
    'dates': '$start/$end',
    'details': event.subtitle,
  });

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Não foi possível abrir Google Agenda: $uri');
  }
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

    final anyLoading = scheduleAsync.isLoading ||
        meetingsAsync.isLoading ||
        milestonesAsync.isLoading ||
        challengesAsync.isLoading;

    if (anyLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final events = <_CalEvent>[];

    for (final s in scheduleAsync.valueOrNull ?? []) {
      if (s.targetDate != null) {
        events.add(_CalEvent(
          type: _CalEventType.schedule,
          title: s.displayTitle,
          subtitle: s.notes ?? 'Ritmo de leitura',
          date: s.targetDate!,
        ));
      }
    }

    for (final m in meetingsAsync.valueOrNull ?? []) {
      events.add(_CalEvent(
        type: _CalEventType.meeting,
        title: m.title,
        subtitle: m.location ?? m.onlineLink ?? 'Encontro do clube',
        date: m.scheduledAt,
      ));
    }

    for (final c in challengesAsync.valueOrNull ?? []) {
      events.add(_CalEvent(
        type: _CalEventType.challenge,
        title: c.title,
        subtitle: 'Prazo: ${c.daysLeftLabel}',
        date: c.endsAt,
      ));
    }

    final milestones = milestonesAsync.valueOrNull ?? [];

    events.sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final upcoming = events.where((e) => e.date.isAfter(now)).toList();
    final past = events
        .where((e) => e.date.isBefore(now) || e.date.isAtSameMomentAs(now))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: _buildAppBar(context),
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
              _SectionLabel('Marcos de leitura'),
              const SizedBox(height: 10),
              _MilestonesList(
                milestones: milestones,
                clubId: clubId,
                clubName: clubName,
              ),
              const SizedBox(height: 28),
            ],

            // ── Próximos eventos ────────────────────────────────────────
            _SectionLabel(
                upcoming.isEmpty ? 'Nenhum evento agendado' : 'Próximos'),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              Text('Admins podem adicionar encontros, cronograma e desafios.',
                  style: ReadLogType.authorName(
                      color: ReadLogColors.inkMuted, size: 13))
            else
              ...upcoming.map((e) => _EventRow(event: e, isPast: false)),

            // ── Eventos passados ────────────────────────────────────────
            if (past.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel('Passados'),
              const SizedBox(height: 10),
              ...past.take(10).map((e) => _EventRow(event: e, isPast: true)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calendário', style: ReadLogType.bookTitle(size: 16)),
          Text(clubName,
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 12)),
        ],
      ),
    );
  }
}

// ── Label de seção ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: ReadLogType.kicker(color: ReadLogColors.inkMuted, size: 11),
    );
  }
}

// ── Linha de evento ────────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final _CalEvent event;
  final bool isPast;

  const _EventRow({required this.event, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm', 'pt_BR');
    final isToday = DateUtils.isSameDay(event.date, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: ReadLogType.authorName(
                        size: 14,
                        color: isPast
                            ? ReadLogColors.inkMuted
                            : ReadLogColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.subtitle,
                      style: ReadLogType.authorName(
                          color: ReadLogColors.inkMuted, size: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isToday ? 'hoje' : fmt.format(event.date),
                    style: ReadLogType.mono(
                      size: 11,
                      color: isToday
                          ? ReadLogColors.progress
                          : ReadLogColors.inkGhost,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (!isPast) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _addToGoogleCalendar(event),
                      child: Text(
                        '+ agenda',
                        style: ReadLogType.mono(
                            size: 10, color: ReadLogColors.inkGhost),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Lista de marcos ────────────────────────────────────────────────────────────

class _MilestonesList extends StatelessWidget {
  final List<ClubMilestone> milestones;
  final String clubId;
  final String clubName;

  const _MilestonesList({
    required this.milestones,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: milestones.map((m) {
        final locked = !m.isUnlocked;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            InkWell(
              onTap: locked
                  ? null
                  : () => context.go(
                        '/clubs/$clubId/milestones/${m.id}/discussion',
                        extra: {
                          'milestone': m,
                          'clubName': clubName,
                        },
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      '${m.milestonePct}%',
                      style: ReadLogType.mono(
                        size: 13,
                        color: locked
                            ? ReadLogColors.inkGhost
                            : ReadLogColors.progress,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.label,
                        style: ReadLogType.authorName(
                          size: 13,
                          color: locked
                              ? ReadLogColors.inkGhost
                              : ReadLogColors.ink,
                        ),
                      ),
                    ),
                    if (!locked)
                      Text('ver',
                          style: ReadLogType.kicker(
                              color: ReadLogColors.inkGhost, size: 10)),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
