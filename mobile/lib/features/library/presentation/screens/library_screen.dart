import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';

final _selectedStatusProvider = StateProvider<BookStatus?>((ref) => null);

// Modo de visualização: false = lista, true = por gênero
final _genreViewProvider = StateProvider<bool>((ref) => false);

final _booksProvider = FutureProvider.autoDispose<List<Book>>((ref) {
  final status = ref.watch(_selectedStatusProvider);
  return ref.watch(bookRepositoryProvider).fetchAll(status: status);
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(_selectedStatusProvider);
    final genreView = ref.watch(_genreViewProvider);
    final books = ref.watch(_booksProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? ReadLogColors.canvas : ReadLogColors.surface,
      body: Column(
        children: [
          ReadLogPageHeader(
            kicker: 'ACERVO',
            title: 'Biblioteca',
            showMenuButton: true,
            actions: [
              // Toggle lista / por gênero
              IconButton(
                icon: Icon(
                  genreView
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined,
                  size: 20,
                  color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal,
                ),
                tooltip: genreView ? 'Visão em lista' : 'Visão por gênero',
                onPressed: () =>
                    ref.read(_genreViewProvider.notifier).state = !genreView,
              ),
              IconButton(
                icon: Icon(Icons.qr_code_scanner_outlined,
                    size: 20, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
                tooltip: 'Escanear ISBN',
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.add,
                    size: 20, color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : ReadLogColors.charcoal),
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
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                if (genreView) {
                  return RefreshIndicator(
                    color: ReadLogColors.brass,
                    onRefresh: () => ref.refresh(_booksProvider.future),
                    child: _GenreView(books: list),
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

// ── Barra de filtros ──────────────────────────────────────────────────────────

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? LumenColors.canvas : ReadLogColors.paperAlt,
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

// ── Visão por gênero ──────────────────────────────────────────────────────────

class _GenreView extends StatefulWidget {
  final List<Book> books;

  const _GenreView({required this.books});

  @override
  State<_GenreView> createState() => _GenreViewState();
}

class _GenreViewState extends State<_GenreView> {
  late final Map<String, bool> _expanded;

  // Agrupa e ordena; livros sem gênero vão para "Sem gênero"
  Map<String, List<Book>> _buildGroups(List<Book> books) {
    final map = <String, List<Book>>{};
    for (final book in books) {
      final key = (book.genre != null && book.genre!.trim().isNotEmpty)
          ? book.genre!.trim()
          : 'Sem gênero';
      map.putIfAbsent(key, () => []).add(book);
    }
    // Ordena: chaves alfabéticas, "Sem gênero" sempre por último
    final keys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Sem gênero') return 1;
        if (b == 'Sem gênero') return -1;
        return a.compareTo(b);
      });
    return {for (final k in keys) k: map[k]!};
  }

  @override
  void initState() {
    super.initState();
    final groups = _buildGroups(widget.books);
    // Começa com todos os grupos expandidos
    _expanded = {for (final k in groups.keys) k: true};
  }

  @override
  void didUpdateWidget(_GenreView old) {
    super.didUpdateWidget(old);
    if (old.books != widget.books) {
      final groups = _buildGroups(widget.books);
      // Preserva estado de expansão; novos grupos começam expandidos
      for (final k in groups.keys) {
        _expanded.putIfAbsent(k, () => true);
      }
      // Remove chaves obsoletas
      _expanded.removeWhere((k, _) => !groups.containsKey(k));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _buildGroups(widget.books);

    return CustomScrollView(
      slivers: [
        for (final entry in groups.entries) ...[
          SliverToBoxAdapter(
            child: _GenreHeader(
              genre: entry.key,
              count: entry.value.length,
              expanded: _expanded[entry.key] ?? true,
              isDark: isDark,
              onTap: () => setState(
                  () => _expanded[entry.key] = !(_expanded[entry.key] ?? true)),
            ),
          ),
          if (_expanded[entry.key] ?? true)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _BookTile(book: entry.value[i]),
                  ),
                  childCount: entry.value.length,
                ),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _GenreHeader extends StatelessWidget {
  final String genre;
  final int count;
  final bool expanded;
  final bool isDark;
  final VoidCallback onTap;

  const _GenreHeader({
    required this.genre,
    required this.count,
    required this.expanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fgMut = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final divider = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Ícone de colapso
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: fgMut,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                genre,
                style: ReadLogType.kicker(size: 11, color: fgMut),
              ),
            ),
            // Badge com contagem
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: ReadLogType.mono(
                  size: 11,
                  weight: FontWeight.w600,
                  color: fgMut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
      coverUrl: book.coverUrl,
      currentPage: book.currentPage,
      totalPages: book.totalPages,
      onTap: () => context.push('/library/book/${book.id}'),
    );
  }
}
