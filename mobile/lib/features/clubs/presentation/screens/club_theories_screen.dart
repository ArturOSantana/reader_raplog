import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _theoriesProvider =
    FutureProvider.family<List<ClubTheory>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listTheories(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela de Teorias do clube.
///
/// Modelo narrativo: cada teoria tem estado (em aberto / confirmada / errada)
/// definido pelo desenrolar do livro — fundamentalmente diferente de poll.
/// Usa [LumenTheoryRow] com tag de status e contador de votos.
/// Sem card colorido, sem coração preenchido, sem ranking.
class ClubTheoriesScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final bool canManage;
  final String? coverUrl;

  const ClubTheoriesScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.canManage = false,
    this.coverUrl,
  });

  @override
  ConsumerState<ClubTheoriesScreen> createState() =>
      _ClubTheoriesScreenState();
}

class _ClubTheoriesScreenState extends ConsumerState<ClubTheoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final theoriesAsync = ref.watch(_theoriesProvider(widget.clubId));

    return LumenClubTintBackground(
      coverUrl: widget.coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teorias',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              widget.clubName,
              style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: LumenIcon('add', size: 20),
            tooltip: 'Nova teoria',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: theoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.progress),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar as teorias.',
              style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (theories) {
          if (theories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nenhuma teoria ainda.',
                      style:
                          ReadLogType.bookTitle(size: 18, color: ReadLogColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Compartilhe o que você acha que vai acontecer.',
                      textAlign: TextAlign.center,
                      style: ReadLogType.authorName(color: ReadLogColors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_theoriesProvider(widget.clubId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              itemCount: theories.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: ReadLogColors.hairline),
              itemBuilder: (context, i) => _TheoryTile(
                theory: theories[i],
                canManage: widget.canManage,
                onVote: () async {
                  await ref
                      .read(bookClubRepositoryProvider)
                      .toggleTheoryVote(theories[i].id);
                  ref.invalidate(_theoriesProvider(widget.clubId));
                },
                onSetStatus: widget.canManage
                    ? (status) async {
                        await ref
                            .read(bookClubRepositoryProvider)
                            .setTheoryStatus(
                              theoryId: theories[i].id,
                              status: status,
                            );
                        ref.invalidate(_theoriesProvider(widget.clubId));
                      }
                    : null,
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ReadLogColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _AddTheorySheet(
        clubId: widget.clubId,
        onAdded: () => ref.invalidate(_theoriesProvider(widget.clubId)),
      ),
    );
  }
}

// ── Tile de teoria — LumenTheoryRow + interação ───────────────────────────────

class _TheoryTile extends StatelessWidget {
  final ClubTheory theory;
  final bool canManage;
  final VoidCallback onVote;
  final void Function(String status)? onSetStatus;

  const _TheoryTile({
    required this.theory,
    required this.canManage,
    required this.onVote,
    this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Mapeia o enum para os parâmetros do LumenTheoryRow
    final statusStr = switch (theory.status) {
      TheoryStatus.confirmed => 'confirmed',
      TheoryStatus.wrong     => 'wrong',
      TheoryStatus.open      => 'pending',
    };

    return GestureDetector(
      onLongPress: canManage ? () => _showStatusMenu(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LumenTheoryRow(
              text: theory.content,
              votes: theory.voteCount,
              status: statusStr,
            ),
            // Metadados: autor + data
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  theory.createdByName ?? 'Membro',
                  style:
                      ReadLogType.mono(size: 10, color: ReadLogColors.inkGhost),
                ),
                // Voto — texto link, sem coração preenchido
                GestureDetector(
                  onTap: onVote,
                  child: Text(
                    theory.votedByMe ? 'votado' : 'votar',
                    style: ReadLogType.mono(
                      size: 10,
                      color: theory.votedByMe
                          ? ReadLogColors.inkMuted
                          : ReadLogColors.ink,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReadLogColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Atualizar status',
                style: ReadLogType.kicker(
                    size: 10, color: ReadLogColors.inkGhost)
                    .copyWith(letterSpacing: 1.2),
              ),
            ),
            for (final (label, value) in [
              ('Em aberto', 'open'),
              ('Confirmada', 'confirmed'),
              ('Errada', 'wrong'),
            ])
              ListTile(
                title: Text(label,
                    style: ReadLogType.authorName(
                        size: 14, color: ReadLogColors.ink)),
                onTap: () {
                  Navigator.pop(context);
                  onSetStatus?.call(value);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Sheet para adicionar teoria ───────────────────────────────────────────────

class _AddTheorySheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onAdded;

  const _AddTheorySheet({required this.clubId, required this.onAdded});

  @override
  ConsumerState<_AddTheorySheet> createState() => _AddTheorySheetState();
}

class _AddTheorySheetState extends ConsumerState<_AddTheorySheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(bookClubRepositoryProvider).addTheory(
            clubId: widget.clubId,
            content: text,
          );
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar teoria: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nova teoria',
              style: ReadLogType.display(
                size: 18,
                color: ReadLogColors.ink,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O que você acha que vai acontecer no livro?',
              style: ReadLogType.authorName(
                  size: 13, color: ReadLogColors.inkMuted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 4,
              maxLength: 400,
              decoration: const InputDecoration(
                hintText: 'Escreva sua teoria...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publicar teoria'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
