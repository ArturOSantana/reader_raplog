import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/providers/providers.dart';

final _achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.watch(achievementRepositoryProvider).fetchAll();
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(_achievementsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LumenTexturedBackground(
      child: Scaffold(
        backgroundColor: isDark ? LumenColors.canvas : LumenColors.surface,
        body: achievements.when(
          loading: () => const Center(
            child: LumenGrainLoader(),
          ),
          error: (e, _) => Center(
            child: Text(
              'Erro ao carregar conquistas',
              style: LumenType.mono(
                size: 13,
                color: isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted,
              ),
            ),
          ),
          data: (list) {
            final unlocked = list.where((a) => a.isUnlocked).toList()
              ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
            final locked = list.where((a) => !a.isUnlocked).toList();
            final progress = list.isEmpty ? 0.0 : unlocked.length / list.length;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _AchievementsHeader(
                  unlocked: unlocked.length,
                  total: list.length,
                  progress: progress,
                ),
                if (unlocked.isNotEmpty) ...[
                  _SectionLabel(label: 'Conquistadas', isDark: isDark),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AchievementsGrid(
                        items: unlocked, unlocked: true, isDark: isDark),
                  ),
                  const SizedBox(height: 8),
                ],
                if (locked.isNotEmpty) ...[
                  _SectionLabel(label: 'Bloqueadas', isDark: isDark, muted: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AchievementsGrid(
                        items: locked, unlocked: false, isDark: isDark),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Header com progresso ────────────────────────────────────────────────────

class _AchievementsHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  final double progress;

  const _AchievementsHeader({
    required this.unlocked,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? LumenColors.canvas : LumenColors.surface;
    final fg = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final muted = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONQUISTAS',
            style: LumenType.kicker(size: 10, color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Carimbos',
            style: LumenType.bookTitle(size: 28, color: fg),
          ),
          const SizedBox(height: 20),
          // Linha de progresso com contagem
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor:
                        isDark ? LumenColors.hairlineDark : LumenColors.surfaceSubtle,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(LumenColors.read),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$unlocked / $total',
                style: LumenType.mono(size: 11, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Label de seção ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool muted;

  const _SectionLabel({
    required this.label,
    required this.isDark,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? (isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted)
        : (isDark ? LumenColors.inkInverse : LumenColors.ink);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        label,
        style: LumenType.bookTitle(size: 15, color: color),
      ),
    );
  }
}

// ── Grid de conquistas ──────────────────────────────────────────────────────

class _AchievementsGrid extends StatelessWidget {
  final List<Achievement> items;
  final bool unlocked;
  final bool isDark;

  const _AchievementsGrid({
    required this.items,
    required this.unlocked,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) =>
          _AchievementCard(achievement: items[i], unlocked: unlocked),
    );
  }
}

// ── Card individual ─────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _AchievementCard({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = unlocked
        ? (isDark
            ? LumenColors.canvasVariant
            : LumenColors.surfaceVariant)
        : (isDark
            ? LumenColors.canvas
            : LumenColors.surface);

    final borderColor = unlocked
        ? (isDark ? LumenColors.dividerDark : LumenColors.divider)
        : (isDark ? LumenColors.hairlineDark : LumenColors.hairline);

    final titleColor = unlocked
        ? (isDark ? LumenColors.inkInverse : LumenColors.ink)
        : (isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted);

    final descColor =
        isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;

    final iconBg = unlocked
        ? LumenColors.read.withValues(alpha: 0.12)
        : (isDark
            ? LumenColors.hairlineDark
            : LumenColors.surfaceSubtle);

    final iconColor = unlocked
        ? LumenColors.read
        : (isDark ? LumenColors.inkSecondaryInverse : LumenColors.inkSecondary);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: LumenRadius.cardAll,
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
                child: Center(
                  child: LumenIcon(
                    unlocked ? 'check' : 'bookmark',
                    size: 15,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nome
              Expanded(
                child: Text(
                  achievement.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LumenType.mono(
                    size: 10,
                    weight: FontWeight.w500,
                    color: titleColor,
                  ).copyWith(letterSpacing: 0.2, height: 1.35),
                ),
              ),
            ],
          ),
          // Descrição
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              height: 1.4,
              color: descColor,
            ),
          ),
          // Data de desbloqueio ou XP
          if (unlocked && achievement.unlockedAt != null)
            Text(
              DateFormat('dd/MM/yy').format(achievement.unlockedAt!),
              style: LumenType.mono(
                size: 9,
                color: LumenColors.read,
              ),
            )
          else
            Text(
              '+${achievement.xpReward} XP',
              style: LumenType.mono(
                size: 9,
                color: isDark
                    ? LumenColors.inkSecondaryInverse
                    : LumenColors.inkSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
