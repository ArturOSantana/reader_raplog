import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/models/social_feed.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../clubs/presentation/screens/book_clubs_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _feedProvider = FutureProvider<List<FeedItem>>((ref) {
  return ref.watch(socialFeedRepositoryProvider).fetchFeed();
});

final _friendsListProvider = FutureProvider<List<Friend>>((ref) {
  return ref.watch(friendsRepositoryProvider).listFriends();
});

final _socialTabProvider = StateProvider<int>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      ref.read(_socialTabProvider.notifier).state = _tabs.index;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outlined),
            tooltip: 'Amigos',
            onPressed: () => context.push('/friends'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Amigos'),
            Tab(text: 'Clubes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _FeedTab(),
          _FriendsTab(),
          BookClubsBody(),
        ],
      ),
    );
  }
}

// ── Feed Tab ──────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(_feedProvider);

    return feedAsync.when(
      loading: () => const SkelScreenList(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.dynamic_feed_outlined,
            message: 'Nenhuma atividade ainda.\nAdicione amigos para ver o feed!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_feedProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _FeedCard(
              item: items[i],
              onLikeToggle: () async {
                await ref.read(socialFeedRepositoryProvider).toggleLike(
                      items[i].id,
                      currentlyLiked: items[i].likedByMe,
                    );
                ref.invalidate(_feedProvider);
              },
            ),
          ),
        );
      },
    );
  }
}

class _FeedCard extends ConsumerStatefulWidget {
  final FeedItem item;
  final VoidCallback onLikeToggle;

  const _FeedCard({required this.item, required this.onLikeToggle});

  @override
  ConsumerState<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<_FeedCard> {
  // Reações do usuário atual neste post (carregadas lazy)
  Set<String> _myReactions = {};
  bool _reactionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMyReactions();
  }

  Future<void> _loadMyReactions() async {
    final reactions = await ref
        .read(socialFeedRepositoryProvider)
        .fetchMyReactions(widget.item.id);
    if (mounted) setState(() { _myReactions = reactions; _reactionsLoaded = true; });
  }

