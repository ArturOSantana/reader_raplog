import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';

final _bookDetailProvider =
    FutureProvider.autoDispose.family<Book, String>((ref, id) {
  return ref.watch(bookRepositoryProvider).fetchById(id);
});

class BookDetailScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(_bookDetailProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (book.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
            ),
        ],
      ),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (b) => _BookDetailBody(book: b),
      ),
    );
  }
}

class _BookDetailBody extends ConsumerWidget {
  final Book book;

  const _BookDetailBody({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_outlined,
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
        if (book.totalPages != null) ...[
          _InfoRow(label: 'Total de paginas', value: '${book.totalPages}'),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.genre != null) ...[
          _InfoRow(label: 'Genero', value: book.genre!),
          const Divider(height: 1, color: AppColors.border),
        ],
        if (book.publisher != null) ...[
          _InfoRow(label: 'Editora', value: book.publisher!),
          const Divider(height: 1, color: AppColors.border),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/session?bookId=${book.id}'),
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Iniciar leitura'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/notes/${book.id}'),
          icon: const Icon(Icons.note_alt_outlined),
          label: const Text('Ver notas'),
        ),
        const SizedBox(height: 12),
        _StatusSelector(book: book),
      ],
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
        const SizedBox(height: 8),
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
                await ref
                    .read(bookRepositoryProvider)
                    .update(book.id, {'status': s.dbValue});
                ref.invalidate(_bookDetailProvider(book.id));
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
