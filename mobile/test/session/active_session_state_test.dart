import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/session/presentation/notifiers/session_notifier.dart';
import 'package:lumen/shared/models/reading_session.dart';

void main() {
  // ── ActiveSessionState ─────────────────────────────────────────────────────

  group('ActiveSessionState', () {
    test('hasActiveSession é false quando session é null', () {
      const state = ActiveSessionState();
      expect(state.hasActiveSession, isFalse);
    });

    test('hasActiveSession é true quando session está definida', () {
      final session = ReadingSession(
        id: 's-1',
        userId: 'u-1',
        bookId: 'b-1',
        startedAt: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 6, 1),
      );
      final state = ActiveSessionState(session: session);
      expect(state.hasActiveSession, isTrue);
    });

    test('estado inicial tem elapsedSeconds = 0 e isPaused = false', () {
      const state = ActiveSessionState();
      expect(state.elapsedSeconds, 0);
      expect(state.isPaused, isFalse);
      expect(state.bookTitle, '');
    });

    test('copyWith altera apenas os campos passados', () {
      final session = ReadingSession(
        id: 's-1',
        userId: 'u-1',
        bookId: 'b-1',
        startedAt: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 6, 1),
      );
      final base = ActiveSessionState(
        session: session,
        bookTitle: 'Dom Casmurro',
        elapsedSeconds: 120,
        isPaused: false,
      );
      final updated = base.copyWith(isPaused: true, elapsedSeconds: 150);
      expect(updated.isPaused, isTrue);
      expect(updated.elapsedSeconds, 150);
      expect(updated.bookTitle, 'Dom Casmurro'); // não alterado
      expect(updated.session, same(session)); // não alterado
    });
  });

  // ── SessionNotifier (lógica de pause/resume em memória) ─────────────────

  group('SessionNotifier._formatTime (via método estático interno)', () {
    // Como _formatTime é private, testamos indiretamente via elapsedSeconds
    // para verificar que o estado é incrementado corretamente pelo copyWith.

    test('copyWith de estado com elapsedSeconds acumula corretamente', () {
      const state = ActiveSessionState(elapsedSeconds: 59);
      final updated = state.copyWith(elapsedSeconds: 60);
      expect(updated.elapsedSeconds, 60);
    });

    test('copyWith preserva todos os outros campos quando só elapsedSeconds muda', () {
      const state = ActiveSessionState(
        bookTitle: 'Título do Livro',
        elapsedSeconds: 0,
        isPaused: false,
      );
      final updated = state.copyWith(elapsedSeconds: 100);
      expect(updated.bookTitle, 'Título do Livro');
      expect(updated.isPaused, isFalse);
    });
  });

  // ── ActiveSessionState múltiplos copyWith ─────────────────────────────────

  group('ActiveSessionState fluxo pause/resume simulado', () {
    test('transição active → paused altera isPaused', () {
      const active = ActiveSessionState(
        bookTitle: 'Meu livro',
        elapsedSeconds: 300,
        isPaused: false,
      );
      final paused = active.copyWith(isPaused: true);
      expect(paused.isPaused, isTrue);
      expect(paused.elapsedSeconds, 300);
    });

    test('transição paused → resumed altera isPaused de volta para false', () {
      const paused = ActiveSessionState(
        bookTitle: 'Meu livro',
        elapsedSeconds: 300,
        isPaused: true,
      );
      final resumed = paused.copyWith(isPaused: false);
      expect(resumed.isPaused, isFalse);
    });
  });
}
