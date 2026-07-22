import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

final _dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchDailyStats(),
    sessionRepo.fetchStreak(),
    sessionRepo.fetchHeatmap(days: 365),
    bookRepo.fetchAll(),
  ]);

  return {
    'daily': results[0] as Map<String, dynamic>,
    'streak': results[1] as int,
    'heatmap': results[2] as List<Map<String, dynamic>>,
    'books': results[3],
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (d) {
          final daily = d['daily'] as Map<String, dynamic>;
          final streak = d['streak'] as int;
          final heatmap = d['heatmap'] as List<Map<String, dynamic>>;
          final books = d['books'] as List;

          final totalMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final totalPages = (daily['total_pages'] as num?)?.toInt() ?? 0;
          final readBooks = books.where((b) {
            try {
              return (b as dynamic).status.dbValue == 'read';
            } catch (_) {
              return false;
            }
          }).length;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_dashboardDataProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Resumo', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                _SummaryGrid(
                  streak: streak,
                  todayMinutes: totalMinutes,
                  todayPages: totalPages,
                  readBooks: readBooks,
                ),
                const SizedBox(height: 28),
                Text('Atividade', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                _HeatmapWidget(data: heatmap),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int streak;
  final int todayMinutes;
  final int todayPages;
  final int readBooks;

  const _SummaryGrid({
    required this.streak,
    required this.todayMinutes,
    required this.todayPages,
    required this.readBooks,
  });

  @override
  Widget build(BuildContext context) {
    final hours = todayMinutes ~/ 60;
    final mins = todayMinutes % 60;
    final timeLabel = hours > 0 ? '${hours}h${mins}min' : '${mins}min';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _GridTile(label: 'Sequencia', value: '$streak dias'),
        _GridTile(label: 'Hoje', value: timeLabel),
        _GridTile(label: 'Paginas hoje', value: '$todayPages'),
        _GridTile(label: 'Livros lidos', value: '$readBooks'),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  final String label;
  final String value;

  const _GridTile({required this.label, required this.value});

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          Text(value, style: AppTextStyles.displayMedium),
        ],
      ),
    );
  }
}

class _HeatmapWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _HeatmapWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text('Nenhuma sessao registrada ainda',
              style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final maxMinutes = data
        .map((d) => (d['total_minutes'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(1.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: data.map((d) {
          final minutes = (d['total_minutes'] as num?)?.toDouble() ?? 0.0;
          final intensity = (minutes / maxMinutes).clamp(0.1, 1.0);
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: intensity),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
