import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/shell/main_shell.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../achievements/data/achievement_service.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../notifiers/session_notifier.dart';
import '../widgets/book_completion_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SessionScreen
// ─────────────────────────────────────────────────────────────────────────────

class SessionScreen extends ConsumerStatefulWidget {
  final String? bookId;

  const SessionScreen({super.key, this.bookId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _startPageController = TextEditingController();
  List<Book> _readingBooks = [];
  Book? _selectedBook;
  SessionGoal _selectedGoal = SessionGoal.freeReading;
  int? _goalValue; // minutos ou número de página

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await ref
        .read(bookRepositoryProvider)
        .fetchAll(status: BookStatus.reading);
    if (!mounted) return;
    setState(() {
      _readingBooks = books;
      if (widget.bookId != null) {
        _selectedBook = books.firstWhere(
          (b) => b.id == widget.bookId,
          orElse: () => books.isNotEmpty ? books.first : books.first,
        );
      } else if (books.isNotEmpty) {
        _selectedBook = books.first;
      }
      if (_selectedBook?.currentPage != null) {
        _startPageController.text = '${_selectedBook!.currentPage}';
      }
    });
  }

  // ── Iniciar ───────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    final book = _selectedBook;
    if (book == null) return;

    final startPage = int.tryParse(_startPageController.text) ?? 0;

    await ref.read(sessionNotifierProvider.notifier).startSession(
          bookId: book.id,
          bookTitle: book.title,
          startPage: startPage,
          goal: _selectedGoal == SessionGoal.freeReading
              ? null
              : _selectedGoal,
          goalValue: _goalValue,
        );
  }

  // ── Pausar / Retomar ──────────────────────────────────────────────────────

  void _togglePause() {
    final notifier = ref.read(sessionNotifierProvider.notifier);
    if (ref.read(sessionNotifierProvider).isPaused) {
      notifier.resume();
    } else {
      notifier.pause();
    }
  }

  // ── Cancelar ──────────────────────────────────────────────────────────────

