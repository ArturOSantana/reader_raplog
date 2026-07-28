import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/readlog_theme.dart';
import '../../../../theme/readlog_components.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';

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
      backgroundColor: ReadLogColors.paper,
      body: Column(
        children: [
          ReadLogPageHeader(
            kicker: 'ACERVO',
            title: 'Biblioteca',
            showMenuButton: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_outlined,
                    size: 20, color: ReadLogColors.charcoal),
                tooltip: 'Escanear ISBN',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.add,
                    size: 20, color: ReadLogColors.charcoal),
                tooltip: 'Adicionar livro',
                onPressed: () => context.push('/library/add'),
              ),
            ],
          ),
          _StatusFilterBar(selected: selectedStatus),
          Expanded(
            child: books.when(
              loading: () => const SkelScreenList(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_books_outlined,
                            size: 48,
                            color:
                                ReadLogColors.charcoal.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum livro aqui ainda',
                          style: ReadLogType.mono(
                              size: 13,
                              color: ReadLogColors.charcoal
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: ReadLogColors.brass,
                  onRefresh: () => ref.refresh(_booksProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
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

/// Barra de filtros usando ReadLogChip do design system
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

    return Container(
      color: ReadLogColors.paperAlt,
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: options.map((opt) {
            final isSelected = selected == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ReadLogChip(
                label: opt.$2,
                variant: isSelected
                    ? ReadLogChipVariant.selected
                    : ReadLogChipVariant.outline,
                onTap: () => ref
                    .read(_selectedStatusProvider.notifier)
                    .state = opt.$1,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

Color _tabColorForStatus(BookStatus status) {
  switch (status) {
    case BookStatus.reading:
      return ReadLogColors.brass;
    case BookStatus.wantToRead:
      return ReadLogColors.sage;
    case BookStatus.read:
      return ReadLogColors.stamp;
    case BookStatus.abandoned:
      return ReadLogColors.charcoal.withValues(alpha: 0.3);
  }
}

double _progressForBook(Book b) {
  if (b.totalPages == null || b.totalPages == 0) return 0;
  return ((b.currentPage ?? 0) / b.totalPages!).clamp(0.0, 1.0);
}

class _BookTile extends StatelessWidget {
  final Book book;

  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return ReadLogCatalogCard(
      title: book.title,
      author: book.author ?? '',
      progress: _progressForBook(book),
      tabColor: _tabColorForStatus(book.status),
      onTap: () => context.push('/library/book/${book.id}'),
    );
  }
}
