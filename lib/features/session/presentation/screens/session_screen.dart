import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';
import '../../../achievements/data/achievement_service.dart';
import '../../../home/presentation/screens/home_screen.dart';

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
        _prefillStartPage();
      });
    }
  }

  void _prefillStartPage() {
    if (_selectedBook?.currentPage != null) {
      _startPageController.text = '${_selectedBook!.currentPage}';
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
    final startPage = int.tryParse(_startPageController.text) ?? 0;
    final sessionStartedAt = DateTime.now().subtract(
        Duration(seconds: ref.read(_elapsedSecondsProvider)));

    await ref.read(sessionRepositoryProvider).finishSession(
          sessionId: sessionId,
          endPage: endPage,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );

    if (_selectedBook != null && endPage > 0) {
      await ref
          .read(bookRepositoryProvider)
          .update(_selectedBook!.id, {'current_page': endPage});
    }

    ref.read(_activeSessionIdProvider.notifier).state = null;
    ref.read(_elapsedSecondsProvider.notifier).state = 0;
    ref.read(homeRefreshTriggerProvider.notifier).state++;

    // Atualiza a página inicial para a próxima sessão
    if (endPage > 0) {
      _startPageController.text = '$endPage';
    }
    _endPageController.clear();
    _notesController.clear();

    // Verificar conquistas automaticamente
    _checkAchievements(
      pagesInSession: (endPage - startPage).clamp(0, 99999),
      sessionStartedAt: sessionStartedAt,
    );

    // UC11 — verificar se chegou na última página
    if (_selectedBook != null &&
        _selectedBook!.totalPages != null &&
        endPage >= _selectedBook!.totalPages! &&
        _selectedBook!.status == BookStatus.reading) {
      if (mounted) {
        _showCompleteBookDialog();
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão registrada com sucesso!')),
      );
    }
  }

  void _showCompleteBookDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Livro concluído!'),
        content: Text(
          'Você chegou à última página de "${_selectedBook!.title}". Deseja marcar como lido?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sessão registrada!')),
              );
            },
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookRepositoryProvider).update(
                _selectedBook!.id,
                {
                  'status': 'read',
                  'end_date':
                      DateTime.now().toIso8601String().substring(0, 10),
                },
              );
              // Verifica conquistas relacionadas a livros concluídos
              _checkAchievements(
                pagesInSession: 0,
                sessionStartedAt: DateTime.now(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '"${_selectedBook!.title}" marcado como lido!'),
                  ),
                );
              }
            },
            child: const Text('Marcar como lido'),
          ),
        ],
      ),
    );
  }

  void _checkAchievements({
    required int pagesInSession,
    required DateTime sessionStartedAt,
  }) {
    final client = ref.read(supabaseClientProvider);
    final service = AchievementService(client);
    service.collectStats(
      pagesInSession: pagesInSession,
      durationMinutes: ref.read(_elapsedSecondsProvider) ~/ 60,
      sessionStartedAt: sessionStartedAt,
    ).then((stats) {
      return service.checkAndUnlock(
        totalPagesRead: stats['total_pages'] as int,
        totalMinutesRead: stats['total_minutes'] as int,
        totalBooksRead: stats['total_books'] as int,
        currentStreak: stats['streak'] as int,
        pagesInSession: stats['pages_in_session'] as int,
        isNightSession: stats['is_night'] as bool,
        totalNotesAndHighlights: stats['total_annotations'] as int,
        totalSessions: stats['total_sessions'] as int,
      );
    }).then((unlocked) {
      if (!mounted || unlocked.isEmpty) return;
      for (final a in unlocked) {
        _showAchievementSnackBar(a);
      }
    }).catchError((_) {});
  }

  void _showAchievementSnackBar(Achievement achievement) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.military_tech, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Conquista: ${achievement.name}!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.warmGold,
        duration: const Duration(seconds: 4),
      ),
    );
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
      appBar: AppBar(leading: const DrawerButton(), title: const Text('Leitura')),
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
                  onChanged: (b) {
                    setState(() {
                      _selectedBook = b;
                      _startPageController.text =
                          b?.currentPage != null ? '${b!.currentPage}' : '';
                    });
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startPageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Página inicial'),
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
                decoration: const InputDecoration(labelText: 'Página atual'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Observações (opcional)'),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.stop),
                label: const Text('Encerrar sessão'),
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