  Future<void> _toggleReaction(FeedReactionType type) async {
    final wasActive = _myReactions.contains(type.dbValue);
    setState(() {
      if (wasActive) {
        _myReactions = Set.from(_myReactions)..remove(type.dbValue);
      } else {
        _myReactions = Set.from(_myReactions)..add(type.dbValue);
      }
    });
    await ref
        .read(socialFeedRepositoryProvider)
        .toggleReaction(widget.item.id, type);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    return 'há ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final timeAgo = _timeAgo(item.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniAvatar(
            url: item.userAvatarUrl,
            name: item.userName ?? '?',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome + tempo
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.userName ?? 'Usuário',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Text(timeAgo, style: AppTextStyles.labelMedium),
                  ],
                ),
                const SizedBox(height: 6),
                _FeedEventContent(item: item),
                const SizedBox(height: 10),
                // ── Barra de reações tipadas ──────────────────────────────
                if (_reactionsLoaded)
                  _ReactionsBar(
                    myReactions: _myReactions,
                    summary: item.reactionsSummary,
                    onToggle: _toggleReaction,
                  ),
                // Like clássico (mantido para compatibilidade)
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: widget.onLikeToggle,
                  child: Row(
                    children: [
                      Icon(
                        item.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: item.likedByMe
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.likesCount}',
                        style: AppTextStyles.labelMedium,
                      ),
                      if (item.commentsCount > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.comment_outlined,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${item.commentsCount}',
                            style: AppTextStyles.labelMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra de reações tipadas ───────────────────────────────────────────────────

class _ReactionsBar extends StatelessWidget {
  final Set<String> myReactions;
  final Map<String, int> summary;
  final void Function(FeedReactionType) onToggle;

  const _ReactionsBar({
    required this.myReactions,
    required this.summary,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: FeedReactionType.values.map((type) {
        final isActive = myReactions.contains(type.dbValue);
        final count = summary[type.dbValue] ?? 0;
        return GestureDetector(
          onTap: () => onToggle(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.warmGold.withValues(alpha: 0.2)
                  : AppColors.textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? AppColors.warmGold.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 14)),
                if (count > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.warmGold
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FeedEventContent extends StatelessWidget {
  final FeedItem item;

  const _FeedEventContent({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.eventType) {
      case FeedEventType.finishedBook:
        return _FinishedBookCard(item: item);

      case FeedEventType.startedBook:
        return _EventCard(
          icon: Icons.menu_book_outlined,
          color: AppColors.forestGreenLight,
          headline: item.bookTitle != null
              ? 'Começou a ler "${item.bookTitle}"'
              : 'Começou um novo livro',
          detail: null,
        );

      case FeedEventType.streak:
        final days = item.streakDays ?? 0;
        final String? streakDetail = switch (true) {
          _ when days >= 100 =>
            'Marco incrível — mais de 99% dos leitores não chegam aqui.',
          _ when days >= 30 =>
            'Um mês inteiro lendo todo dia. Isso é disciplina de verdade.',
          _ when days >= 7 => 'Uma semana seguida. O hábito está se formando.',
          _ => null,
        };
        return _EventCard(
          icon: Icons.local_fire_department_outlined,
          color: AppColors.warmGold,
          headline: '$days dias lendo sem parar 🔥',
          detail: streakDetail,
        );

      case FeedEventType.achievement:
        return _EventCard(
          icon: Icons.workspace_premium_outlined,
          color: AppColors.warmGoldLight,
          headline: item.achievementName != null
              ? 'Desbloqueou "${item.achievementName}"'
              : 'Nova conquista desbloqueada',
          detail: null,
        );

      case FeedEventType.goalCompleted:
        return _EventCard(
          icon: Icons.flag_rounded,
          color: AppColors.forestGreen,
          headline: 'Missão cumprida! 🎯',
          detail: item.goalDescription,
        );

      case FeedEventType.readingSession:
        // Monta uma narrativa contextual com base nos dados disponíveis
        final pages = item.pagesRead;
        final time = item.readingTimeLabel;
        final streak = item.streakDays;
        final book = item.bookTitle;

        final String headline;
        if (pages != null && pages > 0 && book != null) {
          headline = 'Leu $pages páginas de "$book"';
        } else if (book != null) {
          headline = 'Terminou uma sessão de "$book"';
        } else {
          headline = 'Concluiu uma sessão de leitura';
        }

        String? badge;
        if (streak != null && streak >= 100) {
          badge = '🏆 $streak dias seguidos';
        } else if (streak != null && streak > 1) {
          badge = '🔥 $streak dias de ofensiva';
        }

        return _NarrativeSessionCard(
          headline: headline,
          timeLabel: time.isNotEmpty ? time : null,
          badge: badge,
        );

      case FeedEventType.joinedClub:
        return _EventCard(
          icon: Icons.groups_outlined,
          color: AppColors.warmGoldLight,
          headline: 'Entrou para um clube de leitura',
          detail: 'A comunidade cresceu.',
        );

      case FeedEventType.betResolved:
        return _EventCard(
          icon: Icons.emoji_events_outlined,
          color: AppColors.warmGold,
          headline: 'Aposta encerrada',
          detail: item.bookTitle,
        );

      case FeedEventType.pollOpened:
        return _EventCard(
          icon: Icons.how_to_vote_outlined,
          color: AppColors.forestGreenLight,
          headline: 'Abriu uma votação no clube',
          detail: item.bookTitle,
        );

      case FeedEventType.pollClosed:
        return _EventCard(
          icon: Icons.poll_outlined,
          color: AppColors.forestGreen,
          headline: 'Votação encerrada',
          detail: item.bookTitle,
        );

      case FeedEventType.challengeStarted:
        return _EventCard(
          icon: Icons.sports_score_outlined,
          color: AppColors.warmGoldLight,
          headline: 'Novo desafio no clube! 💪',
          detail: item.bookTitle,
        );

      case FeedEventType.challengeFinished:
        return _EventCard(
          icon: Icons.emoji_events_rounded,
          color: AppColors.warmGold,
          headline: 'Desafio concluído com sucesso!',
          detail: item.bookTitle,
        );

      case FeedEventType.sealAwarded:
        return _EventCard(
          icon: Icons.workspace_premium_outlined,
          color: AppColors.warmGoldLight,
          headline: 'Recebeu um selo do clube',
          detail: item.bookTitle,
        );

      case FeedEventType.bookReview:
        return _EventCard(
          icon: Icons.rate_review_outlined,
          color: AppColors.warmGold,
          headline: item.bookTitle != null
              ? 'Publicou uma resenha de "${item.bookTitle}"'
              : 'Publicou uma resenha',
          detail: null,
        );
    }
  }
}

// ── Card narrativo para sessões de leitura ────────────────────────────────────
// Formato mais rico que o _EventCard padrão: destaca o tempo e badge de streak.

class _NarrativeSessionCard extends StatelessWidget {
  final String headline;
  final String? timeLabel;
  final String? badge;

  const _NarrativeSessionCard({
    required this.headline,
    this.timeLabel,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.forestGreenLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.forestGreenLight.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 22, color: AppColors.forestGreenLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (timeLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(timeLabel!,
                          style: AppTextStyles.labelMedium),
                    ],
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warmGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.warmGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Card rico para eventos "terminou de ler" — exibe rating, review e tempo.
class _FinishedBookCard extends StatelessWidget {
  final FeedItem item;

  const _FinishedBookCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.forestGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 22, color: AppColors.forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Narrativa humanizada — "Artur terminou de ler 'O Hobbit' em 4h 30min."
                Text(
                  item.humanNarrative(),
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (item.rating != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < item.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: i < item.rating!
                            ? AppColors.warmGold
                            : AppColors.border,
                      );
                    }),
                  ),
                ],
                if (item.review != null && item.review!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${item.review!}"',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.readingTimeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        item.readingTimeLabel,
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _EventCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String headline;
  final String? detail;

  const _EventCard({
    required this.icon,
    required this.color,
    required this.headline,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friends Tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_friendsListProvider);

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (friends) {
        if (friends.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            message: 'Você ainda não tem amigos.\nBusque pelo nome na aba Amigos.',
            action: TextButton.icon(
              onPressed: () => context.push('/friends'),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Adicionar amigos'),
            ),
          );
        }

        // Ordena: ativos primeiro → recentes → sem presença (por data de amizade)
        final sorted = [...friends]..sort((a, b) {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            if (a.isRecentlyActive && !b.isRecentlyActive) return -1;
            if (!a.isRecentlyActive && b.isRecentlyActive) return 1;
            if (a.lastSeenAt != null && b.lastSeenAt != null) {
              return b.lastSeenAt!.compareTo(a.lastSeenAt!);
            }
            return 0;
          });

        // Conta quantos estão ativos/recentes para mostrar kicker
        final activeCount = sorted.where((f) => f.isRecentlyActive).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_friendsListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: sorted.length + (activeCount > 0 ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              // Kicker "LENDO AGORA" antes do primeiro ativo
              if (activeCount > 0 && i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'LENDO AGORA · $activeCount',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.forestGreen,
                      letterSpacing: 1.2,
                    ),
                  ),
                );
              }
              final idx = activeCount > 0 ? i - 1 : i;
              return _FriendSocialTile(friend: sorted[idx]);
            },
          ),
        );
      },
    );
  }
}

class _FriendSocialTile extends StatelessWidget {
  final Friend friend;

  const _FriendSocialTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final presence = friend.presenceLabel;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          _MiniAvatar(
            url: friend.avatarUrl,
            name: friend.name ?? '?',
            radius: 22,
          ),
          if (friend.isRecentlyActive)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: friend.isActive
                      ? AppColors.forestGreen
                      : AppColors.warmGold,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        friend.name ?? 'Usuário',
        style: AppTextStyles.titleMedium,
      ),
      subtitle: presence != null
          ? Text(
              presence,
              style: AppTextStyles.bodyMedium.copyWith(
                color: friend.isActive
                    ? AppColors.forestGreen
                    : AppColors.textMuted,
                fontWeight: friend.isActive
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            )
          : (friend.bio != null && friend.bio!.isNotEmpty
              ? Text(
                  friend.bio!,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textMuted, size: 20),
      onTap: () => context.push('/friends/profile/${friend.friendId}'),
    );
  }
}

// ── Clubs Preview Tab ─────────────────────────────────────────────────────────

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const _MiniAvatar({required this.url, required this.name, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url!),
        backgroundColor: AppColors.border,
      );
    }
    final initials = _initials(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
