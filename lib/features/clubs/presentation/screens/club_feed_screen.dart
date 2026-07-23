import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/social_feed.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';
import '../../../../shared/widgets/skel_shimmer.dart';

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
        loading: () => const SkelScreenList(),
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
          return _FeedItemWithCheer(
            key: ValueKey(item.id),
            item: item,
            clubId: clubId,
            onRefresh: onRefresh,
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
            const Icon(Icons.dynamic_feed_outlined, size: 48, color: AppColors.textMuted),
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

// ── F-06 Cheer — card com botão de torcida ────────────────────────────────────

class _FeedItemWithCheer extends ConsumerStatefulWidget {
  final FeedItem item;
  final String clubId;
  final Future<void> Function() onRefresh;

  const _FeedItemWithCheer({
    super.key,
    required this.item,
    required this.clubId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_FeedItemWithCheer> createState() =>
      _FeedItemWithCheerState();
}

class _FeedItemWithCheerState extends ConsumerState<_FeedItemWithCheer> {
  bool _cheering = false;
  bool _cheeredByMe = false;
  // O count exato exigiria uma query extra; usamos flag local para feedback imediato.

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedCardWidget(
          item: widget.item,
          showComments: true,
          onLikeToggle: () async {
            await ref
                .read(socialFeedRepositoryProvider)
                .toggleLike(widget.item.id, currentlyLiked: widget.item.likedByMe);
            widget.onRefresh();
          },
        ),
        // Botão de cheer (reação rápida de um toque — toggle_cheer RPC)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _cheering
                ? null
                : () async {
                    setState(() => _cheering = true);
                    final added = await ref
                        .read(bookClubRepositoryProvider)
                        .toggleCheer(widget.item.id);
                    if (mounted) {
                      setState(() {
                        _cheering = false;
                        _cheeredByMe = added;
                      });
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                   Icons.volunteer_activism_outlined,
                   size: 16,
                   color: _cheeredByMe || _cheering
                       ? AppColors.warmGold
                       : AppColors.textMuted,
                 ),
                 const SizedBox(width: 4),
                 Text(
                   _cheeredByMe ? 'Torcendo!' : 'Torcer',
                   style: AppTextStyles.labelMedium.copyWith(
                     fontSize: 12,
                     color: _cheeredByMe || _cheering
                         ? AppColors.warmGold
                         : AppColors.textMuted,
                   ),
                 ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
