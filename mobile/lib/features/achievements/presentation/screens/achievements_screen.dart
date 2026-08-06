import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/providers/providers.dart';

final _achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.watch(achievementRepositoryProvider).fetchAll();
});

// Mapeia a chave da conquista para o nome do ícone SVG correspondente.
// Se a conquista tiver `icon` preenchido no banco, esse campo tem precedência.
String _iconForKey(String key) {
  switch (key) {
    case 'first_book':
      return 'achievement-primeiro-livro';
    case 'hours_100':
      return 'achievement-cem-horas';
    case 'first_club':
      return 'achievement-primeiro-clube';
    case 'first_collective_read':
      return 'achievement-leitura-coletiva';
    case 'books_100':
      return 'achievement-cem-livros';
    case 'streak_365':
      return 'achievement-365-dias';
    default:
      return 'achievement-primeiro-livro';
  }
}

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
          loading: () => const Center(child: LumenGrainLoader()),
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
                ...unlocked.map((a) => _AchievementRow(achievement: a, isUnlocked: true, isDark: isDark)),
                if (locked.isNotEmpty) ...[
                  _Divider(isDark: isDark),
                  ...locked.map((a) => _AchievementRow(achievement: a, isUnlocked: false, isDark: isDark)),
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

// ── Header ──────────────────────────────────────────────────────────────────

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
          Text('CONQUISTAS', style: LumenType.kicker(size: 10, color: muted)),
          const SizedBox(height: 4),
          Text('Carimbos', style: LumenType.bookTitle(size: 28, color: fg)),
          const SizedBox(height: 20),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(LumenColors.read),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$unlocked / $total', style: LumenType.mono(size: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Divisor entre desbloqueadas e bloqueadas ─────────────────────────────────

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? LumenColors.hairlineDark : LumenColors.hairline,
      ),
    );
  }
}

// ── Linha de conquista ───────────────────────────────────────────────────────

class _AchievementRow extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final bool isDark;

  const _AchievementRow({
    required this.achievement,
    required this.isUnlocked,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconName = achievement.icon ?? _iconForKey(achievement.key);
    final fg = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final muted = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Ícone SVG — opacidade 32% se bloqueada
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.32,
            child: LumenIcon(iconName, size: 32, color: fg),
          ),
          const SizedBox(width: 14),
          // Nome + data
          Expanded(
            child: Opacity(
              opacity: isUnlocked ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: fg, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked && achievement.unlockedAt != null
                        ? DateFormat("dd MMM yyyy", "pt_BR")
                            .format(achievement.unlockedAt!)
                        : 'ainda não desbloqueada',
                    style: LumenType.mono(size: 10, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
