import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';

final _sessionsProvider =
    FutureProvider.autoDispose.family<List<ReadingSession>, String>((ref, bookId) {
  return ref.watch(sessionRepositoryProvider).fetchByBook(bookId);
});

class SessionHistoryScreen extends ConsumerWidget {
  final String bookId;
  final String bookTitle;

  const SessionHistoryScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(_sessionsProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_outlined,
                        size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text('Nenhuma sessão registrada',
                        style: AppTextStyles.titleMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Inicie uma sessão de leitura para registrar seu progresso.',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final totalMinutes = list
              .map((s) => s.durationMinutes ?? 0)
              .fold<int>(0, (a, b) => a + b);
          final totalPages = list
              .map((s) => s.pagesRead ?? 0)
              .fold<int>(0, (a, b) => a + b);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SummaryRow(
                sessions: list.length,
                totalMinutes: totalMinutes,
                totalPages: totalPages,
              ),
              const SizedBox(height: 20),
              Text('Sessões', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 12),
              ...list.map((s) => _SessionTile(session: s)),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int sessions;
  final int totalMinutes;
  final int totalPages;

  const _SummaryRow({
    required this.sessions,
    required this.totalMinutes,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Sessões', value: '$sessions')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Tempo total', value: timeLabel)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Páginas', value: '$totalPages')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.titleMedium),
          Text(label, style: AppTextStyles.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ReadingSession session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeLabel =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final duration = session.durationMinutes;
    final durationLabel = duration != null
        ? (duration >= 60
            ? '${duration ~/ 60}h ${duration % 60}min'
            : '${duration}min')
        : '—';

    final pages = session.pagesRead;

    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timer_outlined,
                color: AppColors.forestGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dateLabel às $timeLabel', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Duração: $durationLabel',
                        style: AppTextStyles.bodyMedium),
                    if (pages != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: AppColors.textMuted)),
                      Text('$pages páginas',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ],
                ),
                if (session.startPage != null || session.endPage != null)
                  Text(
                    'Pág. ${session.startPage ?? '?'} → ${session.endPage ?? '?'}',
                    style: AppTextStyles.labelMedium,
                  ),
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.notes!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
