import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/shell/main_shell.dart';
import '../../../../core/widgets/widget_manager.dart';
import '../../../../theme/readlog_theme.dart';
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

  final daily = results[0] as Map<String, dynamic>;
  final streak = results[1] as int;
  final reading = results[2] as List<Book>;
  final goals = results[3] as List<Goal>;

  // ── Atualiza todos os widgets nativos com os dados frescos ──────────────
  final currentBook = reading.isNotEmpty ? reading.first : null;
  final dailyGoalObj = goals.cast<Goal?>().firstWhere(
    (g) => g!.type == GoalType.dailyPages || g.type == GoalType.dailyMinutes,
    orElse: () => null,
  );
  final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;

  unawaited(WidgetManager.updateAll(
    bookTitle: currentBook?.title,
    bookAuthor: currentBook?.author,
    currentPage: currentBook?.currentPage ?? 0,
    totalPages: currentBook?.totalPages ?? 0,
    streak: streak,
    streakRecord: streak, // fallback: recorde = streak atual se não tiver separado
    dailyGoal: todayPages,
    dailyGoalTarget: dailyGoalObj?.targetValue,
  ));

  return {
    'daily': daily,
    'streak': streak,
    'reading': reading,
    'goals': goals,
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
      backgroundColor: ReadLogColors.ink,
      appBar: AppBar(
        backgroundColor: ReadLogColors.ink,
        foregroundColor: ReadLogColors.cream,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
          tooltip: 'Abrir menu',
        ),
        title: Text(
          'Readlog',
          style: ReadLogType.display(size: 19, color: ReadLogColors.brassLight),
        ),
      ),
      body: data.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.brass),
        ),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: ReadLogType.mono(color: ReadLogColors.cream)),
        ),
        data: (d) {
          final daily = d['daily'] as Map<String, dynamic>;
          final streak = d['streak'] as int;
          final reading = d['reading'] as List<Book>;
          final goals = d['goals'] as List<Goal>;

          final todayMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;

          final dailyGoals = goals
              .where((g) =>
                  g.type == GoalType.dailyMinutes ||
                  g.type == GoalType.dailyPages)
              .toList();

          return RefreshIndicator(
            color: ReadLogColors.brass,
            onRefresh: () async {
              ref.invalidate(_homeDataProvider);
              await ref.read(_homeDataProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Streak + stats em linha
                _StreakRow(
                  streak: streak,
                  minutes: todayMinutes,
                  pages: todayPages,
                ),
                if (dailyGoals.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DailyGoalRow(
                    goals: dailyGoals,
                    todayMinutes: todayMinutes,
                    todayPages: todayPages,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Lendo agora',
                  style: ReadLogType.display(
                      size: 18, color: ReadLogColors.cream),
                ),
                const SizedBox(height: 12),
                if (reading.isEmpty)
                  _EmptyReadingCard()
                else
                  ...reading.map((b) => ReadLogCatalogCard(
                        title: b.title,
                        author: b.author ?? '',
                        progress: _progress(b),
                        tabColor: ReadLogColors.brass,
                        onTap: () =>
                            context.push('/library/book/${b.id}'),
                      )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _progress(Book b) {
    if (b.totalPages == null || b.totalPages == 0) return 0;
    final current = b.currentPage ?? 0;
    return (current / b.totalPages!).clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Linha de cabeçalho: carimbo de streak + duas stat tiles
class _StreakRow extends StatelessWidget {
  final int streak;
  final int minutes;
  final int pages;

  const _StreakRow({
    required this.streak,
    required this.minutes,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carimbo de streak — único "elemento ousado" da tela
        ReadLogStamp(
          value: '$streak',
          label: streak == 1 ? 'dia' : 'dias',
          color: streak > 0 ? ReadLogColors.stamp : ReadLogColors.sage,
          size: 84,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              _StatTile(label: 'Hoje', value: timeLabel, sub: 'lidos'),
              const SizedBox(height: 10),
              _StatTile(label: 'Páginas', value: '$pages', sub: 'hoje'),
            ],
          ),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ReadLogColors.inkAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: ReadLogColors.cream.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(label,
              style: ReadLogType.mono(
                  size: 10,
                  color: ReadLogColors.sage)),
          const Spacer(),
          Text(
            value,
            style: ReadLogType.mono(
                size: 16,
                weight: FontWeight.w600,
                color: ReadLogColors.brassLight),
          ),
          const SizedBox(width: 4),
          Text(sub,
              style: ReadLogType.mono(
                  size: 10,
                  color: ReadLogColors.cream.withValues(alpha: 0.45))),
        ],
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
        color: ReadLogColors.inkAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: ReadLogColors.cream.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 40,
              color: ReadLogColors.cream.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            'Nenhum livro em leitura',
            style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.cream.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/library/add'),
            child: Text(
              'Adicionar livro',
              style: ReadLogType.mono(
                  size: 12, color: ReadLogColors.brassLight),
            ),
          ),
        ],
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ReadLogColors.inkAlt,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: done
                  ? ReadLogColors.sage.withValues(alpha: 0.5)
                  : ReadLogColors.cream.withValues(alpha: 0.1),
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
                    style: ReadLogType.mono(
                        size: 10, color: ReadLogColors.sage),
                  ),
                  Text(
                    done
                        ? '✓ Meta atingida!'
                        : '$current / $target ${goal.type.unit}',
                    style: ReadLogType.mono(
                      size: 10,
                      color: done
                          ? ReadLogColors.sage
                          : ReadLogColors.cream.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: ReadLogColors.cream.withValues(alpha: 0.1),
                  color: done
                      ? ReadLogColors.sage
                      : ReadLogColors.brass,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
