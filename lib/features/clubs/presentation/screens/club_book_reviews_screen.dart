import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_reviews.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Resenhas — $bookTitle'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final existing = myReviewAsync.valueOrNull;
          final saved = await context.push<bool>(
            '/clubs/$clubId/reviews/new',
            extra: {
              'clubId':        clubId,
              'bookHistoryId': bookHistoryId,
              'bookTitle':     bookTitle,
              'existing':      existing,
            },
          );
          if (saved == true) {
            ref.invalidate(_reviewsProvider(bookHistoryId));
            ref.invalidate(_myReviewProvider(bookHistoryId));
          }
        },
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(
          myReviewAsync.valueOrNull != null
              ? 'Editar minha resenha'
              : 'Escrever resenha',
        ),
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
                    Icon(Icons.rate_review_outlined,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma resenha ainda.',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seja o primeiro a compartilhar o que achou de "$bookTitle".',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Média do ciclo (todos os ClubReview têm o mesmo avgRating)
          final avg = reviews.first.avgRating;

          return CustomScrollView(
            slivers: [
              // ── Header: média ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _AverageRatingCard(
                    avg: avg,
                    count: reviews.length,
                  ),
                ),
              ),
              // ── Lista de resenhas ─────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final review = reviews[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ReviewCard(review: review),
                    );
                  },
                  childCount: reviews.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }
}

// ── Card de média ─────────────────────────────────────────────────────────────

class _AverageRatingCard extends StatelessWidget {
  final double? avg;
  final int count;

  const _AverageRatingCard({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final avgDisplay = avg != null ? avg!.toStringAsFixed(1) : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warmGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.warmGold, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$avgDisplay / 5',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmGold,
                ),
              ),
              Text(
                '$count ${count == 1 ? 'resenha' : 'resenhas'}',
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card de resenha individual ────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final ClubReview review;
  const _ReviewCard({required this.review});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _spoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: avatar + nome + data
          Row(
            children: [
              MiniAvatar(url: r.avatarUrl, name: r.userName ?? '?'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.userName ?? 'Membro',
                        style: AppTextStyles.titleMedium),
                    Text(
                      fmt.format(r.createdAt.toLocal()),
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              // Badge de recomendação
              _RecommendBadge(recommend: r.wouldRecommend),
            ],
          ),
          const SizedBox(height: 10),
          // Estrelas
          Row(
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                i < r.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 18,
                color:
                    i < r.rating ? AppColors.warmGold : AppColors.border,
              ),
            )),
          ),
          // O que funcionou
          if (r.whatWorked != null && r.whatWorked!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ReviewSection(
              label: 'O que funcionou',
              icon: Icons.thumb_up_outlined,
              color: AppColors.forestGreen,
              text: r.whatWorked!,
              blurred: false,
            ),
          ],
          // O que não funcionou — com blur se tiver spoiler
          if (r.whatDidnt != null && r.whatDidnt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ReviewSection(
              label: 'O que não funcionou',
              icon: Icons.thumb_down_outlined,
              color: AppColors.error,
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
    );
  }
}

// ── Seção de texto da resenha ─────────────────────────────────────────────────

class _ReviewSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String text;
  final bool blurred;
  final VoidCallback? onReveal;
  final String? spoilerLabel;

  const _ReviewSection({
    required this.label,
    required this.icon,
    required this.color,
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
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (blurred)
          GestureDetector(
            onTap: onReveal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${spoilerLabel ?? 'Spoiler'} · Toque para revelar',
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          Text(text, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

// ── Badge de recomendação ─────────────────────────────────────────────────────

class _RecommendBadge extends StatelessWidget {
  final WouldRecommend recommend;
  const _RecommendBadge({required this.recommend});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (recommend) {
      WouldRecommend.yes             => (AppColors.forestGreen,   Icons.thumb_up_outlined),
      WouldRecommend.no              => (AppColors.error,         Icons.thumb_down_outlined),
      WouldRecommend.withReservations => (AppColors.warmGold,     Icons.thumbs_up_down_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            recommend.label,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
