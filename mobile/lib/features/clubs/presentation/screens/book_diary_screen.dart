import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _bookDiaryProvider =
    FutureProvider.family<List<ReadingSession>, String>((ref, bookId) {
  return ref.read(bookClubRepositoryProvider).fetchBookDiary(bookId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Diário do Livro — mostra as mini-resenhas e humores das sessões de leitura.
/// Uma tela contemplativa: cada sessão é uma "página do diário".
class BookDiaryScreen extends ConsumerWidget {
  final String bookId;
  final String bookTitle;
  final String? bookAuthor;

  const BookDiaryScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.bookAuthor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(_bookDiaryProvider(bookId));

    return LumenClubTintBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diário de leitura',
                  style: LumenType.bookTitle(size: 16)),
              Text(
                bookTitle,
                style: LumenType.authorName(
                    color: LumenColors.inkMuted, size: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: diary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar o diário.\n$e',
              textAlign: TextAlign.center,
              style: LumenType.authorName(color: LumenColors.inkMuted),
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Diário vazio.',
                        style: LumenType.bookTitle(size: 18)),
                    const SizedBox(height: 8),
                    Text(
                      'Ao finalizar sessões, você pode registrar\nseu humor e uma impressão rápida.',
                      textAlign: TextAlign.center,
                      style: LumenType.authorName(
                          color: LumenColors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Cabeçalho — resumo compacto em linha
              _DiaryHeader(sessions: sessions),
              // Lista de entradas
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_bookDiaryProvider(bookId)),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 0),
                    itemBuilder: (context, i) =>
                        _DiaryEntry(session: sessions[i]),
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

// ── Cabeçalho do Diário ───────────────────────────────────────────────────────

class _DiaryHeader extends StatelessWidget {
  final List<ReadingSession> sessions;

  const _DiaryHeader({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalEntries = sessions.length;
    final totalPages =
        sessions.fold<int>(0, (a, s) => a + (s.pagesRead ?? 0));
    final moodCounts = <SessionMood, int>{};
    for (final s in sessions) {
      if (s.mood != null) moodCounts[s.mood!] = (moodCounts[s.mood!] ?? 0) + 1;
    }
    final dominantMood = moodCounts.isEmpty
        ? null
        : moodCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LumenColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                '$totalEntries ${totalEntries == 1 ? "entrada" : "entradas"}',
                if (totalPages > 0) '$totalPages páginas',
              ].join(' · '),
              style: LumenType.mono(
                  size: 12, color: LumenColors.inkMuted),
            ),
          ),
          if (dominantMood != null)
            Text(
              '${dominantMood.label} dominante',
              style: LumenType.mono(
                  size: 11, color: LumenColors.inkGhost),
            ),
        ],
      ),
    );
  }
}

// ── Entrada do Diário ─────────────────────────────────────────────────────────

class _DiaryEntry extends StatelessWidget {
  final ReadingSession session;

  const _DiaryEntry({required this.session});

  @override
  Widget build(BuildContext context) {
    final hasMood = session.mood != null;
    final hasReview = session.miniReview?.isNotEmpty == true;

    final fmtDate = DateFormat("EEEE, d 'de' MMM", 'pt_BR');
    final fmtTime = DateFormat('HH:mm', 'pt_BR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha de metadados
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmtDate.format(session.startedAt.toLocal()),
                          style: LumenType.authorName(size: 13),
                        ),
                        Text(
                          [
                            fmtTime.format(session.startedAt.toLocal()),
                            if (hasMood) session.mood!.label,
                          ].join(' · '),
                          style: LumenType.mono(
                              size: 11, color: LumenColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  // Stats compactas
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (session.pagesRead != null &&
                          session.pagesRead! > 0)
                        Text(
                          '${session.pagesRead} pág.',
                          style: LumenType.mono(
                              size: 12, color: LumenColors.ink),
                        ),
                      if (session.durationMinutes != null &&
                          session.durationMinutes! > 0)
                        Text(
                          _fmtDuration(session.durationMinutes!),
                          style: LumenType.mono(
                              size: 11, color: LumenColors.inkGhost),
                        ),
                    ],
                  ),
                ],
              ),
              // Mini-resenha como citação editorial
              if (hasReview) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: LumenColors.divider, width: 2)),
                  ),
                  child: Text(
                    '"${session.miniReview!}"',
                    style: LumenType.quote(size: 13),
                  ),
                ),
              ],
              // Páginas de progresso
              if (session.startPage != null && session.endPage != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Pág. ${session.startPage} → ${session.endPage}',
                  style: LumenType.mono(
                      size: 11, color: LumenColors.inkGhost),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
