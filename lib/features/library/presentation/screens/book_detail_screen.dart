import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../widgets/book_review_dialog.dart';
import '../widgets/book_share_card.dart';

final _bookDetailProvider =
    FutureProvider.autoDispose.family<Book, String>((ref, id) async {
  final book = await ref.read(bookRepositoryProvider).fetchById(id);
  if (book == null) throw Exception('Livro não encontrado');
  return book;
});

final _recentSessionsProvider =
    FutureProvider.autoDispose.family<List<ReadingSession>, String>((ref, bookId) async {
  final all = await ref.watch(sessionRepositoryProvider).fetchByBook(bookId);
  return all.take(3).toList();
});

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  final _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(_bookDetailProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (book.valueOrNull != null) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartilhar card',
              onPressed: () => _shareBookCard(context, book.valueOrNull!),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () async {
                final updated = await context.push(
                  '/library/book/${widget.bookId}/edit',
                  extra: book.valueOrNull!,
                );
                if (updated == true) {
                  ref.invalidate(_bookDetailProvider(widget.bookId));
                }
              },
            ),
          ],
        ],
      ),
      body: book.when(
        loading: () => const SkelScreenList(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (b) => _BookDetailBody(book: b),
      ),
    );
  }

  Future<void> _shareBookCard(BuildContext context, Book book) async {
    // Mostra loading enquanto renderiza o card
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando card...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final Uint8List imageBytes = await _screenshotController.captureFromLongWidget(
      BookShareCard(book: book),
      pixelRatio: 3.0,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/readlog_card_${book.id}.png');
    await file.writeAsBytes(imageBytes);

    if (!context.mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: book.title,
        text: '${book.title}${book.author != null ? ' · ${book.author}' : ''} — ReadLog',
      ),
    );
  }
}

class _BookDetailBody extends ConsumerWidget {
  final Book book;

  const _BookDetailBody({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentSessions = ref.watch(_recentSessionsProvider(book.id));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa
            Container(
              width: 80,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.forestGreen, size: 36)),
                    )
                  : const Icon(Icons.menu_book_outlined,
                      color: AppColors.forestGreen, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: AppTextStyles.displayMedium),
                  if (book.author != null) ...[
                    const SizedBox(height: 4),
                    Text(book.author!, style: AppTextStyles.bodyLarge),
                  ],
                  const SizedBox(height: 8),
                  _StatusBadge(status: book.status),
                  if (book.rating != null) ...[
                    const SizedBox(height: 8),
                    _StarRating(rating: book.rating!),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Progresso + métricas de página
        if (book.currentPage != null && book.totalPages != null) ...[
          _ProgressBar(current: book.currentPage!, total: book.totalPages!),
          const SizedBox(height: 12),
          _PageMetricsRow(
              current: book.currentPage!, total: book.totalPages!),
          const SizedBox(height: 16),
        ] else if (book.currentPage != null || book.totalPages != null) ...[
          const SizedBox(height: 8),
        ],

        if (book.currentPage != null) ...[
          _InfoRow(
            label: 'Página atual',
            value: book.totalPages != null
                ? '${book.currentPage} / ${book.totalPages}'
                : '${book.currentPage}',
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.totalPages != null) ...[
          _InfoRow(label: 'Total de páginas', value: '${book.totalPages}'),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.genre != null) ...[
          _InfoRow(label: 'Gênero', value: book.genre!),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.publisher != null) ...[
          _InfoRow(label: 'Editora', value: book.publisher!),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.startDate != null) ...[
          _InfoRow(
            label: 'Início',
            value:
                '${book.startDate!.day.toString().padLeft(2, '0')}/${book.startDate!.month.toString().padLeft(2, '0')}/${book.startDate!.year}',
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.endDate != null) ...[
          _InfoRow(
            label: 'Concluído',
            value:
                '${book.endDate!.day.toString().padLeft(2, '0')}/${book.endDate!.month.toString().padLeft(2, '0')}/${book.endDate!.year}',
          ),
          const Divider(height: 1, color: AppColors.border),
        ],

        const SizedBox(height: 20),

        // Ações
        if (book.status == BookStatus.reading)
          FilledButton.icon(
            onPressed: () => context.go('/session?bookId=${book.id}'),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Iniciar leitura'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/notes/${book.id}'),
          icon: const Icon(Icons.note_alt_outlined),
          label: const Text('Notas'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/highlights/${book.id}',
              extra: book.title),
          icon: const Icon(Icons.format_quote),
          label: const Text('Trechos favoritos'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warmGold,
            side: const BorderSide(color: AppColors.warmGold),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/session-history/${book.id}',
              extra: book.title),
          icon: const Icon(Icons.history_outlined),
          label: const Text('Histórico de sessões'),
        ),

        const SizedBox(height: 20),
        _StatusSelector(book: book),

        // Sessões recentes
        recentSessions.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (sessions) {
            if (sessions.isEmpty) return const SizedBox.shrink();
            return _RecentSessions(sessions: sessions, bookId: book.id, bookTitle: book.title);
          },
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = (current / total).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progresso', style: AppTextStyles.labelMedium),
            Text('$percent%', style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
          ),
        ),
      ],
    );
  }
}

