import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_bets_and_polls.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _betsProvider =
    FutureProvider.family<List<ClubBet>, String>((ref, clubId) async {
  final repo = ref.watch(bookClubRepositoryProvider);
  try {
    await repo.refreshExpiredBets(clubId);
  } catch (_) {}
  return repo.listBets(clubId);
});

final _betsLeaderboardProvider =
    FutureProvider.family<List<BetLeaderboardEntry>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchBetsLeaderboard(clubId, minBets: 1);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela dedicada de Apostas Amistosas — lista completa + leaderboard de acertos.
class ClubBetsScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final bool canManage;

  const ClubBetsScreen({
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apostas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova aposta',
              onPressed: () => _showCreateSheet(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_betsProvider(clubId));
          ref.invalidate(_betsLeaderboardProvider(clubId));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ── Leaderboard ───────────────────────────────────────────────────
            _LeaderboardSection(clubId: clubId),
            const SizedBox(height: 20),
            // ── Lista de apostas ──────────────────────────────────────────────
            _BetsListSection(
              clubId: clubId,
              canManage: canManage,
              onRefresh: () {
                ref.invalidate(_betsProvider(clubId));
                ref.invalidate(_betsLeaderboardProvider(clubId));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSheet(context, ref),
              backgroundColor: AppColors.forestGreen,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Nova aposta'),
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
      builder: (_) => _CreateBetSheet(
        clubId: clubId,
        onSaved: () {
          ref.invalidate(_betsProvider(clubId));
          ref.invalidate(_betsLeaderboardProvider(clubId));
        },
      ),
    );
  }
}

// ── Leaderboard de acertos ────────────────────────────────────────────────────

class _LeaderboardSection extends ConsumerWidget {
  final String clubId;
  const _LeaderboardSection({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final leaderAsync = ref.watch(_betsLeaderboardProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.warmGold),
            const SizedBox(width: 8),
            Text(
              'Apostador mais certeiro',
              style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 10),
        leaderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            if (entries.isEmpty) {
              return _InfoBox(
                icon: Icons.emoji_events_outlined,
                message: 'Nenhuma aposta resolvida ainda.',
                sub: 'O leaderboard aparece após resolver ao menos 1 aposta.',
              );
            }
            return Column(
              children: entries
                  .take(5)
                  .map((e) => _LeaderboardRow(entry: e))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final BetLeaderboardEntry entry;
  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isOnPodium
            ? AppColors.warmGold.withValues(alpha: 0.06)
            : surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.isOnPodium
              ? AppColors.warmGold.withValues(alpha: 0.3)
              : border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              entry.podiumLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          if (entry.avatarUrl != null)
            CircleAvatar(backgroundImage: NetworkImage(entry.avatarUrl!), radius: 16)
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.forestGreen.withValues(alpha: 0.15),
              child: Text(
                (entry.userName ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName ?? 'Membro',
                  style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface, fontSize: 13),
                ),
                Text(
                  '${entry.totalWins}V · ${entry.totalLosses}D · ${entry.totalBets} apostas',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _winColor(entry.winRatePct).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry.winRatePct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _winColor(entry.winRatePct),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _winColor(double pct) {
    if (pct >= 70) return AppColors.forestGreen;
    if (pct >= 50) return AppColors.warmGold;
    return AppColors.textMuted;
  }
}

// ── Lista de apostas ──────────────────────────────────────────────────────────

class _BetsListSection extends ConsumerWidget {
  final String clubId;
  final bool canManage;
  final VoidCallback onRefresh;

  const _BetsListSection({
    required this.clubId,
    required this.canManage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final betsAsync = ref.watch(_betsProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.casino_outlined, size: 18, color: AppColors.forestGreen),
            const SizedBox(width: 8),
            Text(
              'Todas as apostas',
              style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 10),
        betsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e', style: TextStyle(color: cs.error)),
          data: (bets) {
            if (bets.isEmpty) {
              return _InfoBox(
                icon: Icons.casino_outlined,
                message: 'Nenhuma aposta ainda.',
                sub: 'Desafie um colega — quem termina o livro primeiro?',
              );
            }
            return Column(
              children: bets
                  .map((b) => _BetDetailCard(
                        key: ValueKey(b.id),
                        bet: b,
                        clubId: clubId,
                        canManage: canManage,
                        onChanged: onRefresh,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _BetDetailCard extends ConsumerStatefulWidget {
  final ClubBet bet;
  final String clubId;
  final bool canManage;
  final VoidCallback onChanged;

  const _BetDetailCard({
    super.key,
    required this.bet,
    required this.clubId,
    required this.canManage,
    required this.onChanged,
  });

  @override
  ConsumerState<_BetDetailCard> createState() => _BetDetailCardState();
}

class _BetDetailCardState extends ConsumerState<_BetDetailCard> {
  List<ClubBetParticipant> _participants = [];
  bool _loading = true;
  bool _busy = false;

  ClubBet get bet => widget.bet;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final list = await ref.read(bookClubRepositoryProvider).listBetParticipants(bet.id);
      if (mounted) setState(() { _participants = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _myUserId => ref.read(currentUserProvider)?.id;

  String? get _mySide {
    final uid = _myUserId;
    if (uid == null) return null;
    try {
      return _participants.firstWhere((p) => p.userId == uid).side;
    } catch (_) {
      return null;
    }
  }

  bool get _iAmCreatorOrManager =>
      _myUserId == bet.createdBy || widget.canManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final fmt = DateFormat('dd/MM/yyyy');

    final statusColor = switch (bet.status) {
      BetStatus.open     => AppColors.forestGreen,
      BetStatus.closed   => AppColors.textMuted,
      BetStatus.resolved => AppColors.warmGold,
    };
    final statusLabel = switch (bet.status) {
      BetStatus.open     => 'Aberta',
      BetStatus.closed   => 'Encerrada',
      BetStatus.resolved => 'Resolvida',
    };

    final sideA = _participants.where((p) => p.side == 'a').toList();
    final sideB = _participants.where((p) => p.side == 'b').toList();
    final mySide = _mySide;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // cabeçalho
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.redeem_outlined, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bet.description,
                      style: AppTextStyles.titleMedium
                          .copyWith(color: cs.onSurface, fontSize: 14),
                    ),
                    if (bet.resolutionCriteria != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        bet.resolutionCriteria!,
                        style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  if (bet.resolvesAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'até ${fmt.format(bet.resolvesAt!.toLocal())}',
                      style: AppTextStyles.labelMedium.copyWith(fontSize: 9),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // lados
          if (_loading)
            const SizedBox(height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            _SidesRow(
              sideALabel: '${bet.sideALabel} (${sideA.length})',
              sideBLabel: '${bet.sideBLabel} (${sideB.length})',
              mySide: mySide,
              sideAParticipants: sideA,
              sideBParticipants: sideB,
            ),

          // resultado
          if (bet.isResolved && bet.winnerLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 16, color: AppColors.warmGold),
                  const SizedBox(width: 6),
                  Text(
                    'Vencedor: ${bet.winnerLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (bet.status == BetStatus.closed && bet.winnerLabel == null) ...[
            const SizedBox(height: 6),
            Text(
              'Aposta encerrada sem vencedor.',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
            ),
          ],

          // ações
          if (bet.isOpen) ...[
            const SizedBox(height: 10),
            if (mySide != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _leaveBet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Sair da aposta', style: TextStyle(fontSize: 12)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _joinBet(context, 'a'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forestGreen,
                        side: const BorderSide(color: AppColors.forestGreen),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(bet.sideALabel, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _joinBet(context, 'b'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(bet.sideBLabel, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            if (_iAmCreatorOrManager) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _resolve(context, 'a'),
                      icon: const Icon(Icons.check_circle_outline, size: 14,
                          color: AppColors.forestGreen),
                      label: Text('${bet.sideALabel} venceu',
                          style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forestGreen,
                        side: BorderSide(
                            color: AppColors.forestGreen.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _resolve(context, 'b'),
                      icon: const Icon(Icons.check_circle_outline, size: 14,
                          color: AppColors.error),
                      label: Text('${bet.sideBLabel} venceu',
                          style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side:
                            BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _cancel(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(
                          color: AppColors.textMuted.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    ),
                    child: const Icon(Icons.cancel_outlined, size: 16),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _joinBet(BuildContext context, String side) async {
    setState(() => _busy = true);
    try {
      await ref.read(bookClubRepositoryProvider).joinBet(bet.id, side);
      await _loadParticipants();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Você apostou em "${side == 'a' ? bet.sideALabel : bet.sideBLabel}"!')));
      }
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveBet(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da aposta?'),
        content: const Text('Sua aposta será removida. Você poderá apostar novamente enquanto aberta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(bookClubRepositoryProvider).leaveBet(bet.id);
      await _loadParticipants();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Você saiu da aposta.')));
      }
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(BuildContext context, String side) async {
    final label = side == 'a' ? bet.sideALabel : bet.sideBLabel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Definir vencedor'),
        content: Text('Confirma que "$label" venceu esta aposta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.forestGreen),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(bookClubRepositoryProvider).resolveBet(bet.id, side);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Vencedor: $label')));
      }
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar aposta?'),
        content: const Text('A aposta será encerrada sem definir vencedor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancelar aposta'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(bookClubRepositoryProvider).cancelBet(bet.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Aposta cancelada.')));
      }
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Widget auxiliar: lados da aposta ─────────────────────────────────────────

class _SidesRow extends StatelessWidget {
  final String sideALabel;
  final String sideBLabel;
  final String? mySide;
  final List<ClubBetParticipant> sideAParticipants;
  final List<ClubBetParticipant> sideBParticipants;

  const _SidesRow({
    required this.sideALabel,
    required this.sideBLabel,
    required this.mySide,
    required this.sideAParticipants,
    required this.sideBParticipants,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SideChip(
          label: sideALabel,
          color: mySide == 'a'
              ? AppColors.forestGreen
              : AppColors.forestGreen.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Text('vs', style: AppTextStyles.labelMedium),
        const SizedBox(width: 6),
        _SideChip(
          label: sideBLabel,
          color: mySide == 'b'
              ? AppColors.error
              : AppColors.error.withValues(alpha: 0.45),
        ),
        if (mySide != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Você apostou',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.forestGreen,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SideChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SideChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Sheet: criar aposta ───────────────────────────────────────────────────────

class _CreateBetSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;
  const _CreateBetSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_CreateBetSheet> createState() => _CreateBetSheetState();
}

class _CreateBetSheetState extends ConsumerState<_CreateBetSheet> {
  final _descCtrl = TextEditingController();
  final _sideACtrl = TextEditingController(text: 'Sim');
  final _sideBCtrl = TextEditingController(text: 'Não');
  BetStakeType _stakeType = BetStakeType.cafe;
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _sideACtrl.dispose();
    _sideBCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).createBet(
            clubId: widget.clubId,
            description: desc,
            stakeType: _stakeType,
            sideALabel: _sideACtrl.text.trim().isEmpty ? 'Sim' : _sideACtrl.text.trim(),
            sideBLabel: _sideBCtrl.text.trim().isEmpty ? 'Não' : _sideBCtrl.text.trim(),
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
            Text('Nova Aposta',
                style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                hintText: 'Ex: Quem vai terminar o livro primeiro?',
              ),
            ),
            const SizedBox(height: 12),
            Text('Prêmio', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: BetStakeType.values.map((t) {
                final sel = _stakeType == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: sel,
                  onSelected: (_) => setState(() => _stakeType = t),
                  selectedColor: AppColors.forestGreen.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sideACtrl,
                    decoration: const InputDecoration(labelText: 'Lado A'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sideBCtrl,
                    decoration: const InputDecoration(labelText: 'Lado B'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.forestGreen),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Criar aposta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget auxiliar: caixa de info vazia ─────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _InfoBox({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 8),
          Text(message,
              style: AppTextStyles.titleMedium
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(sub, style: AppTextStyles.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
