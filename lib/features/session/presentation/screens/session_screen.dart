import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';

final _activeSessionIdProvider = StateProvider<String?>((ref) => null);
final _timerRunningProvider = StateProvider<bool>((ref) => false);
final _elapsedSecondsProvider = StateProvider<int>((ref) => 0);

class SessionScreen extends ConsumerStatefulWidget {
  final String? bookId;

  const SessionScreen({super.key, this.bookId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  Timer? _timer;
  final _startPageController = TextEditingController();
  final _endPageController = TextEditingController();
  final _notesController = TextEditingController();
  Book? _selectedBook;
  List<Book> _readingBooks = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await ref
        .read(bookRepositoryProvider)
        .fetchAll(status: BookStatus.reading);
    if (mounted) {
      setState(() {
        _readingBooks = books;
        if (widget.bookId != null) {
          _selectedBook = books.firstWhere(
            (b) => b.id == widget.bookId,
            orElse: () => books.first,
          );
        } else if (books.isNotEmpty) {
          _selectedBook = books.first;
        }
      });
    }
  }

  void _startTimer() {
    ref.read(_elapsedSecondsProvider.notifier).state = 0;
    ref.read(_timerRunningProvider.notifier).state = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(_elapsedSecondsProvider.notifier).update((s) => s + 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    ref.read(_timerRunningProvider.notifier).state = false;
  }

  Future<void> _startSession() async {
    if (_selectedBook == null) return;
    final startPage = int.tryParse(_startPageController.text) ?? 0;

    final session = await ref.read(sessionRepositoryProvider).startSession(
          bookId: _selectedBook!.id,
          startPage: startPage,
        );
    ref.read(_activeSessionIdProvider.notifier).state = session.id;
    _startTimer();
  }

  Future<void> _finishSession() async {
    final sessionId = ref.read(_activeSessionIdProvider);
    if (sessionId == null) return;
    _stopTimer();

    final endPage = int.tryParse(_endPageController.text) ?? 0;
    await ref.read(sessionRepositoryProvider).finishSession(
          sessionId: sessionId,
          endPage: endPage,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );

    ref.read(_activeSessionIdProvider.notifier).state = null;
    ref.read(_elapsedSecondsProvider.notifier).state = 0;
    _endPageController.clear();
    _notesController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessao registrada com sucesso!')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startPageController.dispose();
    _endPageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(_timerRunningProvider);
    final elapsed = ref.watch(_elapsedSecondsProvider);
    final sessionId = ref.watch(_activeSessionIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leitura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isRunning && sessionId == null) ...[
              Text('Livro', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              if (_readingBooks.isEmpty)
                Text(
                  'Nenhum livro em leitura. Adicione um na biblioteca.',
                  style: AppTextStyles.bodyMedium,
                )
              else
                DropdownButtonFormField<Book>(
                  // ignore: deprecated_member_use
                  value: _selectedBook,
                  decoration: const InputDecoration(labelText: 'Selecionar livro'),
                  items: _readingBooks
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b.title, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (b) => setState(() => _selectedBook = b),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startPageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pagina inicial'),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _selectedBook != null ? _startSession : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar leitura'),
              ),
            ],
            if (isRunning || sessionId != null) ...[
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      _selectedBook?.title ?? '',
                      style: AppTextStyles.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _formatTime(elapsed),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('em andamento', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              TextFormField(
                controller: _endPageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pagina atual'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observacoes (opcional)'),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.stop),
                label: const Text('Encerrar sessao'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
