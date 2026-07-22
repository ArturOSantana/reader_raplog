import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';

final _homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchDailyStats(),
    sessionRepo.fetchStreak(),
    bookRepo.fetchAll(status: BookStatus.reading),
    goalRepo.fetchAll(),
  ]);

  return {
    'daily': results[0] as Map<String, dynamic>,
    'streak': results[1] as int,
    'reading': results[2] as List<Book>,
    'goals': results[3] as List<Goal>,
  };
});

final homeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshTriggerProvider);
    final data = ref.watch(_homeDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerButton(),
        title: const Text('Readlog'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (d) {
          final daily = d['daily'] as Map<String, dynamic>;
          final streak = d['streak'] as int;
          final reading = d['reading'] as List<Book>;
          final goals = d['goals'] as List<Goal>;

          final todayMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;

          // Filtra apenas metas diárias para exibir na Home
          final dailyGoals = goals.where((g) =>
              g.type == GoalType.dailyMinutes ||
              g.type == GoalType.dailyPages).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_homeDataProvider);
              await ref.read(_homeDataProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StreakCard(streak: streak),
                const SizedBox(height: 16),
                _DailyStatsCard(
                  minutes: todayMinutes,
                  pages: todayPages,
                ),
                if (dailyGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DailyGoalRow(
                    goals: dailyGoals,
                    todayMinutes: todayMinutes,
                    todayPages: todayPages,
                  ),
                ],
                const SizedBox(height: 24),
                Text('Lendo agora', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                if (reading.isEmpty)
                  _EmptyReadingCard()
                else
                  ...reading.map((b) => _CurrentBookCard(book: b)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (reading.isNotEmpty) {
                      context.go('/session?bookId=${reading.first.id}');
                    } else {
                      context.go('/session');
                    }
                  },
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Iniciar leitura'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sequencia',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streak ${streak == 1 ? 'dia' : 'dias'}',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_fire_department,
              color: AppColors.warmGoldLight, size: 40),
        ],
      ),
    );
  }
}

class _DailyStatsCard extends StatelessWidget {
  final int minutes;
  final int pages;

  const _DailyStatsCard({required this.minutes, required this.pages});

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'Hoje', value: timeLabel, sub: 'lidos'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(label: 'Paginas', value: '$pages', sub: 'hoje'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _StatTile(
      {required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.displayMedium),
          Text(sub, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _CurrentBookCard extends ConsumerWidget {
  final Book book;

  const _CurrentBookCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/library/book/${book.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.menu_book_outlined,
                  color: AppColors.forestGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (book.author != null)
                    Text(book.author!,
                        style: AppTextStyles.bodyMedium, maxLines: 1),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyReadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text('Nenhum livro em leitura',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/library/add'),
            child: const Text('Adicionar livro'),
          ),
        ],
      ),
    );
  }
}

/// Linha compacta de progresso das metas diárias — exibida na Home.
class _DailyGoalRow extends StatelessWidget {
  final List<Goal> goals;
  final int todayMinutes;
  final int todayPages;

  const _DailyGoalRow({
    required this.goals,
    required this.todayMinutes,
    required this.todayPages,
  });

  int _current(Goal goal) {
    if (goal.type == GoalType.dailyMinutes) return todayMinutes;
    return todayPages;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: goals.map((goal) {
        final current = _current(goal);
        final target = goal.targetValue;
        final progress = (current / target).clamp(0.0, 1.0);
        final done = current >= target;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? AppColors.forestGreen : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meta: ${goal.type.label}',
                    style: AppTextStyles.labelMedium,
                  ),
                  Text(
                    done
                        ? '✓ Meta atingida!'
                        : '$current / $target ${goal.type.unit}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: done
                          ? AppColors.forestGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done
                        ? AppColors.forestGreen
                        : AppColors.forestGreen.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
