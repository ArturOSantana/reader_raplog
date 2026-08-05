import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_bets_and_polls.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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
  final String? coverUrl;

  const ClubOpenPollsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.canManage,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(_openPollsProvider(clubId));

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votações', style: ReadLogType.bookTitle(size: 16)),
            Text(clubName,
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 12)),
          ],
        ),
        actions: [
          if (canManage)
            TextButton(
              onPressed: () => _showCreateSheet(context, ref),
              child: Text('Nova',
                  style: ReadLogType.kicker(
                      color: ReadLogColors.ink, size: 12)),
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
                      Text('Nenhuma votação.',
                          style: ReadLogType.bookTitle(size: 18)),
                      const SizedBox(height: 6),
                      Text(
                        canManage
                            ? 'Crie uma votação para ouvir o clube.'
                            : 'Aguarde uma votação dos admins.',
                        style: ReadLogType.authorName(
                            color: ReadLogColors.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final open = polls.where((p) => p.isOpen).toList();
            final closed = polls.where((p) => !p.isOpen).toList();

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (open.isNotEmpty) ...[
                  _SectionLabel('Abertas · ${open.length}'),
                  const SizedBox(height: 8),
                  ...open.map((p) => _PollRow(
                        key: ValueKey(p.id),
                        poll: p,
                        clubId: clubId,
                        canManage: canManage,
                        onChanged: () =>
                            ref.invalidate(_openPollsProvider(clubId)),
                      )),
                  const SizedBox(height: 24),
                ],
                if (closed.isNotEmpty) ...[
                  _SectionLabel('Encerradas · ${closed.length}'),
                  const SizedBox(height: 8),
                  ...closed.map((p) => _PollRow(
                        key: ValueKey(p.id),
                        poll: p,
                        clubId: clubId,
                        canManage: canManage,
                        onChanged: () =>
                            ref.invalidate(_openPollsProvider(clubId)),
                      )),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePollSheet(
        clubId: clubId,
        onSaved: () => ref.invalidate(_openPollsProvider(clubId)),
      ),
    );
  }
}

// ── Label de seção ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: ReadLogType.kicker(color: ReadLogColors.inkMuted, size: 11),
      ),
    );
  }
}

// ── Linha de votação — expansível ─────────────────────────────────────────────

class _PollRow extends ConsumerStatefulWidget {
  final ClubOpenPoll poll;
  final String clubId;
  final bool canManage;
  final VoidCallback onChanged;

  const _PollRow({
    super.key,
    required this.poll,
    required this.clubId,
    required this.canManage,
    required this.onChanged,
  });

  @override
  ConsumerState<_PollRow> createState() => _PollRowState();
}

class _PollRowState extends ConsumerState<_PollRow> {
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
        content: const Text(
            'A votação será fechada e ninguém mais poderá votar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: ReadLogColors.danger),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(bookClubRepositoryProvider)
          .closeOpenPoll(widget.poll.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final results = _results;
    final isOpen = poll.isOpen;
    final fmtDate = DateFormat('dd/MM/yyyy');
    final totalVoters =
        results?.fold<int>(0, (acc, r) => acc + r.voteCount) ?? 0;
    final hasVoted = results?.any((r) => r.votedByMe) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha clicável — cabeçalho
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poll.question,
                          style: ReadLogType.authorName(size: 15)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          isOpen ? 'aberta' : 'encerrada',
                          if (poll.closesAt != null)
                            'até ${fmtDate.format(poll.closesAt!.toLocal())}',
                          if (results != null)
                            '$totalVoters voto${totalVoters != 1 ? 's' : ''}',
                        ].join(' · '),
                        style: ReadLogType.mono(
                            size: 11, color: ReadLogColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (isOpen && widget.canManage)
                  GestureDetector(
                    onTap: _close,
                    child: Text('encerrar',
                        style: ReadLogType.kicker(
                            color: ReadLogColors.inkGhost, size: 10)),
                  ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: ReadLogColors.inkGhost,
                ),
              ],
            ),
          ),
        ),
        // Opções (expandíveis)
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: results == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (poll.multiSelect && isOpen && !hasVoted)
                        _MultiSelectVoter(
                          results: results,
                          loading: _loadingVote,
                          onVote: (ids) => _vote(ids),
                        )
                      else
                        ...results.map(
                          (r) => _OptionLine(
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
        const Divider(height: 1),
      ],
    );
  }
}

