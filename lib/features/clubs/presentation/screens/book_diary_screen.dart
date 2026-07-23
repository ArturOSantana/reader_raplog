import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final diary = ref.watch(_bookDiaryProvider(bookId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diário de leitura',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              bookTitle,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: diary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar o diário.\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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
                    Icon(Icons.menu_book_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('Diário vazio.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Text(
                      'Ao finalizar sessões, você pode registrar\nseu humor e uma impressão rápida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Cabeçalho — resumo do livro
              _DiaryHeader(
                sessions: sessions,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
              ),
              // Lista de entradas
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_bookDiaryProvider(bookId)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _DiaryEntry(session: sessions[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Cabeçalho do Diário ───────────────────────────────────────────────────────

class _DiaryHeader extends StatelessWidget {
  final List<ReadingSession> sessions;
  final String bookTitle;
  final String? bookAuthor;

  const _DiaryHeader({
    required this.sessions,
    required this.bookTitle,
    this.bookAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalEntries = sessions.length;
    final totalPages = sessions.fold<int>(0, (a, s) => a + (s.pagesRead ?? 0));
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$totalEntries ${totalEntries == 1 ? "entrada" : "entradas"}',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6))),
                if (totalPages > 0)
                  Text('$totalPages páginas registradas',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
          if (dominantMood != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dominantMood.emoji,
                    style: const TextStyle(fontSize: 24)),
                Text('humor dominante',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.4))),
              ],
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMood = session.mood != null;
    final hasReview = session.miniReview?.isNotEmpty == true;

    final fmtDate = DateFormat("EEEE, d 'de' MMM", 'pt_BR');
    final fmtTime = DateFormat('HH:mm', 'pt_BR');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de metadados
          Row(
            children: [
              if (hasMood) ...[
                Text(session.mood!.emoji,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtDate.format(session.startedAt.toLocal()),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      fmtTime.format(session.startedAt.toLocal()),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              // Stats compactas
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (session.pagesRead != null && session.pagesRead! > 0)
                    Text('${session.pagesRead} pág.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.forestGreen)),
                  if (session.durationMinutes != null &&
                      session.durationMinutes! > 0)
                    Text(_fmtDuration(session.durationMinutes!),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ],
          ),
          // Mini-resenha
          if (hasReview) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.forestGreen.withValues(alpha: 0.15)),
              ),
              child: Text(
                '"${session.miniReview!}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: cs.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
          ],
          // Humor como label se não há review
          if (hasMood && !hasReview) ...[
            const SizedBox(height: 6),
            Text('Humor: ${session.mood!.label}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ],
          // Páginas de progresso
          if (session.startPage != null && session.endPage != null) ...[
            const SizedBox(height: 6),
            Text(
              'Pág. ${session.startPage} → ${session.endPage}',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.35)),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
