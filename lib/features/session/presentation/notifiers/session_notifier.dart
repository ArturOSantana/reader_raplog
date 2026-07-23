import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../core/services/reading_notification_service.dart';

// Duração máxima contínua sem interação antes de auto-pausar a sessão.
const _kInactivityAutoPause = Duration(hours: 4);

// Intervalo de tempo para avisar o usuário antes do auto-pause.
const _kInactivityWarning = Duration(minutes: 30);

// Intervalo de atualização da notificação persistente (bateria-friendly).
const _kNotificationThrottle = Duration(seconds: 30);

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
  Timer? _inactivityWarningTimer;
  Timer? _inactivityAutoPauseTimer;
  Timer? _notificationThrottle;

  // Quando a sessão foi pausada pela última vez (para acumular paused_seconds)
  DateTime? _pausedAt;

  // Contador de ticks desde a última atualização de notificação
  int _ticksSinceNotification = 0;

  @override
  ActiveSessionState build() {
    ref.onDispose(_cleanup);
    return const ActiveSessionState();
  }

  // ── Boot recovery ─────────────────────────────────────────────────────────

  /// Chamado pelo SessionScreen no initState para recuperar sessão interrompida.
  /// Retorna true se encontrou e restaurou uma sessão ativa.
  Future<bool> recoverActiveSession({required String bookTitle}) async {
    if (state.hasActiveSession) return true;

    final session =
        await ref.read(sessionRepositoryProvider).fetchActiveSession();
    if (session == null) return false;

    // Recalcula elapsed a partir de started_at menos pausas já acumuladas
    final now = DateTime.now();
    final totalElapsed = now.difference(session.startedAt).inSeconds;
    final netElapsed =
        (totalElapsed - session.pausedDurationSeconds).clamp(0, totalElapsed);

    state = ActiveSessionState(
      session: session,
      bookTitle: bookTitle,
      elapsedSeconds: netElapsed,
      isPaused: false,
    );

    _startTicker();
    _scheduleInactivityTimers();
    return true;
  }

  // ── Iniciar ───────────────────────────────────────────────────────────────

  Future<void> startSession({
    required String bookId,
    required String bookTitle,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    // Evita iniciar duas sessões simultâneas (guard em memória)
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
    _scheduleInactivityTimers();
  }

  // ── Pausar ────────────────────────────────────────────────────────────────

  void pause() {
    if (!state.hasActiveSession || state.isPaused) return;
    _ticker?.cancel();
    _ticker = null;
    _inactivityWarningTimer?.cancel();
    _inactivityAutoPauseTimer?.cancel();

    _pausedAt = DateTime.now();
    state = state.copyWith(isPaused: true);

    // Persiste o timestamp de pausa no SQLite imediatamente
    final session = state.session;
    if (session != null) {
      ref
          .read(sessionRepositoryProvider)
          .localRepo
          .persistPausedAt(session.id, _pausedAt!);
    }

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

    // Persiste pausa acumulada no SQLite imediatamente
    ref
        .read(sessionRepositoryProvider)
        .localRepo
        .persistResumed(updatedSession.id, addedPaused);

    state = ActiveSessionState(
      session: updatedSession,
      bookTitle: state.bookTitle,
      elapsedSeconds: state.elapsedSeconds,
      isPaused: false,
    );

    _startTicker();
    _scheduleInactivityTimers();
  }

  // ── Finalizar ─────────────────────────────────────────────────────────────

  Future<ReadingSession?> finishSession({
    required int endPage,
    String? notes,
    SessionMood? mood,
    String? miniReview,
  }) async {
    final session = state.session;
    if (session == null) return null;

    _cleanup();

    final finished = await ref.read(sessionRepositoryProvider).finishSession(
          sessionId: session.id,
          endPage: endPage,
          notes: notes,
          pausedDurationSeconds: session.pausedDurationSeconds,
          mood: mood,
          miniReview: miniReview,
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
    _ticksSinceNotification = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final newElapsed = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: newElapsed);

      // Atualiza notificação com throttle de 30s (economia de bateria)
      _ticksSinceNotification++;
      if (_ticksSinceNotification >= _kNotificationThrottle.inSeconds) {
        _ticksSinceNotification = 0;
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

  void _scheduleInactivityTimers() {
    _inactivityWarningTimer?.cancel();
    _inactivityAutoPauseTimer?.cancel();

    // Aviso em 30 min
    _inactivityWarningTimer =
        Timer(_kInactivityWarning, () {
      if (state.hasActiveSession && !state.isPaused) {
        ReadingNotificationService.instance.showInactivityAlert(
          bookTitle: state.bookTitle,
        );
      }
    });

    // Auto-pausa em 4h — sessão não fica aberta para sempre
    _inactivityAutoPauseTimer =
        Timer(_kInactivityAutoPause, () {
      if (state.hasActiveSession && !state.isPaused) {
        pause();
      }
    });
  }

  void _cleanup() {
    _ticker?.cancel();
    _ticker = null;
    _inactivityWarningTimer?.cancel();
    _inactivityWarningTimer = null;
    _inactivityAutoPauseTimer?.cancel();
    _inactivityAutoPauseTimer = null;
    _notificationThrottle?.cancel();
    _notificationThrottle = null;
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
