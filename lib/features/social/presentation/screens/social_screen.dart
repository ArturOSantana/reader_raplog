import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/models/social_feed.dart';
import '../../../../shared/providers/providers.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
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

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onLikeToggle;

  const _FeedCard({required this.item, required this.onLikeToggle});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(item.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
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
                // Conteúdo do evento
                _FeedEventContent(item: item),
                const SizedBox(height: 10),
                // Like
                GestureDetector(
                  onTap: onLikeToggle,
                  child: Row(
                    children: [
                      Icon(
                        item.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                        color: item.likedByMe
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.likesCount}',
                        style: AppTextStyles.labelMedium,
                      ),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    return 'há ${diff.inDays} dias';
  }
}

class _FeedEventContent extends StatelessWidget {
  final FeedItem item;

  const _FeedEventContent({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.eventType) {
      case FeedEventType.finishedBook:
        return _EventCard(
          emoji: '✅',
          color: AppColors.forestGreen,
          lines: [
            'Terminou de ler',
            if (item.bookTitle != null) item.bookTitle!,
            if (item.rating != null) '⭐' * item.rating!,
          ],
        );
      case FeedEventType.startedBook:
        return _EventCard(
          emoji: '📖',
          color: AppColors.forestGreenLight,
          lines: [
            'Começou a ler',
            if (item.bookTitle != null) item.bookTitle!,
          ],
        );
      case FeedEventType.streak:
        return _EventCard(
          emoji: '🔥',
          color: AppColors.warmGold,
          lines: [
            'Ofensiva de',
            '${item.streakDays ?? 0} dias lendo!',
          ],
        );
      case FeedEventType.achievement:
        return _EventCard(
          emoji: '🏅',
          color: AppColors.warmGoldLight,
          lines: [
            'Conquista desbloqueada',
            if (item.achievementName != null) item.achievementName!,
          ],
        );
      case FeedEventType.goalCompleted:
        return _EventCard(
          emoji: '🎯',
          color: AppColors.forestGreen,
          lines: [
            'Completou a meta',
            if (item.goalDescription != null) item.goalDescription!,
          ],
        );
    }
  }
}

class _EventCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final List<String> lines;

  const _EventCard({
    required this.emoji,
    required this.color,
    required this.lines,
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
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((l) => Text(
                        l,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: lines.indexOf(l) == 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ))
                  .toList(),
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _FriendSocialTile(friend: friends[i]),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: _MiniAvatar(
        url: friend.avatarUrl,
        name: friend.name ?? '?',
        radius: 22,
      ),
      title: Text(
        friend.name ?? 'Usuário',
        style: AppTextStyles.titleMedium,
      ),
      subtitle: friend.bio != null && friend.bio!.isNotEmpty
          ? Text(
              friend.bio!,
              style: AppTextStyles.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
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
