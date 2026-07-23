import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_bets_and_polls.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _openPollsProvider =
    FutureProvider.family<List<ClubOpenPoll>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listOpenPolls(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela dedicada de Votações Livres — lista completa + criação + encerramento.
class ClubOpenPollsScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final bool canManage;

  const ClubOpenPollsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final pollsAsync = ref.watch(_openPollsProvider(clubId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Votações',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova votação',
              onPressed: () => _showCreateSheet(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_openPollsProvider(clubId)),
        child: pollsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (polls) {
            if (polls.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.poll_outlined,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma votação',
                        style: AppTextStyles.headlineMedium
                            .copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canManage
                            ? 'Crie uma votação para ouvir o clube.'
                            : 'Aguarde uma votação dos admins.',
                        style: AppTextStyles.labelMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Separa abertas das encerradas
            final open = polls.where((p) => p.isOpen).toList();
            final closed = polls.where((p) => !p.isOpen).toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (open.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.how_to_vote_outlined,
                    label: 'Abertas (${open.length})',
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(height: 8),
                  ...open.map((p) => _PollCard(
                        key: ValueKey(p.id),
                        poll: p,
                        clubId: clubId,
                        canManage: canManage,
                        onChanged: () => ref.invalidate(_openPollsProvider(clubId)),
                      )),
                  const SizedBox(height: 16),
                ],
                if (closed.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.lock_clock,
                    label: 'Encerradas (${closed.length})',
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  ...closed.map((p) => _PollCard(
                        key: ValueKey(p.id),
                        poll: p,
                        clubId: clubId,
                        canManage: canManage,
                        onChanged: () => ref.invalidate(_openPollsProvider(clubId)),
                      )),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSheet(context, ref),
              backgroundColor: const Color(0xFF7c5cd8),
              icon: const Icon(Icons.add),
              label: const Text('Nova votação'),
            )
          : null,
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreatePollSheet(
        clubId: clubId,
        onSaved: () => ref.invalidate(_openPollsProvider(clubId)),
      ),
    );
  }
}

// ── Cabeçalho de seção ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.headlineMedium.copyWith(
                color: cs.onSurface, fontSize: 13)),
      ],
    );
  }
}

// ── Card de votação ───────────────────────────────────────────────────────────

class _PollCard extends ConsumerStatefulWidget {
  final ClubOpenPoll poll;
  final String clubId;
  final bool canManage;
  final VoidCallback onChanged;

  const _PollCard({
    super.key,
    required this.poll,
    required this.clubId,
    required this.canManage,
    required this.onChanged,
  });

