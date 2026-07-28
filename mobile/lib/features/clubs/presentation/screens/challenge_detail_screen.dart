import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _challengeProgressProvider =
    FutureProvider.family<List<ChallengeProgressEntry>, String>(
        (ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchChallengeProgress(challengeId);
});

final _restDaysLeftProvider =
    FutureProvider.family<int, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchRestDaysLeft(challengeId);
});

final _nudgeProvider =
    FutureProvider.family<double?, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchWeeklyNudge(challengeId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengeDetailScreen extends ConsumerWidget {
  final String clubId;
  final String challengeId;
  final String challengeTitle;
  /// Objeto completo do desafio — necessário para heatmap e tela de resultado.
  final ClubChallenge? challenge;

  const ChallengeDetailScreen({
    super.key,
    required this.clubId,
    required this.challengeId,
    required this.challengeTitle,
    this.challenge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Invalida o progresso do desafio ao finalizar qualquer sessão de leitura.
    ref.listen(clubSessionRefreshProvider, (_, __) {
      ref.invalidate(_challengeProgressProvider(challengeId));
      ref.invalidate(_nudgeProvider(challengeId));
    });

    final progressAsync = ref.watch(_challengeProgressProvider(challengeId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challengeTitle,
              style: AppTextStyles.titleMedium
                  .copyWith(color: cs.onSurface, fontSize: 15),
            ),
            Text(
              'Desafio',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (challenge != null) ...[
            // F-02/F-03 Heatmap
            IconButton(
              icon: const Icon(Icons.grid_view_outlined),
              tooltip: 'Heatmap de leitura',
              onPressed: () => context.push(
                '/clubs/$clubId/challenges/$challengeId/heatmap',
                extra: {'challenge': challenge},
              ),
            ),
            // F-04 Resultado (só se encerrado)
            if (challenge!.status == ChallengeStatus.finished)
              IconButton(
                icon: const Icon(Icons.emoji_events_outlined),
                tooltip: 'Resultado',
                onPressed: () => context.push(
                  '/clubs/$clubId/challenges/$challengeId/result',
                  extra: {'challenge': challenge},
                ),
              ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_challengeProgressProvider(challengeId));
          ref.invalidate(_restDaysLeftProvider(challengeId));
          ref.invalidate(_nudgeProvider(challengeId));
        },
        child: progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (entries) => _ChallengeBody(
            entries: entries,
            clubId: clubId,
            challengeId: challengeId,
            challenge: challenge,
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ChallengeBody extends ConsumerWidget {
  final List<ChallengeProgressEntry> entries;
  final String clubId;
  final String challengeId;
  final ClubChallenge? challenge;

  const _ChallengeBody({
    required this.entries,
    required this.clubId,
    required this.challengeId,
    this.challenge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId =
        ref.read(supabaseClientProvider).auth.currentUser?.id ?? '';

    // F-01 Rest Days
    final restDaysAsync = ref.watch(_restDaysLeftProvider(challengeId));
    final restDaysLeft = restDaysAsync.valueOrNull ?? 0;

    // F-08 Nudge
    final nudgeAsync = ref.watch(_nudgeProvider(challengeId));
    final nudge = nudgeAsync.valueOrNull;

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'Nenhum progresso ainda.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Comece a ler para aparecer no ranking!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Encontra meu entry
    final myEntry = entries.where((e) => e.userId == currentUserId).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // F-08 Nudge de média
        if (nudge != null) ...[
          _NudgeBanner(diffPct: nudge),
          const SizedBox(height: 16),
        ],

        // F-01 Rest Days (só mostra se o desafio está ativo e tem saldo)
        if (challenge != null && challenge!.isOngoing) ...[
          _RestDaysCard(
            challengeId: challengeId,
            daysLeft: restDaysLeft,
            ref: ref,
          ),
          const SizedBox(height: 20),
        ],

        // ── Meu progresso ────────────────────────────────────────────────────
        if (myEntry != null) ...[
          _MyProgressCard(entry: myEntry),
          const SizedBox(height: 20),
        ],

        // ── Leaderboard ──────────────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.leaderboard_outlined,
                size: 18, color: AppColors.warmGold),
            const SizedBox(width: 8),
            Text(
              'Classificação',
              style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...entries.map((e) => _LeaderboardTile(
              entry: e,
              isMe: e.userId == currentUserId,
              clubId: clubId,
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── F-08 Nudge banner ─────────────────────────────────────────────────────────

class _NudgeBanner extends StatelessWidget {
  final double diffPct;

  const _NudgeBanner({required this.diffPct});

  @override
  Widget build(BuildContext context) {
    final isAhead = diffPct >= 0;
    final color = isAhead ? AppColors.forestGreen : AppColors.warmGold;
    final icon = isAhead ? Icons.trending_up : Icons.trending_down;
    final absPct = diffPct.abs().toStringAsFixed(0);
    final text = isAhead
        ? 'Você está $absPct% acima da média do clube esta semana!'
        : 'Você está $absPct% abaixo da média do clube esta semana.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── F-01 Rest Days card ───────────────────────────────────────────────────────

class _RestDaysCard extends StatefulWidget {
  final String challengeId;
  final int daysLeft;
  final WidgetRef ref;

  const _RestDaysCard({
    required this.challengeId,
    required this.daysLeft,
    required this.ref,
  });

  @override
  State<_RestDaysCard> createState() => _RestDaysCardState();
}

class _RestDaysCardState extends State<_RestDaysCard> {
  bool _loading = false;

  Future<void> _useRestDay() async {
    setState(() => _loading = true);
    final used = await widget.ref
        .read(bookClubRepositoryProvider)
        .useRestDay(widget.challengeId);
    if (mounted) {
      setState(() => _loading = false);
      if (used) {
        widget.ref.invalidate(_restDaysLeftProvider(widget.challengeId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dia de descanso registrado!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhum dia de descanso disponível.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(Icons.self_improvement_outlined,
              size: 22, color: AppColors.forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dias de descanso',
                  style: AppTextStyles.titleMedium
                      .copyWith(fontSize: 13),
                ),
                Text(
                  widget.daysLeft > 0
                      ? '${widget.daysLeft} disponível(is) — use um sem quebrar o streak'
                      : 'Nenhum disponível',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ),
          if (widget.daysLeft > 0)
            _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _useRestDay,
                    child: const Text('Usar hoje'),
                  ),
        ],
      ),
    );
  }
}

// ── Meu card de progresso ─────────────────────────────────────────────────────

class _MyProgressCard extends StatelessWidget {
  final ChallengeProgressEntry entry;

  const _MyProgressCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (entry.pctComplete / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.podiumLabel(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seu progresso',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: cs.onSurface),
                    ),
                    Text(
                      '${entry.currentValue} / ${entry.goalValue}',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.pctComplete.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: entry.isComplete
                      ? AppColors.forestGreen
                      : AppColors.warmGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.warmGold.withValues(alpha: 0.2),
              color: entry.isComplete
                  ? AppColors.forestGreen
                  : AppColors.warmGold,
            ),
          ),
          if (entry.isComplete) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 14, color: AppColors.forestGreen),
                const SizedBox(width: 4),
                Text(
                  'Meta concluída!',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tile do leaderboard ───────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final ChallengeProgressEntry entry;
  final bool isMe;
  final String clubId;

  const _LeaderboardTile({
    required this.entry,
    required this.isMe,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final pct = (entry.pctComplete / 100).clamp(0.0, 1.0);
    final fmt = NumberFormat.decimalPattern('pt_BR');

    return GestureDetector(
      onTap: () => context.push(
        '/clubs/$clubId/members/${entry.userId}/profile',
        extra: {
          'userName': entry.userName ?? 'Membro',
          'avatarUrl': entry.avatarUrl,
        },
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.warmGold.withValues(alpha: 0.06)
            : surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.warmGold.withValues(alpha: 0.35)
              : border,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  entry.podiumLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              MiniAvatar(
                url: entry.avatarUrl,
                name: entry.userName ?? '?',
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.userName ?? 'Anônimo',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: cs.onSurface,
                        fontSize: 13,
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor:
                            cs.outlineVariant.withValues(alpha: 0.5),
                        color: entry.isComplete
                            ? AppColors.forestGreen
                            : AppColors.warmGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(entry.currentValue),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: entry.isComplete
                          ? AppColors.forestGreen
                          : cs.onSurface,
                    ),
                  ),
                  Text(
                    '${entry.pctComplete.toStringAsFixed(0)}%',
                    style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
