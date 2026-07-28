import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../data/book_search_result.dart';
import '../../data/book_search_service.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _isbnController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();
  final _genreController = TextEditingController();
  final _publisherController = TextEditingController();

  final _bookSearch = BookSearchService();
  Timer? _debounce;
  List<BookSearchResult> _suggestions = [];
  bool _searching = false;
  bool _searchingIsbn = false;
  String? _selectedCoverUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    _genreController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _bookSearch.search(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
    });
  }

  Future<void> _searchByIsbn() async {
    final isbn = _isbnController.text.trim().replaceAll(RegExp(r'[-\s]'), '');
    if (isbn.isEmpty) return;
    setState(() => _searchingIsbn = true);
    final results = await _bookSearch.search('isbn:$isbn');
    setState(() => _searchingIsbn = false);
    if (results.isNotEmpty) {
      _fillFromResult(results.first);
      _isbnController.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ISBN não encontrado.')),
      );
    }
  }

  void _fillFromResult(BookSearchResult result) {
    _titleController.text = result.title;
    _authorController.text = result.author ?? '';
    _pagesController.text = result.totalPages?.toString() ?? '';
    _genreController.text = result.genre ?? '';
    _publisherController.text = result.publisher ?? '';
    setState(() {
      _selectedCoverUrl = result.coverUrl;
      _suggestions = [];
      _searchController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(bookRepositoryProvider).insert({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        'total_pages': _pagesController.text.isEmpty
            ? null
            : int.tryParse(_pagesController.text),
        'genre': _genreController.text.trim().isEmpty
            ? null
            : _genreController.text.trim(),
        'publisher': _publisherController.text.trim().isEmpty
            ? null
            : _publisherController.text.trim(),
        'cover_url': _selectedCoverUrl,
        'status': 'want_to_read',
      });

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar livro'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Busca por ISBN ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _isbnController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _searchingIsbn ? null : _searchByIsbn(),
                    decoration: InputDecoration(
                      labelText: 'Buscar por ISBN',
                      prefixIcon: const Icon(Icons.tag),
                      suffixIcon: _searchingIsbn
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _searchingIsbn ? null : _searchByIsbn,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 52),
                    ),
                    child: const Text('Buscar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Busca por título/autor ──────────────────────────
            TextFormField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Buscar por título ou autor',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),

            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: _suggestions.map((r) => _SuggestionTile(
                    result: r,
                    onTap: () => _fillFromResult(r),
                  )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text('Dados do livro', style: AppTextStyles.labelMedium),
            const SizedBox(height: 16),

            // ── Capa selecionada ────────────────────────────────
            if (_selectedCoverUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: _selectedCoverUrl!,
                        width: 56,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 80,
                          color: AppColors.border,
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Capa encontrada',
                          style: AppTextStyles.bodyMedium),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedCoverUrl = null),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remover capa',
                    ),
                  ],
                ),
              ),

            // ── Campos manuais ──────────────────────────────────
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Título obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Autor'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Número de páginas'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genreController,
              decoration: const InputDecoration(labelText: 'Gênero'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _publisherController,
              decoration: const InputDecoration(labelText: 'Editora'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar livro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final BookSearchResult result;
  final VoidCallback onTap;

  const _SuggestionTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (result.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: result.coverUrl!,
                  width: 36,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(
                    width: 36,
                    height: 50,
                    child: Icon(Icons.menu_book_outlined,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
              )
            else
              const SizedBox(
                width: 36,
                height: 50,
                child: Icon(Icons.menu_book_outlined,
                    color: AppColors.textMuted, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (result.author != null)
                    Text(result.author!,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  if (result.totalPages != null)
                    Text('${result.totalPages} páginas',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
