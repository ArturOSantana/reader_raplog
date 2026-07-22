import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();
  final _genreController = TextEditingController();
  final _publisherController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    _genreController.dispose();
    _publisherController.dispose();
    super.dispose();
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
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titulo *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Titulo obrigatorio' : null,
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
                  const InputDecoration(labelText: 'Numero de paginas'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genreController,
              decoration: const InputDecoration(labelText: 'Genero'),
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
