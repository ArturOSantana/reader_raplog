import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/providers/providers.dart';

// Providers locais

final _publicProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).fetchPublicProfile(userId);
});

final _relationshipProvider =
    FutureProvider.family<String, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).relationshipStatus(userId);
});

// Screen

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_publicProfileProvider(userId));
    final relAsync = ref.watch(_relationshipProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Não foi possível carregar o perfil.')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          return _ProfileBody(
            profile: profile,
            relAsync: relAsync,
            onAction: () {
              ref.invalidate(_relationshipProvider(userId));
            },
          );
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final PublicProfile profile;
  final AsyncValue<String> relAsync;
  final VoidCallback onAction;

  const _ProfileBody({
    required this.profile,
    required this.relAsync,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(child: _Avatar(url: profile.avatarUrl, name: profile.name ?? '?')),
        const SizedBox(height: 16),
        if (profile.name != null && profile.name!.isNotEmpty)
          Center(
            child: Text(
              profile.name!,
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
        if (profile.bio != null && profile.bio!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                profile.bio!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (profile.favoriteGenre != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 14, color: AppColors.forestGreen),
                const SizedBox(width: 6),
                Text('Gênero favorito: ${profile.favoriteGenre}',
                    style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        const SizedBox(height: 32),
        relAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
          data: (rel) => _ActionButton(
            relationship: rel,
            profile: profile,
            onAction: onAction,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final String relationship;
  final PublicProfile profile;
  final VoidCallback onAction;

  const _ActionButton({
    required this.relationship,
    required this.profile,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (relationship) {
      'friend' => OutlinedButton.icon(
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Já são amigos'),
          onPressed: () => _confirmRemove(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      'pending_sent' => OutlinedButton.icon(
          icon: const Icon(Icons.hourglass_top_outlined),
          label: const Text('Solicitação enviada'),
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
          ),
        ),
      'pending_received' => FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Aceitar solicitação'),
          onPressed: () async {
            // Precisamos do request id — busca novamente
            final req = await ref
                .read(friendsRepositoryProvider)
                .listPendingReceived();
            final match = req
                .where((r) => r.senderId == profile.id)
                .firstOrNull;
            if (match != null) {
              await ref
                  .read(friendsRepositoryProvider)
                  .acceptRequest(match.id);
              onAction();
            }
          },
        ),
      _ => FilledButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Adicionar amigo'),
          onPressed: () async {
            await ref
                .read(friendsRepositoryProvider)
                .sendRequest(profile.id);
            onAction();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Solicitação de amizade enviada!')),
              );
            }
          },
        ),
    };
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover amigo'),
        content:
            Text('Deseja remover ${profile.name ?? "este usuário"} da sua lista de amigos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(friendsRepositoryProvider)
                  .removeFriend(profile.id);
              onAction();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(url!),
        backgroundColor: AppColors.forestGreen.withValues(alpha: 0.12),
      );
    }
    final initials = _initials(name);
    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
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
