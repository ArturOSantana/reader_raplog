import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/social_feed.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../../../theme/lumen_theme.dart';

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
    final feedAsync = ref.watch(_clubFeedProvider(clubId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feed', style: ReadLogType.bookTitle(size: 16)),
            Text(
              clubName,
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
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
            Text('Nenhuma atividade ainda.',
                style: ReadLogType.bookTitle(size: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Quando alguém ler, terminar um livro\nou entrar no clube, vai aparecer aqui.',
              style: ReadLogType.authorName(color: ReadLogColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed item com cheer ───────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final cheerColor =
        _cheeredByMe || _cheering ? ReadLogColors.progress : ReadLogColors.inkMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedCardWidget(
          item: widget.item,
          showComments: true,
          onLikeToggle: () async {
            await ref
                .read(socialFeedRepositoryProvider)
                .toggleLike(widget.item.id,
                    currentlyLiked: widget.item.likedByMe);
            widget.onRefresh();
          },
        ),
        // Botão de cheer — texto simples, sem ícone preenchido
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: InkWell(
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _cheeredByMe ? 'Torcendo 👏' : 'Torcer',
                style: ReadLogType.kicker(
                    color: cheerColor, size: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
