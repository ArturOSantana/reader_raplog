import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/social_feed.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clubFeedProvider =
    FutureProvider.family<List<FeedItem>, String>((ref, clubId) {
  return ref.watch(socialFeedRepositoryProvider).fetchClubFeed(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubFeedScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubFeedScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final feedAsync = ref.watch(_clubFeedProvider(clubId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feed do clube',
              style: AppTextStyles.titleMedium
                  .copyWith(color: cs.onSurface, fontSize: 15),
            ),
            Text(
              clubName,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (items) => _FeedList(
          items: items,
          clubId: clubId,
          onRefresh: () async => ref.invalidate(_clubFeedProvider(clubId)),
        ),
      ),
    );
  }
}

// ── Lista de posts ────────────────────────────────────────────────────────────

class _FeedList extends ConsumerWidget {
  final List<FeedItem> items;
  final String clubId;
  final Future<void> Function() onRefresh;

  const _FeedList({
    required this.items,
    required this.clubId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            _EmptyFeed(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (_, i) {
          final item = items[i];
          return FeedCardWidget(
            key: ValueKey(item.id),
            item: item,
            showComments: true,
            onLikeToggle: () async {
              await ref
                  .read(socialFeedRepositoryProvider)
                  .toggleLike(item.id, currentlyLiked: item.likedByMe);
              ref.invalidate(_clubFeedProvider(clubId));
            },
          );
        },
      ),
    );
  }
}

// ── Estado vazio ──────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Nenhuma atividade ainda.',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Quando alguém ler, terminar um livro\nou entrar no clube, vai aparecer aqui.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
