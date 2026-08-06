import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_reviews.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _reviewsProvider =
    FutureProvider.family<List<ClubReview>, String>((ref, bookHistoryId) {
  return ref.watch(bookClubRepositoryProvider).fetchBookReviews(bookHistoryId);
});

final _myReviewProvider =
    FutureProvider.family<ClubReview?, String>((ref, bookHistoryId) {
  return ref.watch(bookClubRepositoryProvider).fetchMyReview(bookHistoryId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Lista todas as resenhas de um ciclo de leitura + média + botão de nova resenha.
class ClubBookReviewsScreen extends ConsumerWidget {
  final String clubId;
  final String bookHistoryId;
  final String bookTitle;

  const ClubBookReviewsScreen({
    super.key,
    required this.clubId,
    required this.bookHistoryId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(_reviewsProvider(bookHistoryId));
    final myReviewAsync = ref.watch(_myReviewProvider(bookHistoryId));

    return LumenClubTintBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Resenhas',
            style: LumenType.bookTitle(size: 16)),
          actions: [
            TextButton(
              onPressed: () async {
                final existing = myReviewAsync.valueOrNull;
                final saved = await context.push<bool>(
                  '/clubs/$clubId/reviews/new',
                  extra: {
                    'clubId': clubId,
                    'bookHistoryId': bookHistoryId,
                    'bookTitle': bookTitle,
                    'existing': existing,
                  },
                );
                if (saved == true) {
                  ref.invalidate(_reviewsProvider(bookHistoryId));
                  ref.invalidate(_myReviewProvider(bookHistoryId));
                }
              },
              child: Text(
                myReviewAsync.valueOrNull != null ? 'Editar' : 'Escrever',
                style: LumenType.kicker(color: LumenColors.ink, size: 12),
              ),
            ),
          ],
        ),
        body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nenhuma resenha ainda.',
                        style: LumenType.bookTitle(size: 18)),
                    const SizedBox(height: 8),
                    Text(
                      'Seja o primeiro a compartilhar o que achou de "$bookTitle".',
                      textAlign: TextAlign.center,
                      style: LumenType.authorName(
                          color: LumenColors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final avg = reviews.first.avgRating;

          return CustomScrollView(
            slivers: [
              // ── Média — texto simples ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _AverageLine(avg: avg, count: reviews.length),
                ),
              ),
              // ── Lista de resenhas ─────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _ReviewEntry(review: reviews[index]),
                    );
                  },
                  childCount: reviews.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
      ),
    );
  }
}

// ── Média — linha de texto ────────────────────────────────────────────────────

class _AverageLine extends StatelessWidget {
  final double? avg;
  final int count;

  const _AverageLine({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final avgDisplay = avg != null ? avg!.toStringAsFixed(1) : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            avgDisplay,
            style: LumenType.bookTitle(size: 28),
          ),
          const SizedBox(width: 6),
          Text(' / 5',
              style: LumenType.mono(
                  size: 13, color: LumenColors.inkMuted)),
          const SizedBox(width: 12),
          Text(
            '$count ${count == 1 ? 'resenha' : 'resenhas'}',
            style: LumenType.mono(
                size: 12, color: LumenColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ── Entrada de resenha ────────────────────────────────────────────────────────

class _ReviewEntry extends StatefulWidget {
  final ClubReview review;
  const _ReviewEntry({required this.review});

  @override
  State<_ReviewEntry> createState() => _ReviewEntryState();
}

class _ReviewEntryState extends State<_ReviewEntry> {
  bool _spoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final fmt = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha de cabeçalho: nome · data · recomendação
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.userName ?? 'Membro',
                      style: LumenType.authorName(size: 14),
                    ),
                  ),
                  Text(
                    fmt.format(r.createdAt.toLocal()),
                    style: LumenType.mono(
                        size: 11, color: LumenColors.inkGhost),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Nota numérica + recomendação em texto
              Text(
                '${r.rating}/5 · ${r.wouldRecommend.label.toLowerCase()}',
                style: LumenType.mono(
                    size: 11, color: LumenColors.inkMuted),
              ),
              // O que funcionou
              if (r.whatWorked != null && r.whatWorked!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ReviewSection(
                  label: 'o que funcionou',
                  text: r.whatWorked!,
                  blurred: false,
                ),
              ],
              // O que não funcionou — com aviso de spoiler
              if (r.whatDidnt != null && r.whatDidnt!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _ReviewSection(
                  label: 'o que não funcionou',
                  text: r.whatDidnt!,
                  blurred: r.hasSpoiler && !_spoilerRevealed,
                  onReveal: r.hasSpoiler && !_spoilerRevealed
                      ? () => setState(() => _spoilerRevealed = true)
                      : null,
                  spoilerLabel: r.spoilerLevel.label,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Seção de texto da resenha ─────────────────────────────────────────────────

class _ReviewSection extends StatelessWidget {
  final String label;
  final String text;
  final bool blurred;
  final VoidCallback? onReveal;
  final String? spoilerLabel;

  const _ReviewSection({
    required this.label,
    required this.text,
    required this.blurred,
    this.onReveal,
    this.spoilerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: LumenType.kicker(
              color: LumenColors.inkMuted, size: 10),
        ),
        const SizedBox(height: 4),
        if (blurred)
          GestureDetector(
            onTap: onReveal,
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: LumenColors.divider, width: 2)),
              ),
              child: Text(
                '${spoilerLabel ?? 'Spoiler'} · Toque para revelar',
                style: LumenType.mono(
                    size: 12, color: LumenColors.inkMuted),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                  left:
                      BorderSide(color: LumenColors.divider, width: 2)),
            ),
            child: Text(text,
                style: LumenType.authorName(size: 14)),
          ),
      ],
    );
  }
}