class _PageMetricsRow extends StatelessWidget {
  final int current;
  final int total;

  const _PageMetricsRow({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = (total - current).clamp(0, total);
    final pagesRead = current.clamp(0, total);

    return Row(
      children: [
        Expanded(
          child: _MetricCell(
            label: 'Lidas',
            value: '$pagesRead',
            sub: 'págs',
            valueColor: AppColors.forestGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCell(
            label: 'Restantes',
            value: '$remaining',
            sub: 'págs',
            valueColor: AppColors.warmGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCell(
            label: 'Total',
            value: '$total',
            sub: 'págs',
            valueColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color valueColor;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: valueColor,
                    fontSize: 20,
                  ),
                ),
                TextSpan(
                  text: ' $sub',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(value, style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.label, style: AppTextStyles.labelMedium),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i < rating ? AppColors.warmGold : AppColors.border,
        );
      }),
    );
  }
}

class _StatusSelector extends ConsumerWidget {
  final Book book;

  const _StatusSelector({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alterar status', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: BookStatus.values.map((s) {
            final isSelected = book.status == s;
            return ChoiceChip(
              label: Text(s.label),
              selected: isSelected,
              onSelected: (_) async {
                // Salva o novo status (e end_date se necessário)
                final updates = <String, dynamic>{'status': s.dbValue};
                if (s == BookStatus.read && book.endDate == null) {
                  updates['end_date'] =
                      DateTime.now().toIso8601String().substring(0, 10);
                }
                await ref
                    .read(bookRepositoryProvider)
                    .update(book.id, updates);
                ref.invalidate(_bookDetailProvider(book.id));

                // Ao marcar como "Lido", abre o dialog de avaliação
                if (s == BookStatus.read && context.mounted) {
                  final updatedBook =
                      book.copyWith(status: BookStatus.read);
                  final saved = await showBookReviewDialog(
                    context,
                    updatedBook,
                  );
                  if (saved == true) {
                    ref.invalidate(_bookDetailProvider(book.id));
                  }
                }
              },
              selectedColor: AppColors.forestGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecentSessions extends StatelessWidget {
  final List<ReadingSession> sessions;
  final String bookId;
  final String bookTitle;

  const _RecentSessions({
    required this.sessions,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sessões recentes', style: AppTextStyles.titleMedium),
            TextButton(
              onPressed: () =>
                  context.push('/session-history/$bookId', extra: bookTitle),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sessions.map((s) {
          final date = s.startedAt;
          final dateLabel =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
          final duration = s.durationMinutes;
          final durationLabel = duration != null
              ? (duration >= 60
                  ? '${duration ~/ 60}h ${duration % 60}min'
                  : '${duration}min')
              : '—';
          final pages = s.pagesRead;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(dateLabel, style: AppTextStyles.titleMedium),
                const Spacer(),
                Text(durationLabel, style: AppTextStyles.bodyMedium),
                if (pages != null) ...[
                  const SizedBox(width: 12),
                  Text('$pages pág.', style: AppTextStyles.bodyMedium),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
