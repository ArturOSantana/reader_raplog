import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../../../../core/shell/main_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';
import '../../../achievements/data/achievement_service.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../widgets/book_completion_card.dart';

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
    final book = _selectedBook!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Livro concluído!'),
        content: Text(
          'Você chegou à última página de "${book.title}". Deseja marcar como lido?',
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
                book.id,
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
                _showShareBottomSheet(book.copyWith(
                  status: BookStatus.read,
                  endDate: DateTime.now(),
                ));
              }
            },
            child: const Text('Marcar como lido'),
          ),
        ],
      ),
    );
  }

  /// Chave global para capturar o card como PNG.
  final GlobalKey _cardRepaintKey = GlobalKey();

  void _showShareBottomSheet(Book completedBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShareCompletionSheet(
        book: completedBook,
        cardRepaintKey: _cardRepaintKey,
        sessionRepository: ref.read(sessionRepositoryProvider),
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
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => mainScaffoldKey.currentState?.openDrawer(), tooltip: 'Abrir menu'), title: const Text('Leitura')),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de compartilhamento após concluir o livro
// ─────────────────────────────────────────────────────────────────────────────

class _ShareCompletionSheet extends StatefulWidget {
  final Book book;
  final GlobalKey cardRepaintKey;
  final dynamic sessionRepository; // SessionRepository

  const _ShareCompletionSheet({
    required this.book,
    required this.cardRepaintKey,
    required this.sessionRepository,
  });

  @override
  State<_ShareCompletionSheet> createState() => _ShareCompletionSheetState();
}

class _ShareCompletionSheetState extends State<_ShareCompletionSheet> {
  int _totalMinutes = 0;
  int _totalSessions = 0;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.sessionRepository
          .fetchBookTotalStats(widget.book.id) as Map<String, int>;
      if (mounted) {
        setState(() {
          _totalMinutes = stats['total_minutes'] ?? 0;
          _totalSessions = stats['total_sessions'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary = widget.cardRepaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        name: 'readlog_conclusao.png',
        mimeType: 'image/png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: '📚 Acabei de ler "${widget.book.title}"'
              '${widget.book.author != null ? ' de ${widget.book.author}' : ''}'
              ' — registrado no ReadLog!',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alça
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text(
            'Compartilhar conquista',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Preview do card (capturável)
          if (_loading)
            const SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.warmGold),
              ),
            )
          else
            RepaintBoundary(
              key: widget.cardRepaintKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BookCompletionCard(
                  book: widget.book,
                  totalMinutes: _totalMinutes,
                  totalSessions: _totalSessions,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Botão compartilhar como imagem
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading || _sharing ? null : _shareAsImage,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_sharing ? 'Gerando imagem…' : 'Compartilhar imagem'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmGold,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Fechar
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkTextSecondary,
              ),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }
}
