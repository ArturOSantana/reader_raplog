import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _timelineBookHistoryProvider =
    FutureProvider.family<List<ClubBookHistory>, String>(
        (ref, clubId) =>
            ref.read(bookClubRepositoryProvider).listBookHistory(clubId));

final _timelineHallOfFameProvider =
    FutureProvider.family<List<ClubHallOfFameEntry>, String>(
        (ref, clubId) =>
            ref.read(bookClubRepositoryProvider).fetchHallOfFame(clubId));

final _timelineMeetingsProvider =
    FutureProvider.family<List<BookClubMeeting>, String>(
        (ref, clubId) =>
            ref.read(bookClubRepositoryProvider).listMeetings(clubId));

// ── Modelo de evento de linha do tempo ────────────────────────────────────────

enum _TLEventType { bookStarted, bookFinished, meeting, hallOfFame }

class _TLEvent {
  final _TLEventType type;
  final DateTime date;
  final String title;
  final String? subtitle;
  final String? detail;

  const _TLEvent({
    required this.type,
    required this.date,
    required this.title,
    this.subtitle,
    this.detail,
  });

  IconData get icon {
    switch (type) {
      case _TLEventType.bookStarted:   return Icons.play_circle_outline;
      case _TLEventType.bookFinished:  return Icons.check_circle_outline;
      case _TLEventType.meeting:       return Icons.event_outlined;
      case _TLEventType.hallOfFame:    return Icons.workspace_premium_outlined;
    }
  }

  Color get color {
    switch (type) {
      case _TLEventType.bookStarted:   return AppColors.forestGreenLight;
      case _TLEventType.bookFinished:  return AppColors.forestGreen;
      case _TLEventType.meeting:       return AppColors.warmGold;
      case _TLEventType.hallOfFame:    return AppColors.warmGoldLight;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubTimelineScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubTimelineScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;

    final historyAsync = ref.watch(_timelineBookHistoryProvider(clubId));
    final hallAsync = ref.watch(_timelineHallOfFameProvider(clubId));
    final meetingsAsync = ref.watch(_timelineMeetingsProvider(clubId));

    final isLoading = historyAsync.isLoading ||
        hallAsync.isLoading ||
        meetingsAsync.isLoading;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Linha do Tempo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_timelineBookHistoryProvider(clubId));
                ref.invalidate(_timelineHallOfFameProvider(clubId));
                ref.invalidate(_timelineMeetingsProvider(clubId));
              },
              child: _buildTimeline(context, ref),
            ),
    );
  }

  Widget _buildTimeline(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final history = ref.read(_timelineBookHistoryProvider(clubId)).valueOrNull ?? [];
    final hall = ref.read(_timelineHallOfFameProvider(clubId)).valueOrNull ?? [];
    final meetings = ref.read(_timelineMeetingsProvider(clubId)).valueOrNull ?? [];

    // Agrega todos os eventos
    final events = <_TLEvent>[];

    for (final b in history) {
      events.add(_TLEvent(
        type: _TLEventType.bookStarted,
        date: b.startedAt,
        title: 'Iniciou: ${b.bookTitle}',
        subtitle: b.bookAuthor,
      ));
      if (b.endedAt != null) {
        events.add(_TLEvent(
          type: _TLEventType.bookFinished,
          date: b.endedAt!,
          title: 'Concluiu: ${b.bookTitle}',
          subtitle: b.bookAuthor,
          detail: b.meetingCount > 0 ? '${b.meetingCount} encontros' : null,
        ));
      }
    }

    for (final m in meetings) {
      events.add(_TLEvent(
        type: _TLEventType.meeting,
        date: m.scheduledAt,
        title: m.title,
        subtitle: m.location ?? m.onlineLink ?? 'Encontro do clube',
      ));
    }

    for (final h in hall) {
      events.add(_TLEvent(
        type: _TLEventType.hallOfFame,
        date: h.seasonEndedAt,
        title: 'Hall da Fama — ${h.bookTitle}',
        subtitle: h.topReaderName != null
            ? 'Destaque: ${h.topReaderName}'
            : null,
        detail: '${h.totalPages} pág. · ${h.totalMembers} membros',
      ));
    }

    // Ordena mais recente primeiro
    events.sort((a, b) => b.date.compareTo(a.date));

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined,
                  size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('Nenhum histórico ainda.',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 4),
              Text('A linha do tempo aparecerá conforme o clube evolui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.45))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: events.length,
      itemBuilder: (context, i) => _TLEventTile(
        event: events[i],
        isLast: i == events.length - 1,
      ),
    );
  }
}

// ── Tile de evento na timeline ────────────────────────────────────────────────

class _TLEventTile extends StatelessWidget {
  final _TLEvent event;
  final bool isLast;

  const _TLEventTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat("d 'de' MMM 'de' yyyy", 'pt_BR');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna da linha vertical + ícone
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: event.color.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(event.icon, size: 16, color: event.color),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(event.subtitle!,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                    if (event.detail != null) ...[
                      const SizedBox(height: 4),
                      Text(event.detail!,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.45))),
                    ],
                    const SizedBox(height: 4),
                    Text(fmt.format(event.date.toLocal()),
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.35))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
