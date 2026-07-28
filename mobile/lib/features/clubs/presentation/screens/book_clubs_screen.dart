import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../../theme/readlog_components.dart';

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
    return Scaffold(
      backgroundColor: ReadLogColors.paper,
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
                  icon: const Icon(Icons.search,
                      size: 20, color: ReadLogColors.charcoal),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.add,
                      size: 22, color: ReadLogColors.charcoal),
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
  bool _fabOpen = false;

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

    return Stack(
      children: [
        clubsAsync.when(
          loading: () => const SkelScreenList(),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (clubs) {
            final filtered = _applyFilter(clubs);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Barra de busca ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar clube...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                // ── Chips de filtro — ReadLogChip ──────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: _ClubFilter.values
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ReadLogChip(
                              label: f.label,
                              isSelected: _activeFilter == f,
                              onTap: () =>
                                  setState(() => _activeFilter = f),
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return ReadLogClubCard(
                            clubName: c.name,
                            currentBookTitle:
                                c.currentBookTitle ?? 'Sem livro definido',
                            currentBookAuthor:
                                c.currentBookAuthor ?? '',
                            progress: 0,
                            memberCount: c.memberCount,
                            streakDays: 0,
                            status: c.isClosed
                                ? ReadLogClubStatus.archived
                                : c.isOnVacation
                                    ? ReadLogClubStatus.vacation
                                    : ReadLogClubStatus.active,
                            isOwner: c.isOwner,
                            onTap: () =>
                                context.push('/clubs/${c.id}'),
                          );
                        },
                      ),
                    ),
                ),
              ],
            );
          },
        ),
        // ── FAB posicionado dentro do Stack para funcionar em TabBarView ──
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _fabOpen = false),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        if (_fabOpen) ...[
          Positioned(
            right: 20,
            bottom: 84,
            child: _FabMenuItem(
              icon: Icons.login,
              label: 'Entrar com código',
              onTap: () {
                setState(() => _fabOpen = false);
                _showJoinSheet(context);
              },
            ),
          ),
          Positioned(
            right: 20,
            bottom: 140,
            child: _FabMenuItem(
              icon: Icons.add,
              label: 'Criar clube',
              onTap: () {
                setState(() => _fabOpen = false);
                _showCreateSheet(context);
              },
            ),
          ),
        ],
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'clubs_fab',
            onPressed: () => setState(() => _fabOpen = !_fabOpen),
            backgroundColor: AppColors.forestGreen,
            foregroundColor: Colors.white,
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateClubSheet(
        onCreated: (club) {
          ref.invalidate(_myClubsProvider);
          if (context.mounted) context.push('/clubs/${club.id}');
        },
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
            Icon(
              Icons.library_add_outlined,
              size: 48,
              color: ReadLogColors.charcoal.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 20),
            Text(
              hasClubs ? 'Nenhum clube encontrado' : 'Você ainda não\nestá em nenhum clube',
              style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasClubs
                  ? 'Tente ajustar os filtros ou a busca.'
                  : 'Crie um clube, convide amigos\ne leiam juntos.',
              style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.charcoal.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasClubs) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Criar clube'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ReadLogColors.charcoal,
                  side: const BorderSide(color: ReadLogColors.paperDeep),
                  textStyle: ReadLogType.mono(size: 12, weight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Entrar com código'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ReadLogColors.brass,
                  side: BorderSide(color: ReadLogColors.brass.withValues(alpha: 0.5)),
                  textStyle: ReadLogType.mono(size: 12, weight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
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
            Text('Novo clube', style: AppTextStyles.headlineMedium),
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
                const Text('Visibilidade:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
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
              child: FilledButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
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
        _toggle(ClubVisibility.private, Icons.lock_outline, 'Privado'),
        const SizedBox(width: 8),
        _toggle(ClubVisibility.public, Icons.public, 'Público'),
      ],
    );
  }

  Widget _toggle(ClubVisibility v, IconData icon, String label) {
    final active = value == v;
    return GestureDetector(
      onTap: () => onChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.forestGreen.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.forestGreen : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    active ? AppColors.forestGreen : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.forestGreen : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB Menu Item ─────────────────────────────────────────────────────────────

class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.forestGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
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
            const SnackBar(content: Text('Código inválido ou clube não encontrado.')),
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
          const SnackBar(content: Text('Erro ao entrar no clube. Tente novamente.')),
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
          Text('Entrar em um clube', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Peça o código de convite ao dono ou admin do clube.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código de convite',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _join,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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
