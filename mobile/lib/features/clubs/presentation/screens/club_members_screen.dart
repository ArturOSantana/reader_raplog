import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _clubMembersProvider =
    FutureProvider.family<List<ClubMember>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listMembers(clubId);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ClubMembersScreen extends ConsumerWidget {
  final String clubId;

  const ClubMembersScreen({
    super.key,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_clubMembersProvider(clubId));

    return LumenTexturedBackground(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          backgroundColor: AppColors.offWhite,
          foregroundColor: AppColors.textPrimary,
          title: const Text('Membros', style: AppTextStyles.titleMedium),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_clubMembersProvider(clubId));
          },
          child: membersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (members) {
              if (members.isEmpty) {
                return const Center(
                  child: Text('Nenhum membro encontrado.'),
                );
              }

              // Ordena: owner → admins → mentors → members
              final sorted = _sortMembers(members);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _MemberTile(
                  member: sorted[i],
                  clubId: clubId,
                  onChanged: () => ref.invalidate(_clubMembersProvider(clubId)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<ClubMember> _sortMembers(List<ClubMember> members) {
    final roleOrder = {'owner': 0, 'admin': 1, 'mentor': 2, 'member': 3};
    final sorted = List<ClubMember>.from(members);
    sorted.sort((a, b) {
      final orderA = roleOrder[a.role] ?? 999;
      final orderB = roleOrder[b.role] ?? 999;
      return orderA.compareTo(orderB);
    });
    return sorted;
  }
}

// ── Tile de Membro ───────────────────────────────────────────────────────────

class _MemberTile extends ConsumerWidget {
  final ClubMember member;
  final String clubId;
  final VoidCallback onChanged;

  const _MemberTile({
    required this.member,
    required this.clubId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _MemberAvatar(
        url: member.avatarUrl,
        name: member.name ?? '?',
      ),
      title: Text(member.name ?? 'Leitor'),
      subtitle: Text(
        member.roleLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      trailing: member.canManage
          ? null
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context, ref),
            ),
      onTap: member.canManage
          ? null
          : () => _showOptions(context, ref),
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
                // TODO: Navegar para perfil do membro
              },
            ),
            if (member.role != 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Promover a admin'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(bookClubRepositoryProvider)
                      .promoteMember(clubId, member.userId);
                  onChanged();
                },
              ),
            if (member.role == 'admin')
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Rebaixar para membro'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(bookClubRepositoryProvider)
                      .demoteMember(clubId, member.userId);
                  onChanged();
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: AppColors.error,
              ),
              title: const Text(
                'Remover do clube',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmRemoval(context);
                if (confirmed) {
                  await ref
                      .read(bookClubRepositoryProvider)
                      .removeMember(clubId, member.userId);
                  onChanged();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmRemoval(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text(
          'Deseja remover ${member.name ?? "este membro"} do clube?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Avatar do Membro ─────────────────────────────────────────────────────────

class _MemberAvatar extends StatelessWidget {
  final String? url;
  final String name;

  const _MemberAvatar({
    required this.url,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url!),
      );
    }

    return CircleAvatar(
      backgroundColor: AppColors.forestGreen,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: AppColors.offWhite,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return (name.isNotEmpty ? name[0] : '?').toUpperCase();
  }
}
