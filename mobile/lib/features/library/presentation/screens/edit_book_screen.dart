import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';

class EditBookScreen extends ConsumerStatefulWidget {
  final Book book;

  const EditBookScreen({super.key, required this.book});

  @override
  ConsumerState<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends ConsumerState<EditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _pagesController;
  late final TextEditingController _genreController;
  late final TextEditingController _publisherController;
  late final TextEditingController _currentPageController;
  late final TextEditingController _ratingController;
  String? _coverUrl;
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _titleController = TextEditingController(text: b.title);
    _authorController = TextEditingController(text: b.author ?? '');
    _pagesController =
        TextEditingController(text: b.totalPages?.toString() ?? '');
    _genreController = TextEditingController(text: b.genre ?? '');
    _publisherController = TextEditingController(text: b.publisher ?? '');
    _currentPageController =
        TextEditingController(text: b.currentPage?.toString() ?? '');
    _ratingController =
        TextEditingController(text: b.rating?.toString() ?? '');
    _coverUrl = b.coverUrl;
    _deadline = b.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    _genreController.dispose();
    _publisherController.dispose();
    _currentPageController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Prazo para finalizar o livro',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final fields = <String, dynamic>{
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
        'current_page': _currentPageController.text.isEmpty
            ? null
            : int.tryParse(_currentPageController.text),
        'rating': _ratingController.text.isEmpty
            ? null
            : int.tryParse(_ratingController.text),
        'cover_url': _coverUrl,
        'deadline':
            _deadline != null ? DateFormat('yyyy-MM-dd').format(_deadline!) : null,
      };

      await ref.read(bookRepositoryProvider).update(widget.book.id, fields);

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
          ),
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
        title: const Text('Editar livro'),
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
            // ── Capa atual ──────────────────────────────────────
            if (_coverUrl != null && _coverUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: _coverUrl!,
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
                      child: Text('Capa atual', style: AppTextStyles.bodyMedium),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _coverUrl = null),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remover capa',
                    ),
                  ],
                ),
              ),

            // ── Campos ─────────────────────────────────────────
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
              controller: _currentPageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Página atual'),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final current = int.tryParse(v);
                if (current == null) return 'Número inválido';
                final total = int.tryParse(_pagesController.text);
                if (total != null && current > total) {
                  return 'Página atual não pode ser maior que o total';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ratingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Avaliação (1–5)',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final r = int.tryParse(v);
                if (r == null || r < 1 || r > 5) {
                  return 'Avaliação deve ser entre 1 e 5';
                }
                return null;
              },
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
            const SizedBox(height: 16),

            // ── Prazo de leitura ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prazo de leitura', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        _deadline != null
                            ? DateFormat('dd/MM/yyyy').format(_deadline!)
                            : 'Sem prazo definido',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _deadline != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remover prazo',
                  ),
                TextButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_deadline != null ? 'Alterar' : 'Definir'),
                ),
              ],
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
                  : const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
