import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/note.dart';
import '../../../../shared/providers/providers.dart';

final _notesProvider =
    FutureProvider.autoDispose.family<List<Note>, String>((ref, bookId) {
  return ref.watch(noteRepositoryProvider).fetchByBook(bookId);
});

class NotesScreen extends ConsumerWidget {
  final String bookId;

  const NotesScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(_notesProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('Notas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Nenhuma nota adicionada',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_notesProvider(bookId).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NoteTile(
                note: list[i],
                onDelete: () async {
                  await ref.read(noteRepositoryProvider).delete(list[i].id);
                  ref.invalidate(_notesProvider(bookId));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddNoteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddNoteSheet(
        bookId: bookId,
        onSaved: () => ref.invalidate(_notesProvider(bookId)),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;

  const _NoteTile({required this.note, required this.onDelete});

  Color _typeColor(NoteType type) {
    switch (type) {
      case NoteType.highlight:
        return AppColors.warmGold;
      case NoteType.reflection:
        return AppColors.forestGreen;
      case NoteType.observation:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(note.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              note.type.label,
              style: AppTextStyles.labelMedium.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.pageNumber != null) ...[
                  Text('Pág. ${note.pageNumber}',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                ],
                Text(note.content, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  final String bookId;
  final VoidCallback onSaved;

  const _AddNoteSheet({required this.bookId, required this.onSaved});

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _contentController = TextEditingController();
  final _pageController = TextEditingController();
  NoteType _type = NoteType.observation;
  bool _loading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _loading = true);
    await ref.read(noteRepositoryProvider).insert(
          bookId: widget.bookId,
          type: _type,
          content: content,
          pageNumber: int.tryParse(_pageController.text),
        );

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nova nota', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: NoteType.values.map((t) {
              final selected = _type == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: AppColors.forestGreen,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Página (opcional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Conteúdo'),
            autofocus: true,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
