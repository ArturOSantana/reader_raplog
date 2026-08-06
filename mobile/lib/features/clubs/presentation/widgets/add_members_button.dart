import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/lumen_theme.dart';
import '../../../../shared/providers/providers.dart';

/// Button to add friends to club — can be used in AppBar or elsewhere.
class AddMembersButton extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const AddMembersButton({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Adicionar membros',
      icon: const Icon(Icons.person_add_outlined),
      onPressed: () => _showAddMembersSheet(context),
    );
  }

  void _showAddMembersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SimpleAddMembersSheet(
        clubId: clubId,
        clubName: clubName,
      ),
    );
  }
}

// ── Simple Add Members Sheet ─────────────────────────────────────────────────

class _SimpleAddMembersSheet extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  const _SimpleAddMembersSheet({
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<_SimpleAddMembersSheet> createState() =>
      _SimpleAddMembersSheetState();
}

class _SimpleAddMembersSheetState
    extends ConsumerState<_SimpleAddMembersSheet> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(_friendsForInviteProvider);
    final query = _searchController.text.toLowerCase();

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

          Text('Adicionar membros', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Escolha amigos para adicionar a ${widget.clubName}',
            style: AppTextStyles.bodyMedium,
          ),

          const SizedBox(height: 16),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar amigos…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Friends list
          Flexible(
            child: friendsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (friends) {
                final filtered = friends.where((f) {
                  return query.isEmpty ||
                      (f.name ?? '').toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        query.isEmpty
                            ? 'Nenhum amigo encontrado'
                            : 'Nenhum resultado',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final friend = filtered[i];
                    return CheckboxListTile(
                      value: _selectedIds.contains(friend.friendId),
                      onChanged: (v) {
                        setState(() {
                          if (v ?? false) {
                            _selectedIds.add(friend.friendId);
                          } else {
                            _selectedIds.remove(friend.friendId);
                          }
                        });
                      },
                      title: Text(friend.name ?? 'Leitor'),
                      subtitle: friend.bio != null && friend.bio!.isNotEmpty
                          ? Text(
                              friend.bio!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Action button
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(
                    _selectedIds.isEmpty
                        ? 'Adicionar'
                        : 'Adicionar ${_selectedIds.length}',
                  ),
                  onPressed: _isLoading || _selectedIds.isEmpty
                      ? null
                      : _handleAddMembers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddMembers() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(bookClubRepositoryProvider);
      int count = 0;
      for (final id in _selectedIds) {
        try {
          await repo.addMemberToClub(widget.clubId, id);
          count++;
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count membro${count != 1 ? "s" : ""} adicionado${count != 1 ? "s" : ""}'
                  : 'Erro ao adicionar',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _friendsForInviteProvider =
    FutureProvider<List<({String friendId, String? name, String? bio})>>((ref) async {
  final friends = await ref.watch(friendsRepositoryProvider).listFriends();
  return friends
      .map((f) => (friendId: f.friendId, name: f.name, bio: f.bio))
      .toList();
});
