import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/providers/providers.dart';
import '../widgets/invite_friend_sheet.dart';

// ── Providers ────────────────────────────────────────────────────────────

final _friendsProvider = FutureProvider<List<Friend>>((ref) {
  return ref.watch(friendsRepositoryProvider).listFriends();
});

final _pendingReceivedProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendsRepositoryProvider).listPendingReceived();
});

final _pendingSentProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendsRepositoryProvider).listPendingSent();
});

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider<List<PublicProfile>>((ref) async {
  final q = ref.watch(_searchQueryProvider);
  if (q.trim().length < 2) return [];
  return ref.read(friendsRepositoryProvider).searchByName(q);
});

// ── Screen ───────────────────────────────────────────────────────────────

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(_friendsProvider);
    ref.invalidate(_pendingReceivedProvider);
    ref.invalidate(_pendingSentProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(_pendingReceivedProvider);
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return LumenTexturedBackground(
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Amigos'),
        actions: [
          IconButton(
            tooltip: 'Convidar amigo',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showInviteSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.forestGreen,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.forestGreen,
          tabs: [
            const Tab(text: 'Meus amigos'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendentes'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    _Badge(count: pendingCount),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Buscar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FriendsTab(onRefresh: _invalidateAll),
          _PendingTab(onRefresh: _invalidateAll),
          _SearchTab(controller: _searchController),
        ],
      ),
    )
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const InviteFriendSheet(),
    );
  }
}

// ── Tab: Meus Amigos ─────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _FriendsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_friendsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (friends) {
        if (friends.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message: 'Você ainda não tem amigos.\nUse a aba "Buscar" para encontrar leitores.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (_, i) => _FriendTile(
              friend: friends[i],
              onRemoved: onRefresh,
            ),
          ),
        );
      },
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final Friend friend;
  final VoidCallback onRemoved;

  const _FriendTile({required this.friend, required this.onRemoved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _SmallAvatar(url: friend.avatarUrl, name: friend.name ?? '?'),
      title: Text(friend.name ?? 'Leitor'),
      subtitle: friend.bio != null && friend.bio!.isNotEmpty
          ? Text(friend.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showOptions(context, ref),
      ),
      onTap: () => context.push('/friends/profile/${friend.friendId}'),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Ver perfil'),
              onTap: () {
                Navigator.pop(context);
                context.push('/friends/profile/${friend.friendId}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: AppColors.error),
              title: const Text('Remover amigo',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(friendsRepositoryProvider)
                    .removeFriend(friend.friendId);
                onRemoved();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Pendentes ───────────────────────────────────────────────────────

class _PendingTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _PendingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivedAsync = ref.watch(_pendingReceivedProvider);
    final sentAsync = ref.watch(_pendingSentProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recebidas
        receivedAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Erro: $e'),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Recebidas (${list.length})'),
                const SizedBox(height: 8),
                ...list.map((r) => _RequestTile(
                      request: r,
                      isSent: false,
                      onAction: onRefresh,
                    )),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // Enviadas
        sentAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Erro: $e'),
          data: (list) {
            if (list.isEmpty) {
              final receivedEmpty =
                  receivedAsync.valueOrNull?.isEmpty ?? true;
              if (receivedEmpty) {
                return const _EmptyState(
                  icon: Icons.hourglass_empty_outlined,
                  message: 'Nenhuma solicitação pendente.',
                );
              }
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Enviadas (${list.length})'),
                const SizedBox(height: 8),
                ...list.map((r) => _RequestTile(
                      request: r,
                      isSent: true,
                      onAction: onRefresh,
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final FriendRequest request;
  final bool isSent;
  final VoidCallback onAction;

  const _RequestTile({
    required this.request,
    required this.isSent,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _SmallAvatar(
          url: request.otherAvatarUrl,
          name: request.otherName ?? '?',
        ),
        title: Text(request.otherName ?? 'Leitor'),
        trailing: isSent
            ? TextButton(
                onPressed: () async {
                  await ref
                      .read(friendsRepositoryProvider)
                      .cancelRequest(request.id);
                  onAction();
                },
                child: const Text('Cancelar'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Aceitar',
                    icon: const Icon(Icons.check_circle_outline,
                        color: AppColors.success),
                    onPressed: () async {
                      await ref
                          .read(friendsRepositoryProvider)
                          .acceptRequest(request.id);
                      onAction();
                    },
                  ),
                  IconButton(
                    tooltip: 'Recusar',
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppColors.error),
                    onPressed: () async {
                      await ref
                          .read(friendsRepositoryProvider)
                          .declineRequest(request.id);
                      onAction();
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Tab: Buscar ──────────────────────────────────────────────────────────

class _SearchTab extends ConsumerStatefulWidget {
  final TextEditingController controller;
  const _SearchTab({required this.controller});

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: widget.controller,
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Buscar por nome…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) =>
                ref.read(_searchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: query.trim().length < 2
              ? const _EmptyState(
                  icon: Icons.search,
                  message: 'Digite pelo menos 2 caracteres para buscar.',
                )
              : resultsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (results) {
                    if (results.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.person_search_outlined,
                        message: 'Nenhum usuário encontrado.',
                      );
                    }
                    return ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) =>
                          _SearchResultTile(profile: results[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final PublicProfile profile;
  const _SearchResultTile({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _SmallAvatar(url: profile.avatarUrl, name: profile.name ?? '?'),
      title: Text(profile.name ?? 'Leitor'),
      subtitle: profile.bio != null && profile.bio!.isNotEmpty
          ? Text(profile.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/friends/profile/${profile.id}'),
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _SmallAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(url!),
        backgroundColor: AppColors.forestGreen.withValues(alpha: 0.12),
      );
    }
    final initials = _initials(name);
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
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