  @override
  ConsumerState<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<_PollCard> {
  List<OpenPollOptionResult>? _results;
  bool _loadingVote = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final results = await ref
        .read(bookClubRepositoryProvider)
        .fetchOpenPollResults(widget.poll.id);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _vote(List<String> optionIds) async {
    setState(() => _loadingVote = true);
    try {
      await ref
          .read(bookClubRepositoryProvider)
          .voteOnOpenPoll(widget.poll.id, optionIds);
      await _loadResults();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingVote = false);
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar votação?'),
        content: const Text('A votação será fechada e ninguém mais poderá votar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(bookClubRepositoryProvider).closeOpenPoll(widget.poll.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final poll = widget.poll;
    final results = _results;
    final isOpen = poll.isOpen;
    final fmtDate = DateFormat('dd/MM/yyyy');

    // Contagem total de votos (para % de participação)
    final totalVoters = results?.fold<int>(0, (acc, r) => acc + r.voteCount) ?? 0;
    final hasVoted = results?.any((r) => r.votedByMe) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // cabeçalho (sempre visível)
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.question,
                          style: AppTextStyles.titleMedium
                              .copyWith(color: cs.onSurface, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppColors.forestGreen.withValues(alpha: 0.12)
                                    : AppColors.textMuted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOpen ? 'Aberta' : 'Encerrada',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isOpen
                                      ? AppColors.forestGreen
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (poll.closesAt != null)
                              Text(
                                'até ${fmtDate.format(poll.closesAt!.toLocal())}',
                                style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
                              ),
                            const SizedBox(width: 8),
                            if (results != null)
                              Text(
                                '$totalVoters voto${totalVoters != 1 ? 's' : ''}',
                                style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (isOpen && widget.canManage)
                        IconButton(
                          icon: const Icon(Icons.lock_outline, size: 18,
                              color: AppColors.textMuted),
                          tooltip: 'Encerrar votação',
                          onPressed: _close,
                        ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // opções (expandíveis)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: results == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        if (poll.multiSelect && isOpen && !hasVoted)
                          _MultiSelectVoter(
                            results: results,
                            loading: _loadingVote,
                            onVote: (ids) => _vote(ids),
                          )
                        else
                          ...results.map(
                            (r) => _OptionBar(
                              result: r,
                              isOpen: isOpen,
                              loading: _loadingVote,
                              onTap: (isOpen && !_loadingVote)
                                  ? () => _vote([r.optionId])
                                  : null,
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Barra de opção com % ──────────────────────────────────────────────────────

class _OptionBar extends StatelessWidget {
  final OpenPollOptionResult result;
  final bool isOpen;
  final bool loading;
  final VoidCallback? onTap;

  const _OptionBar({
    required this.result,
    required this.isOpen,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final voted = result.votedByMe;
    final purple = const Color(0xFF7c5cd8);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: voted ? purple.withValues(alpha: 0.10) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: voted ? purple.withValues(alpha: 0.4) : cs.outlineVariant,
          ),
        ),
        child: Stack(
          children: [
            // barra de progresso
            FractionallySizedBox(
              widthFactor: result.pct / 100,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: (voted ? purple : cs.primary).withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  if (voted)
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF7c5cd8)),
                  if (voted) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.optionLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: voted ? FontWeight.w600 : FontWeight.normal,
                        color: voted ? purple : cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${result.voteCount} (${result.pct.toStringAsFixed(0)}%)',
                    style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seletor multi-opção ───────────────────────────────────────────────────────

class _MultiSelectVoter extends StatefulWidget {
  final List<OpenPollOptionResult> results;
  final bool loading;
  final void Function(List<String>) onVote;

  const _MultiSelectVoter({
    required this.results,
    required this.loading,
    required this.onVote,
  });

  @override
  State<_MultiSelectVoter> createState() => _MultiSelectVoterState();
}

class _MultiSelectVoterState extends State<_MultiSelectVoter> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF7c5cd8);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecione uma ou mais opções:',
            style: AppTextStyles.labelMedium.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        ...widget.results.map((r) {
          final sel = _selected.contains(r.optionId);
          return GestureDetector(
            onTap: () => setState(() {
              if (sel) {
                _selected.remove(r.optionId);
              } else {
                _selected.add(r.optionId);
              }
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? purple.withValues(alpha: 0.10) : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel ? purple.withValues(alpha: 0.4) : cs.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 16,
                    color: sel ? purple : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.optionLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? purple : cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${r.voteCount}',
                    style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_selected.isEmpty || widget.loading)
                ? null
                : () => widget.onVote(_selected.toList()),
            style: FilledButton.styleFrom(backgroundColor: purple),
            child: widget.loading
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirmar votos'),
          ),
        ),
      ],
    );
  }
}

// ── Sheet: criar votação ──────────────────────────────────────────────────────

class _CreatePollSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;
  const _CreatePollSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<_CreatePollSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiSelect = false;
  bool _loading = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha a pergunta e ao menos 2 opções.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final pollOptions = options
          .asMap()
          .entries
          .map((e) => OpenPollOption(id: 'opt_${e.key + 1}', label: e.value))
          .toList();
      await ref.read(bookClubRepositoryProvider).createOpenPoll(
            clubId: widget.clubId,
            question: question,
            options: pollOptions,
            multiSelect: _multiSelect,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final purple = const Color(0xFF7c5cd8);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nova Votação',
                style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: _questionCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Pergunta *',
                hintText: 'Ex: Qual horário preferem para o encontro?',
              ),
            ),
            const SizedBox(height: 12),
            Text('Opções (mín. 2)', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            ..._optionCtrls.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: e.value,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(labelText: 'Opção ${e.key + 1}'),
                          ),
                        ),
                        if (_optionCtrls.length > 2)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.error),
                            onPressed: () => setState(() {
                              e.value.dispose();
                              _optionCtrls.removeAt(e.key);
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
            if (_optionCtrls.length < 8)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _optionCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar opção'),
                style: TextButton.styleFrom(foregroundColor: purple),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir múltipla escolha',
                  style: TextStyle(fontSize: 13)),
              subtitle: const Text('Membros podem votar em mais de uma opção',
                  style: TextStyle(fontSize: 11)),
              value: _multiSelect,
              activeThumbColor: purple,
              activeTrackColor: purple.withValues(alpha: 0.5),
              onChanged: (v) => setState(() => _multiSelect = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: purple),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Criar votação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
