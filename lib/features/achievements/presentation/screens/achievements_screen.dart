import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
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

    return Scaffold(
      appBar: AppBar(leading: const DrawerButton(), title: const Text('Conquistas')),
      body: achievements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          final unlocked = list.where((a) => a.isUnlocked).toList();
          final locked = list.where((a) => !a.isUnlocked).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${unlocked.length} de ${list.length} conquistadas',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              _LinearProgress(value: list.isEmpty ? 0 : unlocked.length / list.length),
              const SizedBox(height: 28),
              if (unlocked.isNotEmpty) ...[
                Text('Conquistadas', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                ...unlocked.map((a) => _AchievementTile(achievement: a)),
                const SizedBox(height: 24),
              ],
              if (locked.isNotEmpty) ...[
                Text('Bloqueadas', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                ...locked.map((a) => _AchievementTile(achievement: a)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LinearProgress extends StatelessWidget {
  final double value;

  const _LinearProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? AppColors.forestGreen.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.forestGreen.withValues(alpha: 0.1)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              unlocked ? Icons.military_tech : Icons.lock_outline,
              color: unlocked ? AppColors.forestGreen : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${achievement.xpReward} XP',
            style: AppTextStyles.labelMedium.copyWith(
              color: unlocked ? AppColors.warmGold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