// ── Linha de opção com barra fina monocromática ───────────────────────────────

class _OptionLine extends StatelessWidget {
  final OpenPollOptionResult result;
  final bool isOpen;
  final bool loading;
  final VoidCallback? onTap;

  const _OptionLine({
    required this.result,
    required this.isOpen,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final voted = result.votedByMe;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.optionLabel,
                    style: ReadLogType.authorName(
                      size: 13,
                      color: voted
                          ? ReadLogColors.ink
                          : ReadLogColors.inkMuted,
                    ),
                  ),
                ),
                Text(
                  '${result.voteCount} (${result.pct.toStringAsFixed(0)}%)',
                  style: ReadLogType.mono(
                      size: 11, color: ReadLogColors.inkGhost),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Barra fina monocromática — sem cor roxa/verde
            LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                      height: 2,
                      width: constraints.maxWidth,
                      color: ReadLogColors.hairline),
                  Container(
                    height: 2,
                    width: constraints.maxWidth * (result.pct / 100).clamp(0, 1),
                    color: voted
                        ? ReadLogColors.ink
                        : ReadLogColors.inkGhost,
                  ),
                ],
              );
            }),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecione uma ou mais opções:',
            style: ReadLogType.kicker(
                color: ReadLogColors.inkMuted, size: 11)),
        const SizedBox(height: 10),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Text(
                    sel ? '▪' : '▫',
                    style: ReadLogType.mono(
                        size: 13,
                        color: sel
                            ? ReadLogColors.ink
                            : ReadLogColors.inkGhost),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.optionLabel,
                      style: ReadLogType.authorName(
                        size: 13,
                        color: sel
                            ? ReadLogColors.ink
                            : ReadLogColors.inkMuted,
                      ),
                    ),
                  ),
                  Text(
                    '${r.voteCount}',
                    style: ReadLogType.mono(
                        size: 11, color: ReadLogColors.inkGhost),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_selected.isEmpty || widget.loading)
                ? null
                : () => widget.onVote(_selected.toList()),
            child: widget.loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
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
        const SnackBar(
            content: Text('Preencha a pergunta e ao menos 2 opções.')),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova votação', style: ReadLogType.bookTitle(size: 20)),
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
            Text('Opções (mín. 2)',
                style: ReadLogType.kicker(
                    color: ReadLogColors.inkMuted, size: 11)),
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
                            decoration:
                                InputDecoration(labelText: 'Opção ${e.key + 1}'),
                          ),
                        ),
                        if (_optionCtrls.length > 2)
                          TextButton(
                            onPressed: () => setState(() {
                              e.value.dispose();
                              _optionCtrls.removeAt(e.key);
                            }),
                            style: TextButton.styleFrom(
                                foregroundColor: ReadLogColors.danger),
                            child: const Text('−'),
                          ),
                      ],
                    ),
                  ),
                ),
            if (_optionCtrls.length < 8)
              TextButton(
                onPressed: () =>
                    setState(() => _optionCtrls.add(TextEditingController())),
                child: Text('+ Adicionar opção',
                    style: ReadLogType.authorName(size: 13)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Múltipla escolha',
                          style: ReadLogType.authorName(size: 13)),
                      Text('Membros podem votar em mais de uma opção',
                          style: ReadLogType.mono(
                              size: 11, color: ReadLogColors.inkMuted)),
                    ],
                  ),
                ),
                Switch(
                  value: _multiSelect,
                  onChanged: (v) => setState(() => _multiSelect = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Criar votação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