  Future<void> _cancelSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir sessão?'),
        content: const Text(
            'A sessão atual será descartada e não será salva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Sim, excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionNotifierProvider.notifier).cancelSession();
    }
  }

  // ── Finalizar (abre bottomsheet) ──────────────────────────────────────────

  void _openFinishSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FinishSessionSheet(
        session: ref.read(sessionNotifierProvider).session!,
        elapsedSeconds: ref.read(sessionNotifierProvider).elapsedSeconds,
        onSaved: _handleSessionFinished,
      ),
    );
  }

  Future<void> _handleSessionFinished(int endPage, String? notes) async {
    final session = ref.read(sessionNotifierProvider).session!;
    final elapsed = ref.read(sessionNotifierProvider).elapsedSeconds;

    final finished =
        await ref.read(sessionNotifierProvider.notifier).finishSession(
              endPage: endPage,
              notes: notes,
            );

    if (finished == null || !mounted) return;

    // Atualiza página do livro
    if (_selectedBook != null && endPage > 0) {
      await ref
          .read(bookRepositoryProvider)
          .update(_selectedBook!.id, {'current_page': endPage});
    }

    ref.read(homeRefreshTriggerProvider.notifier).state++;

    // Próxima sessão começa na página que parou
    if (endPage > 0 && mounted) {
      _startPageController.text = '$endPage';
    }

    _checkAchievements(
      startPage: session.startPage ?? 0,
      endPage: endPage,
      elapsedSeconds: elapsed,
      sessionStartedAt: session.startedAt,
    );

    // Verifica conclusão do livro
    if (_selectedBook != null &&
        _selectedBook!.totalPages != null &&
        endPage >= _selectedBook!.totalPages! &&
        _selectedBook!.status == BookStatus.reading) {
      if (mounted) _showCompleteBookDialog();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão registrada com sucesso!')),
      );
    }
  }

  // ── Concluir livro ────────────────────────────────────────────────────────

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
              await ref.read(bookRepositoryProvider).update(book.id, {
                'status': 'read',
                'end_date':
                    DateTime.now().toIso8601String().substring(0, 10),
              });
              _checkAchievements(
                startPage: 0,
                endPage: 0,
                elapsedSeconds: 0,
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
    required int startPage,
    required int endPage,
    required int elapsedSeconds,
    required DateTime sessionStartedAt,
  }) {
    final client = ref.read(supabaseClientProvider);
    final service = AchievementService(client);
    final pagesInSession = (endPage - startPage).clamp(0, 99999);
    service.collectStats(
      pagesInSession: pagesInSession,
      durationMinutes: elapsedSeconds ~/ 60,
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
    _startPageController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final isRunning = sessionState.hasActiveSession;
    final isPaused = sessionState.isPaused;
    final elapsed = sessionState.elapsedSeconds;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
          tooltip: 'Abrir menu',
        ),
        title: const Text('Leitura'),
        actions: [
          if (isRunning)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar sessão',
              onPressed: _cancelSession,
            ),
        ],
      ),
      body: isRunning
          ? _ActiveSessionView(
              sessionState: sessionState,
              elapsed: elapsed,
              isPaused: isPaused,
              onTogglePause: _togglePause,
              onFinish: _openFinishSheet,
            )
          : _StartSessionView(
              readingBooks: _readingBooks,
              selectedBook: _selectedBook,
              startPageController: _startPageController,
              selectedGoal: _selectedGoal,
              goalValue: _goalValue,
              onBookChanged: (b) => setState(() {
                _selectedBook = b;
                _startPageController.text =
                    b?.currentPage != null ? '${b!.currentPage}' : '';
              }),
              onGoalChanged: (g) => setState(() => _selectedGoal = g),
              onGoalValueChanged: (v) => setState(() => _goalValue = v),
              onStart: _selectedBook != null ? _startSession : null,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StartSessionView
// ─────────────────────────────────────────────────────────────────────────────

class _StartSessionView extends StatelessWidget {
  final List<Book> readingBooks;
  final Book? selectedBook;
  final TextEditingController startPageController;
  final SessionGoal selectedGoal;
  final int? goalValue;
  final void Function(Book?) onBookChanged;
  final void Function(SessionGoal) onGoalChanged;
  final void Function(int?) onGoalValueChanged;
  final VoidCallback? onStart;

  const _StartSessionView({
    required this.readingBooks,
    required this.selectedBook,
    required this.startPageController,
    required this.selectedGoal,
    required this.goalValue,
    required this.onBookChanged,
    required this.onGoalChanged,
    required this.onGoalValueChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Livro', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          if (readingBooks.isEmpty)
            Text(
              'Nenhum livro em leitura. Adicione um na biblioteca.',
              style: AppTextStyles.bodyMedium,
            )
          else
            DropdownButtonFormField<Book>(
              initialValue: selectedBook,
              decoration: const InputDecoration(labelText: 'Selecionar livro'),
              items: readingBooks
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.title,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onBookChanged,
            ),

          const SizedBox(height: 16),
          TextFormField(
            controller: startPageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Página inicial'),
          ),

          const SizedBox(height: 24),
          Text('Objetivo da sessão', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _GoalPicker(
            selected: selectedGoal,
            goalValue: goalValue,
            currentPage: selectedBook?.currentPage,
            totalPages: selectedBook?.totalPages,
            onGoalChanged: onGoalChanged,
            onGoalValueChanged: onGoalValueChanged,
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar leitura'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GoalPicker
// ─────────────────────────────────────────────────────────────────────────────

class _GoalPicker extends StatelessWidget {
  final SessionGoal selected;
  final int? goalValue;
  final int? currentPage;
  final int? totalPages;
  final void Function(SessionGoal) onGoalChanged;
  final void Function(int?) onGoalValueChanged;

  const _GoalPicker({
    required this.selected,
    required this.goalValue,
    required this.currentPage,
    required this.totalPages,
    required this.onGoalChanged,
    required this.onGoalValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final goals = [
      (SessionGoal.freeReading, Icons.auto_stories_outlined, 'Leitura livre'),
      (SessionGoal.byTime, Icons.timer_outlined, 'Por tempo'),
      (SessionGoal.byPage, Icons.bookmark_outlined, 'Até uma página'),
      (SessionGoal.dailyGoal, Icons.flag_outlined, 'Meta diária'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goals
              .map((g) => _GoalChip(
                    icon: g.$2,
                    label: g.$3,
                    isSelected: selected == g.$1,
                    onTap: () => onGoalChanged(g.$1),
                  ))
              .toList(),
        ),
        if (selected == SessionGoal.byTime) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: goalValue?.toString(),
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Objetivo (minutos)'),
            onChanged: (v) => onGoalValueChanged(int.tryParse(v)),
          ),
        ],
        if (selected == SessionGoal.byPage) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: goalValue?.toString() ??
                totalPages?.toString(),
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Ler até a página'),
            onChanged: (v) => onGoalValueChanged(int.tryParse(v)),
          ),
        ],
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? AppColors.forestGreen : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.forestGreen.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.forestGreen
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActiveSessionView
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveSessionView extends StatelessWidget {
  final ActiveSessionState sessionState;
  final int elapsed;
  final bool isPaused;
  final VoidCallback onTogglePause;
  final VoidCallback onFinish;

  const _ActiveSessionView({
    required this.sessionState,
    required this.elapsed,
    required this.isPaused,
    required this.onTogglePause,
    required this.onFinish,
  });

  String _formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final goal = sessionState.session?.sessionGoal;
    final goalValue = sessionState.session?.goalValue;

    // Progresso do objetivo
    double? progress;
    String? progressLabel;
    if (goal == SessionGoal.byTime && goalValue != null && goalValue > 0) {
      final done = elapsed ~/ 60;
      progress = (done / goalValue).clamp(0.0, 1.0);
      progressLabel = '$done / $goalValue min';
    } else if (goal == SessionGoal.byPage && goalValue != null && goalValue > 0) {
      progressLabel = 'Até a pág. $goalValue';
      progress = null; // sem barra pois não sabemos a página atual ainda
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            sessionState.bookTitle,
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),
          if (isPaused)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.warmGold.withValues(alpha: 0.4)),
              ),
              child: Text(
                'PAUSADO',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.warmGold,
                    fontWeight: FontWeight.w700),
              ),
            ),

          const SizedBox(height: 32),

          // Cronômetro principal
          Text(
            _formatTime(elapsed),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 64,
              fontWeight: FontWeight.w200,
              letterSpacing: -3,
              color: isPaused
                  ? AppColors.warmGold
                  : AppColors.forestGreen,
            ),
          ),

          if (sessionState.session?.startPage != null) ...[
            const SizedBox(height: 4),
            Text(
              'desde a página ${sessionState.session!.startPage}',
              style: AppTextStyles.bodyMedium,
            ),
          ],

          // Barra de progresso do objetivo
          if (progress != null || progressLabel != null) ...[
            const SizedBox(height: 24),
            _GoalProgressBar(
              progress: progress,
              label: progressLabel ?? '',
            ),
          ],

          const Spacer(),

          // Botões de ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTogglePause,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Retomar' : 'Pausar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.stop),
                  label: const Text('Finalizar'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GoalProgressBar
// ─────────────────────────────────────────────────────────────────────────────

class _GoalProgressBar extends StatelessWidget {
  final double? progress;
  final String label;

  const _GoalProgressBar({this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Objetivo', style: AppTextStyles.labelMedium),
            Text(label, style: AppTextStyles.labelMedium),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.forestGreen),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FinishSessionSheet — bottomsheet de finalização
// ─────────────────────────────────────────────────────────────────────────────

class _FinishSessionSheet extends StatefulWidget {
  final ReadingSession session;
  final int elapsedSeconds;
  final Future<void> Function(int endPage, String? notes) onSaved;

  const _FinishSessionSheet({
    required this.session,
    required this.elapsedSeconds,
    required this.onSaved,
  });

  @override
  State<_FinishSessionSheet> createState() => _FinishSessionSheetState();
}

class _FinishSessionSheetState extends State<_FinishSessionSheet> {
  final _endPageController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _endPageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _fmtTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  Future<void> _save() async {
    final endPage = int.tryParse(_endPageController.text);
    if (endPage == null || endPage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a página final.')),
      );
      return;
    }

    setState(() => _saving = true);
    Navigator.pop(context); // fecha o sheet antes de salvar
    await widget.onSaved(endPage, _notesController.text.isEmpty
        ? null
        : _notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    final startPage = widget.session.startPage ?? 0;
    final elapsed = widget.elapsedSeconds;
    final durationLabel = _fmtTime(elapsed);
    final pagesEstimate = (int.tryParse(_endPageController.text) ?? 0) -
        startPage;
    final speed = elapsed > 0 && pagesEstimate > 0
        ? (pagesEstimate / (elapsed / 60)).toStringAsFixed(2)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('Você terminou sua leitura?',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text('Página inicial: $startPage',
              style: AppTextStyles.bodyMedium),

          const SizedBox(height: 20),
          TextFormField(
            controller: _endPageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Página final'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),

          // Resumo em tempo real
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                    label: 'Tempo', value: durationLabel),
                _SummaryItem(
                    label: 'Páginas',
                    value: pagesEstimate > 0 ? '$pagesEstimate' : '—'),
                _SummaryItem(
                    label: 'Pág/min',
                    value: speed ?? '—'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Salvar sessão'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.forestGreen)),
        Text(label, style: AppTextStyles.labelMedium),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareCompletionSheet (mantido do código original)
// ─────────────────────────────────────────────────────────────────────────────

class _ShareCompletionSheet extends StatefulWidget {
  final Book book;
  final GlobalKey cardRepaintKey;
  final dynamic sessionRepository;

  const _ShareCompletionSheet({
    required this.book,
    required this.cardRepaintKey,
    required this.sessionRepository,
  });

  @override
  State<_ShareCompletionSheet> createState() =>
      _ShareCompletionSheetState();
}

class _ShareCompletionSheetState extends State<_ShareCompletionSheet> {
  int _totalMinutes = 0;
  int _totalSessions = 0;
  bool _loading = true;
  bool _sharing = false;
  final _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.sessionRepository
          .fetchBookTotalStats(widget.book.id);
      if (mounted) {
        setState(() {
          _totalMinutes = stats['total_minutes'] as int;
          _totalSessions = stats['total_sessions'] as int;
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
      final bytes = byteData.buffer.asUint8List();

      final tmpDir = await _getTmpDir();
      final file = await _writeFile('$tmpDir/readlog_share.png', bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file)],
        text: 'Acabei de terminar "${widget.book.title}" 📚',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível compartilhar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<String> _getTmpDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<String> _writeFile(String path, List<int> bytes) async {
    final file = await File(path).writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Compartilhar conquista',
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.darkTextPrimary)),
          const SizedBox(height: 4),
          Text(widget.book.title,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.darkTextSecondary)),
          const SizedBox(height: 20),

          // Card preview
          RepaintBoundary(
            key: widget.cardRepaintKey,
            child: BookCompletionCard(
              book: widget.book,
              totalMinutes: _totalMinutes,
              totalSessions: _totalSessions,
              review: _reviewController.text.isEmpty
                  ? null
                  : _reviewController.text,
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: InputDecoration(
              hintText: 'Adicione uma resenha (opcional)...',
              hintStyle:
                  const TextStyle(color: AppColors.darkTextSecondary),
              filled: true,
              fillColor: AppColors.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _shareAsImage,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              label: Text(_sharing ? 'Gerando...' : 'Compartilhar'),
            ),
          ),
        ],
      ),
    );
  }
}
