import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/wishlist_item.dart';
import '../../../../shared/providers/providers.dart';

final _wishlistProvider = FutureProvider.autoDispose<List<WishlistItem>>((ref) {
  return ref.watch(wishlistRepositoryProvider).fetchAll();
});

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_wishlistProvider);

    return LumenTexturedBackground(
      child: Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Lista de Desejos')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => _WishlistBody(items: list),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    )
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
      builder: (_) => _AddWishlistSheet(onSaved: () {
        ref.invalidate(_wishlistProvider);
      }),
    );
  }
}

class _WishlistBody extends ConsumerWidget {
  final List<WishlistItem> items;

  const _WishlistBody({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('Sua lista de desejos está vazia',
                  style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Adicione livros que deseja ler ou comprar.',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_wishlistProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _WishlistTile(
          item: items[i],
          onAcquired: () async {
            await ref.read(wishlistRepositoryProvider).markAcquired(items[i].id);
            ref.invalidate(_wishlistProvider);
          },
          onDelete: () async {
            await ref.read(wishlistRepositoryProvider).delete(items[i].id);
            ref.invalidate(_wishlistProvider);
          },
        ),
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onAcquired;
  final VoidCallback onDelete;

  const _WishlistTile({
    required this.item,
    required this.onAcquired,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.acquired
            ? AppColors.forestGreen.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.acquired ? LumenColors.readSubtle : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(item.coverUrl!,
                  width: 44, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderCover()),
            )
          else
            _PlaceholderCover(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    decoration: item.acquired ? TextDecoration.lineThrough : null,
                    color: item.acquired ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
                if (item.author != null)
                  Text(item.author!, style: AppTextStyles.bodyMedium),
                if (item.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(item.notes!,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (item.acquired)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: AppColors.forestGreen),
                        const SizedBox(width: 4),
                        Text('Adquirido',
                            style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.forestGreen)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              if (!item.acquired)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppColors.forestGreen),
                  tooltip: 'Marcar como adquirido',
                  onPressed: onAcquired,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Remover',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: LumenColors.readSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.menu_book_outlined,
          color: AppColors.forestGreen, size: 22),
    );
  }
}

class _AddWishlistSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddWishlistSheet({required this.onSaved});

  @override
  State<_AddWishlistSheet> createState() => _AddWishlistSheetState();
}

class _AddWishlistSheetState extends State<_AddWishlistSheet> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save(WidgetRef ref) async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await ref.read(wishlistRepositoryProvider).insert(
          title: _titleController.text.trim(),
          author: _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
            Text('Adicionar à lista de desejos',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration:
                  const InputDecoration(labelText: 'Autor (opcional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _save(ref),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
