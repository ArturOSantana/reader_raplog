import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../core/services/reading_notification_service.dart';

/// Estado imutável que a UI consome.
class ActiveSessionState {
  final ReadingSession? session;
  final String bookTitle;
  final int elapsedSeconds;
  final bool isPaused;

  const ActiveSessionState({
    this.session,
    this.bookTitle = '',
    this.elapsedSeconds = 0,
    this.isPaused = false,
  });

  bool get hasActiveSession => session != null;

  ActiveSessionState copyWith({
    ReadingSession? session,
    String? bookTitle,
    int? elapsedSeconds,
    bool? isPaused,
  }) =>
      ActiveSessionState(
        session: session ?? this.session,
        bookTitle: bookTitle ?? this.bookTitle,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        isPaused: isPaused ?? this.isPaused,
      );
}

/// Notifier global que sobrevive à navegação entre abas.
/// O [Timer] vive aqui — não no widget — então não é cancelado pelo dispose.
class SessionNotifier extends Notifier<ActiveSessionState> {
  Timer? _ticker;
  Timer? _inactivityTimer;

  // Quando a sessão foi pausada pela última vez (para acumular paused_seconds)
  DateTime? _pausedAt;

  @override
  ActiveSessionState build() {
    ref.onDispose(_cleanup);
    return const ActiveSessionState();
  }

  // ── Iniciar ───────────────────────────────────────────────────────────────

  Future<void> startSession({
    required String bookId,
    required String bookTitle,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    // Evita iniciar duas sessões simultâneas
    if (state.hasActiveSession) return;

    final session = await ref.read(sessionRepositoryProvider).startSession(
          bookId: bookId,
          startPage: startPage,
          goal: goal,
          goalValue: goalValue,
        );

    state = ActiveSessionState(
      session: session,
      bookTitle: bookTitle,
      elapsedSeconds: 0,
    );
    _startTicker();
    _scheduleInactivityReminder();
  }

  // ── Pausar ────────────────────────────────────────────────────────────────

  void pause() {
    if (!state.hasActiveSession || state.isPaused) return;
    _ticker?.cancel();
    _inactivityTimer?.cancel();
    _pausedAt = DateTime.now();
    state = state.copyWith(isPaused: true);

    ReadingNotificationService.instance.showPaused(
      bookTitle: state.bookTitle,
      elapsed: _formatTime(state.elapsedSeconds),
    );
  }

  void resume() {
    if (!state.hasActiveSession || !state.isPaused) return;

    // Acumula segundos pausados
    int addedPaused = 0;
    if (_pausedAt != null) {
      addedPaused = DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }

    final updatedSession = state.session!.copyWith(
      pausedDurationSeconds:
          state.session!.pausedDurationSeconds + addedPaused,
    );

    state = ActiveSessionState(
      session: updatedSession,
      bookTitle: state.bookTitle,
      elapsedSeconds: state.elapsedSeconds,
      isPaused: false,
    );

    _startTicker();
    _scheduleInactivityReminder();
  }

  // ── Finalizar ─────────────────────────────────────────────────────────────

  Future<ReadingSession?> finishSession({
    required int endPage,
    String? notes,
  }) async {
    final session = state.session;
    if (session == null) return null;

    _cleanup();

    final finished = await ref.read(sessionRepositoryProvider).finishSession(
          sessionId: session.id,
          endPage: endPage,
          notes: notes,
          pausedDurationSeconds: session.pausedDurationSeconds,
        );

    state = const ActiveSessionState();
    return finished;
  }

  // ── Cancelar ──────────────────────────────────────────────────────────────

  Future<void> cancelSession() async {
    final session = state.session;
    if (session == null) return;

    _cleanup();

    await ref
        .read(sessionRepositoryProvider)
        .cancelSession(sessionId: session.id);

    state = const ActiveSessionState();
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final newElapsed = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: newElapsed);

      // Atualiza a notificação a cada minuto
      if (newElapsed % 60 == 0) {
        ReadingNotificationService.instance.show(
          bookTitle: state.bookTitle,
          elapsed: _formatTime(newElapsed),
        );
      }
    });

    // Exibe imediatamente ao iniciar/retomar
    ReadingNotificationService.instance.show(
      bookTitle: state.bookTitle,
      elapsed: _formatTime(state.elapsedSeconds),
    );
  }

  void _scheduleInactivityReminder() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 30), () {
      if (state.hasActiveSession && !state.isPaused) {
        ReadingNotificationService.instance.showInactivityAlert(
          bookTitle: state.bookTitle,
        );
      }
    });
  }

  void _cleanup() {
    _ticker?.cancel();
    _ticker = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    ReadingNotificationService.instance.dismiss();
  }

  static String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Provider global — o notifier vive enquanto o app estiver em memória,
/// sobrevivendo à navegação entre abas.
final sessionNotifierProvider =
    NotifierProvider<SessionNotifier, ActiveSessionState>(
  SessionNotifier.new,
);
