import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/providers/providers.dart';

/// Sheet para selecionar um clube e convidar um amigo.
class InviteToClubSheet extends ConsumerWidget {
  final String friendId;
  final String? friendName;

  const InviteToClubSheet({
    super.key,
    required this.friendId,
    this.friendName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myClubsAsync = ref.watch(_myClubsForInviteProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Convidar para clube',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Escolha um clube para convidar ${friendName ?? "seu amigo"}',
            style: AppTextStyles.bodyMedium,
          ),

          const SizedBox(height: 24),

          // Lista de clubes
          myClubsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (clubs) {
              if (clubs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Você não tem clubes ainda.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: clubs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 0),
                  itemBuilder: (_, i) => _ClubInviteTile(
                    club: clubs[i],
                    friendId: friendId,
                    onInvited: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Provider dos meus clubes que podem receber convites
final _myClubsForInviteProvider = FutureProvider<List<BookClub>>((ref) async {
  final clubs = await ref.watch(bookClubRepositoryProvider).listMyClubs();
  // Filtra apenas clubes ativos onde o usuário é admin ou owner
  return clubs.where((c) => c.isActive && c.canManage).toList();
});

/// Tile de cada clube na lista de seleção
class _ClubInviteTile extends ConsumerWidget {
  final BookClub club;
  final String friendId;
  final VoidCallback onInvited;

  const _ClubInviteTile({
    required this.club,
    required this.friendId,
    required this.onInvited,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(club.name),
      subtitle: Text(
        '${club.memberCount} membro${club.memberCount != 1 ? 's' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: FilledButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Convidar'),
        onPressed: () => _invite(context, ref),
      ),
      onTap: () => _invite(context, ref),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      // Adiciona o amigo como membro do clube com papel 'member'
      await ref
          .read(bookClubRepositoryProvider)
          .addMemberToClub(club.id, friendId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${club.name}: convite enviado!'),
            duration: const Duration(seconds: 2),
          ),
        );
        onInvited();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao convidar: $e')),
        );
      }
    }
  }
}
