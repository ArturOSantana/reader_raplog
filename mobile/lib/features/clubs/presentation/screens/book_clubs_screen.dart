import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _myClubsProvider = FutureProvider<List<BookClub>>((ref) {
  return ref.watch(bookClubRepositoryProvider).listMyClubs();
});

// ── Filtro ────────────────────────────────────────────────────────────────────

enum _ClubFilter {
  all,
  isOwner,
  isAdmin,
  isMember,
  active,
  onVacation,
  closed;

  String get label {
    switch (this) {
      case _ClubFilter.all:
        return 'Todos';
      case _ClubFilter.isOwner:
        return 'Proprietário';
      case _ClubFilter.isAdmin:
        return 'Administrador';
      case _ClubFilter.isMember:
        return 'Membro';
      case _ClubFilter.active:
        return 'Ativos';
      case _ClubFilter.onVacation:
        return 'Em férias';
      case _ClubFilter.closed:
        return 'Encerrados';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela completa com Scaffold + AppBar (usada na rota /clubs).
class BookClubsScreen extends ConsumerWidget {
  const BookClubsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LumenTexturedBackground(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: ReadLogPageHeader(
                kicker: 'SEÇÃO',
                title: 'Clubes',
                dark: false,
                showMenuButton: true,
                actions: [
                  IconButton(
                    icon: LumenIcon('search', size: 20, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Ação de criar/entrar — ícone + no topo, sem FAB
                  IconButton(
                    icon: LumenIcon('add', size: 22, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Expanded(child: BookClubsBody()),
          ],
        ),
      ),
    );
  }
}

/// Corpo reutilizável — pode ser embutido dentro de um TabBarView
/// sem conflito de Scaffold.
class BookClubsBody extends ConsumerStatefulWidget {
  const BookClubsBody({super.key});

  @override
  ConsumerState<BookClubsBody> createState() => _BookClubsBodyState();
}

class _BookClubsBodyState extends ConsumerState<BookClubsBody> {
  _ClubFilter _activeFilter = _ClubFilter.all;
  String _search = '';

  List<BookClub> _applyFilter(List<BookClub> clubs) {
    return clubs.where((c) {
      if (_search.isNotEmpty &&
          !c.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      switch (_activeFilter) {
        case _ClubFilter.all:
          return true;
        case _ClubFilter.isOwner:
          return c.isOwner;
        case _ClubFilter.isAdmin:
          return c.isAdmin;
        case _ClubFilter.isMember:
          return c.memberRole == 'member';
        case _ClubFilter.active:
          return c.isActive;
        case _ClubFilter.onVacation:
          return c.isOnVacation;
        case _ClubFilter.closed:
          return c.isClosed;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(_myClubsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final mutedColor  = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final ghostColor  = isDark ? LumenColors.inkGhostInverse : LumenColors.inkGhost;

    return clubsAsync.when(
      loading: () => const SkelScreenList(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (clubs) {
        final filtered = _applyFilter(clubs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra de busca ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar clube…',
                  hintStyle: ReadLogType.authorName(
                      color: ghostColor, size: 14),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: ghostColor),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // ── Abas de filtro — texto, sem chip preenchido ───────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: _ClubFilter.values
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = f),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f.label,
                                style: ReadLogType.authorName(
                                  size: 13,
                                  color: _activeFilter == f
                                      ? activeColor
                                      : mutedColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 1.5,
                                width: 20,
                                color: _activeFilter == f
                                    ? activeColor
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            // ── Lista ──────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      hasClubs: clubs.isNotEmpty,
                      onCreate: () => _showCreateSheet(context),
                      onJoin: () => _showJoinSheet(context),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(_myClubsProvider),
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return _ClubRow(
                            club: c,
                            onTap: () => context.push('/clubs/${c.id}'),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JoinClubSheet(
        onJoined: (club) {
          ref.invalidate(_myClubsProvider);
          if (context.mounted) context.push('/clubs/${club.id}');
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateClubSheet(
        onCreated: (club) {
          ref.invalidate(_myClubsProvider);
          if (context.mounted) context.push('/clubs/${club.id}');
        },
      ),
    );
  }
}

// ── Linha de clube — sem card, só linha com Divider ───────────────────────────

class _ClubRow extends StatelessWidget {
  final BookClub club;
  final VoidCallback onTap;

  const _ClubRow({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String statusText = '';
    if (club.isClosed) statusText = 'encerrado';
    if (club.isOnVacation) statusText = 'em férias';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: ReadLogType.bookTitle(size: 15)),
                  const SizedBox(height: 2),
                  Text(
                    club.currentBookTitle != null
                        ? '${club.currentBookTitle}'
                        : 'Sem livro definido',
                    style: ReadLogType.authorName(
                        color: ReadLogColors.inkMuted, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${club.memberCount} membros',
                      if (statusText.isNotEmpty) statusText,
                      if (club.isOwner) 'proprietário',
                      if (club.isAdmin && !club.isOwner) 'admin',
                    ].join(' · '),
                    style: ReadLogType.mono(
                        size: 11, color: ReadLogColors.inkGhost),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right,
                size: 18, color: ReadLogColors.inkGhost),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasClubs;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptyState({
    required this.hasClubs,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasClubs
                  ? 'Nenhum clube encontrado.'
                  : 'Você ainda não\nestá em nenhum clube.',
              style: ReadLogType.bookTitle(size: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasClubs
                  ? 'Tente ajustar os filtros ou a busca.'
                  : 'Crie um clube, convide amigos\ne leiam juntos.',
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 14),
              textAlign: TextAlign.center,
            ),
            if (!hasClubs) ...[
              const SizedBox(height: 28),
              TextButton(
                onPressed: onCreate,
                child: Text('Criar clube',
                    style: ReadLogType.authorName(size: 14)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onJoin,
                child: Text('Entrar com código',
                    style: ReadLogType.authorName(size: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Create Club Sheet ─────────────────────────────────────────────────────────

class _CreateClubSheet extends ConsumerStatefulWidget {
  final ValueChanged<BookClub> onCreated;

  const _CreateClubSheet({required this.onCreated});

  @override
  ConsumerState<_CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends ConsumerState<_CreateClubSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  ClubVisibility _visibility = ClubVisibility.private;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final club = await ref.read(bookClubRepositoryProvider).createClub(
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            visibility: _visibility,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(club);
      }
    } catch (e) {
      debugPrint('[CreateClub] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar clube: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Novo clube', style: ReadLogType.bookTitle(size: 20)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do clube',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Informe o nome do clube';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            const SizedBox(height: 4),
            // ── Visibilidade ─────────────────────────────────────────────
            Row(
              children: [
                Text('Visibilidade:',
                    style: ReadLogType.authorName(
                        color: ReadLogColors.inkMuted, size: 13)),
                const SizedBox(width: 12),
                _VisibilityToggle(
                  value: _visibility,
                  onChanged: (v) => setState(() => _visibility = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Criar clube'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visibility Toggle ─────────────────────────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  final ClubVisibility value;
  final ValueChanged<ClubVisibility> onChanged;

  const _VisibilityToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggle(ClubVisibility.private, 'Privado'),
        const SizedBox(width: 16),
        _toggle(ClubVisibility.public, 'Público'),
      ],
    );
  }

  Widget _toggle(ClubVisibility v, String label) {
    final active = value == v;
    return GestureDetector(
      onTap: () => onChanged(v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: ReadLogType.authorName(
              size: 13,
              color: active ? ReadLogColors.ink : ReadLogColors.inkMuted,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 1.5,
            width: 24,
            color: active ? ReadLogColors.ink : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ── Join Club Sheet ───────────────────────────────────────────────────────────

class _JoinClubSheet extends ConsumerStatefulWidget {
  final ValueChanged<BookClub> onJoined;

  const _JoinClubSheet({required this.onJoined});

  @override
  ConsumerState<_JoinClubSheet> createState() => _JoinClubSheetState();
}

class _JoinClubSheetState extends ConsumerState<_JoinClubSheet> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(bookClubRepositoryProvider);
      final club = await repo.fetchByInviteCode(code);
      if (club == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Código inválido ou clube não encontrado.')),
          );
        }
        return;
      }
      await repo.joinClub(club.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onJoined(club);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao entrar no clube. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entrar em um clube', style: ReadLogType.bookTitle(size: 20)),
          const SizedBox(height: 8),
          Text(
            'Peça o código de convite ao dono ou admin do clube.',
            style: ReadLogType.authorName(
                color: ReadLogColors.inkMuted, size: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código de convite',
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _join,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Entrar no clube'),
            ),
          ),
        ],
      ),
    );
  }
}
