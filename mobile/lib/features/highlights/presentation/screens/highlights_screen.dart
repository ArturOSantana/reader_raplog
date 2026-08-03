import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/highlight.dart';
import '../../../../shared/providers/providers.dart';

final _highlightsProvider =
    FutureProvider.autoDispose.family<List<Highlight>, String>((ref, bookId) {
  return ref.watch(highlightRepositoryProvider).fetchByBook(bookId);
});

class HighlightsScreen extends ConsumerWidget {
  final String bookId;
  final String bookTitle;

  const HighlightsScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(_highlightsProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: highlights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => _HighlightBody(bookId: bookId, highlights: list),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.warmGold,
        foregroundColor: Colors.white,
        child: const Icon(Icons.format_quote),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddHighlightSheet(
        bookId: bookId,
        onSaved: () => ref.invalidate(_highlightsProvider(bookId)),
      ),
    );
  }
}

class _HighlightBody extends ConsumerWidget {
  final String bookId;
  final List<Highlight> highlights;

  const _HighlightBody({required this.bookId, required this.highlights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (highlights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.format_quote, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('Nenhum favorito', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text('Salve seus trechos favoritos tocando no +.',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_highlightsProvider(bookId).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: highlights.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _HighlightTile(
          highlight: highlights[i],
          onDelete: () async {
            await ref
                .read(highlightRepositoryProvider)
                .delete(highlights[i].id);
            ref.invalidate(_highlightsProvider(bookId));
          },
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final Highlight highlight;
  final VoidCallback onDelete;

  const _HighlightTile({required this.highlight, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.25)),
        // borda esquerda dourada
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 60,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: AppColors.warmGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${highlight.text}"',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (highlight.pageNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Página ${highlight.pageNumber}',
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddHighlightSheet extends StatefulWidget {
  final String bookId;
  final VoidCallback onSaved;

  const _AddHighlightSheet({required this.bookId, required this.onSaved});

  @override
  State<_AddHighlightSheet> createState() => _AddHighlightSheetState();
}

class _AddHighlightSheetState extends State<_AddHighlightSheet> {
  final _textController = TextEditingController();
  final _pageController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save(WidgetRef ref) async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await ref.read(highlightRepositoryProvider).insert(
          bookId: widget.bookId,
          text: _textController.text.trim(),
          pageNumber: int.tryParse(_pageController.text),
        );
    setState(() => _loading = false);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salvar trecho favorito', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            TextFormField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Trecho *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Página (opcional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _save(ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmGold,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
