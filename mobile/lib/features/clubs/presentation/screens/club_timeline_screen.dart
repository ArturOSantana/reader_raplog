import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubTimelineScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final String? coverUrl;

  const ClubTimelineScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_timelineBookHistoryProvider(clubId));
    final hallAsync = ref.watch(_timelineHallOfFameProvider(clubId));
    final meetingsAsync = ref.watch(_timelineMeetingsProvider(clubId));

    final isLoading = historyAsync.isLoading ||
        hallAsync.isLoading ||
        meetingsAsync.isLoading;

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Linha do tempo', style: ReadLogType.bookTitle(size: 16)),
            Text(clubName,
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 12)),
          ],
        ),
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
    ),
    );
  }

  Widget _buildTimeline(BuildContext context, WidgetRef ref) {
    final history =
        ref.read(_timelineBookHistoryProvider(clubId)).valueOrNull ?? [];
    final hall =
        ref.read(_timelineHallOfFameProvider(clubId)).valueOrNull ?? [];
    final meetings =
        ref.read(_timelineMeetingsProvider(clubId)).valueOrNull ?? [];

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
          detail:
              b.meetingCount > 0 ? '${b.meetingCount} encontros' : null,
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
        title: 'Temporada encerrada — ${h.bookTitle}',
        subtitle:
            h.topReaderName != null ? 'Destaque: ${h.topReaderName}' : null,
        detail: '${h.totalPages} pág. · ${h.totalMembers} membros',
      ));
    }

    events.sort((a, b) => b.date.compareTo(a.date));

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nenhum histórico ainda.',
                  style: ReadLogType.bookTitle(size: 18)),
              const SizedBox(height: 6),
              Text(
                'A linha do tempo aparecerá conforme o clube evolui.',
                textAlign: TextAlign.center,
                style: ReadLogType.authorName(color: ReadLogColors.inkMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: events.length,
      itemBuilder: (context, i) => _TLEventRow(event: events[i]),
    );
  }
}

// ── Linha de evento da timeline ───────────────────────────────────────────────

class _TLEventRow extends StatelessWidget {
  final _TLEvent event;

  const _TLEventRow({required this.event});

  String get _typeLabel => switch (event.type) {
        _TLEventType.bookStarted => 'início',
        _TLEventType.bookFinished => 'conclusão',
        _TLEventType.meeting => 'encontro',
        _TLEventType.hallOfFame => 'temporada',
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMM 'de' yyyy", 'pt_BR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data + tipo à esquerda
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.format(event.date.toLocal()),
                      style: ReadLogType.mono(
                          size: 10, color: ReadLogColors.inkGhost),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel,
                      style: ReadLogType.kicker(
                          color: ReadLogColors.inkGhost, size: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: ReadLogType.authorName(size: 14)),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(event.subtitle!,
                          style: ReadLogType.authorName(
                              color: ReadLogColors.inkMuted, size: 12)),
                    ],
                    if (event.detail != null) ...[
                      const SizedBox(height: 3),
                      Text(event.detail!,
                          style: ReadLogType.mono(
                              size: 11, color: ReadLogColors.inkGhost)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
