import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengeDetailScreen extends ConsumerWidget {
  final String clubId;
  final String challengeId;
  final String challengeTitle;

  const ChallengeDetailScreen({
    super.key,
    required this.clubId,
    required this.challengeId,
    required this.challengeTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              '💪 Desafio',
              style:
                  AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_challengeProgressProvider(challengeId));
        },
        child: progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (entries) => _ChallengeBody(
            entries: entries,
            clubId: clubId,
            challengeId: challengeId,
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

  const _ChallengeBody({
    required this.entries,
    required this.clubId,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId =
        ref.read(supabaseClientProvider).auth.currentUser?.id ?? '';

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯', style: TextStyle(fontSize: 40)),
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
            )),
        const SizedBox(height: 24),
      ],
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
                entry.podiumEmoji(),
                style: const TextStyle(fontSize: 22),
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
                  'Meta concluída! 🎉',
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

  const _LeaderboardTile({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final pct = (entry.pctComplete / 100).clamp(0.0, 1.0);
    final fmt = NumberFormat.decimalPattern('pt_BR');

    return Container(
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
                  entry.podiumEmoji(),
                  style: TextStyle(
                    fontSize: entry.rank <= 3 ? 20 : 13,
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
    );
  }
}
