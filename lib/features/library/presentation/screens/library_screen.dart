import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';

final _selectedStatusProvider = StateProvider<BookStatus?>((ref) => null);

final _booksProvider = FutureProvider.autoDispose<List<Book>>((ref) {
  final status = ref.watch(_selectedStatusProvider);
  return ref.watch(bookRepositoryProvider).fetchAll(status: status);
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(_selectedStatusProvider);
    final books = ref.watch(_booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/library/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusFilterBar(selected: selectedStatus),
          Expanded(
            child: books.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.library_books_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum livro aqui ainda',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_booksProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BookTile(book: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends ConsumerWidget {
  final BookStatus? selected;

  const _StatusFilterBar({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      (null, 'Todos'),
      (BookStatus.reading, 'Lendo'),
      (BookStatus.wantToRead, 'Quero Ler'),
      (BookStatus.read, 'Lidos'),
      (BookStatus.abandoned, 'Abandonados'),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            child: FilterChip(
              label: Text(opt.$2),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(_selectedStatusProvider.notifier).state = opt.$1,
              selectedColor: AppColors.forestGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
              ),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppColors.forestGreen : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;

  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/library/book/${book.id}'),
      child: Container(
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
                color: AppColors.forestGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.menu_book_outlined,
                  color: AppColors.forestGreen, size: 22),
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
                  if (book.author != null) ...[
                    const SizedBox(height: 2),
                    Text(book.author!,
                        style: AppTextStyles.bodyMedium, maxLines: 1),
                  ],
                  const SizedBox(height: 6),
                  _StatusBadge(status: book.status),
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

class _StatusBadge extends StatelessWidget {
  final BookStatus status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case BookStatus.reading:
        return AppColors.forestGreen;
      case BookStatus.wantToRead:
        return AppColors.warmGold;
      case BookStatus.read:
        return AppColors.success;
      case BookStatus.abandoned:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelMedium.copyWith(color: _color),
      ),
    );
  }
}
