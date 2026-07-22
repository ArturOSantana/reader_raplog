import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';

final _homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchDailyStats(),
    sessionRepo.fetchStreak(),
    bookRepo.fetchAll(status: BookStatus.reading),
  ]);

  return {
    'daily': results[0] as Map<String, dynamic>,
    'streak': results[1] as int,
    'reading': results[2] as List<Book>,
  };
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_homeDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Readlog'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (d) {
          final daily = d['daily'] as Map<String, dynamic>;
          final streak = d['streak'] as int;
          final reading = d['reading'] as List<Book>;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_homeDataProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StreakCard(streak: streak),
                const SizedBox(height: 16),
                _DailyStatsCard(
                  minutes: (daily['total_minutes'] as num?)?.toInt() ?? 0,
                  pages: (daily['total_pages'] as num?)?.toInt() ?? 0,
                ),
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
