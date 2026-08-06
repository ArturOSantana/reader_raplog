import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/lumen_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/providers/providers.dart';

/// Sheet para selecionar amigos e convidá-los para um clube.
/// Oferece busca e seleção múltipla.
class InviteMultipleFriendsSheet extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  const InviteMultipleFriendsSheet({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<InviteMultipleFriendsSheet> createState() =>
      _InviteMultipleFriendsSheetState();
}

class _InviteMultipleFriendsSheetState
    extends ConsumerState<InviteMultipleFriendsSheet> {
  final _searchController = TextEditingController();
  final _selectedFriends = <String>{}; // Set de friendIds selecionados
  bool _isInviting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(_allFriendsProvider);
    final query = _searchController.text.toLowerCase().trim();

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
            'Convidar amigos',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Selecione amigos para convidar a ${widget.clubName}',
            style: AppTextStyles.bodyMedium,
          ),

          const SizedBox(height: 16),

          // Campo de busca
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar amigos…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
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

          // Lista de amigos
          Flexible(
            child: friendsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (friends) {
                // Filtra amigos por query
                final filtered = friends.where((f) {
                  final name = (f.name ?? '').toLowerCase();
                  return query.isEmpty || name.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        query.isEmpty
                            ? 'Nenhum amigo encontrado'
                            : 'Nenhum resultado para "$query"',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _FriendCheckboxTile(
                    friend: filtered[i],
                    isSelected: _selectedFriends.contains(filtered[i].friendId),
                    onChanged: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFriends.add(filtered[i].friendId);
                        } else {
                          _selectedFriends.remove(filtered[i].friendId);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Botões de ação
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _selectedFriends.isEmpty
                        ? 'Convidar'
                        : 'Convidar ${_selectedFriends.length}',
                  ),
                  onPressed: _selectedFriends.isEmpty || _isInviting
                      ? null
                      : () => _inviteSelected(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _inviteSelected(BuildContext context) async {
    if (_selectedFriends.isEmpty) return;

    setState(() => _isInviting = true);

    try {
      final repo = ref.read(bookClubRepositoryProvider);
      int successCount = 0;

      for (final friendId in _selectedFriends) {
        try {
          await repo.addMemberToClub(widget.clubId, friendId);
          successCount++;
        } catch (_) {
          // Silencia erros individuais, continua tentando outros
        }
      }

      if (mounted) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successCount > 0
                    ? 'Convites enviados para $successCount amigo${successCount != 1 ? "s" : ""}'
                    : 'Erro ao convidar amigos',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _allFriendsProvider = FutureProvider<List<Friend>>((ref) {
  return ref.watch(friendsRepositoryProvider).listFriends();
});

// ── Tile com Checkbox ────────────────────────────────────────────────────────

class _FriendCheckboxTile extends StatelessWidget {
  final Friend friend;
  final bool isSelected;
  final Function(bool) onChanged;

  const _FriendCheckboxTile({
    required this.friend,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: isSelected,
      onChanged: (val) => onChanged(val ?? false),
      title: Text(friend.name ?? 'Leitor'),
      subtitle: friend.bio != null && friend.bio!.isNotEmpty
          ? Text(
              friend.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      secondary: _FriendAvatar(
        url: friend.avatarUrl,
        name: friend.name ?? '?',
      ),
    );
  }
}

// ── Avatar do Amigo ─────────────────────────────────────────────────────────

class _FriendAvatar extends StatelessWidget {
  final String? url;
  final String name;

  const _FriendAvatar({
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
