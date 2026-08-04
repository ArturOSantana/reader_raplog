import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      backgroundColor: isDark ? LumenColors.canvas : ReadLogColors.paperAlt,
      body: achievements.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.brass),
        ),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          final unlocked = list.where((a) => a.isUnlocked).toList();
          final locked = list.where((a) => !a.isUnlocked).toList();

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ReadLogPageHeader(
                kicker: 'CONQUISTAS',
                title: 'Carimbos',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Resumo: "X de Y carimbadas"
              Text(
                '${unlocked.length} de ${list.length} carimbadas',
                style: ReadLogType.mono(
                    size: 11,
                    color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkMutedInverse : LumenColors.inkMuted),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: list.isEmpty
                      ? 0
                      : unlocked.length / list.length,
                  minHeight: 5,
                  backgroundColor: ReadLogColors.paperDeep,
                  color: ReadLogColors.stamp,
                ),
              ),
              const SizedBox(height: 28),

              // Grid de conquistas desbloqueadas
              if (unlocked.isNotEmpty) ...[
                Text(
                  'Conquistadas',
                  style: ReadLogType.display(
                      size: 17, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                ),
                const SizedBox(height: 14),
                _AchievementsGrid(items: unlocked, unlocked: true),
                const SizedBox(height: 24),
              ],

              // Grid de conquistas bloqueadas
              if (locked.isNotEmpty) ...[
                Text(
                  'Bloqueadas',
                  style: ReadLogType.display(
                      size: 17,
                      color:
                          LumenColors.inkMuted),
                ),
                const SizedBox(height: 14),
                _AchievementsGrid(items: locked, unlocked: false),
              ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  final List<Achievement> items;
  final bool unlocked;

  const _AchievementsGrid({required this.items, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) =>
          _AchievementSlot(achievement: items[i], unlocked: unlocked),
    );
  }
}

class _AchievementSlot extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _AchievementSlot(
      {required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? LumenColors.inkInverse : ReadLogColors.charcoal;
    final lockedColor = isDark ? LumenColors.hairlineDark : ReadLogColors.charcoal.withValues(alpha: 0.25);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carimbo de conquista — desbloqueado em stamp, bloqueado em transparente
        ReadLogStamp(
          value: '+${achievement.xpReward}',
          label: 'xp',
          color: unlocked
              ? ReadLogColors.stamp
              : lockedColor,
          size: 64,
          rotationDeg: unlocked ? -6 : 0,
        ),
        const SizedBox(height: 6),
        Text(
          achievement.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ReadLogType.mono(
            size: 9,
            color: unlocked
                ? textColor
                : LumenColors.inkSecondary,
          ).copyWith(letterSpacing: 0.3),
        ),
      ],
    );
  }
}
