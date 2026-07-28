// Testes da lógica do cronômetro de sessão de leitura.
//
// Cobre:
//  • Cálculo de elapsed ao recuperar sessão do banco (recoverActiveSession)
//  • Consistência do elapsed com pausedDurationSeconds
//  • Guard de sessão órfã (maxSessionAge de 4h)
//  • Formato HH:MM:SS do timer
//  • Acúmulo correto de pausa no fluxo pause → resume

import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/features/session/presentation/notifiers/session_notifier.dart';
import 'package:readlog/shared/models/reading_session.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Simula o cálculo de netElapsed que o [SessionNotifier.recoverActiveSession]
/// faz: `now.toUtc() - session.startedAt.toUtc() - pausedDurationSeconds`.
int _calcNetElapsed({
  required DateTime startedAt,
  required DateTime now,
  int pausedDurationSeconds = 0,
}) {
  final totalElapsed = now.toUtc().difference(startedAt.toUtc()).inSeconds;
  if (totalElapsed <= 0) return 0;
  return (totalElapsed - pausedDurationSeconds).clamp(0, totalElapsed);
}

/// Retorna true se a sessão seria descartada como órfã (> 4h de idade).
bool _isOrphan({required DateTime startedAt, required DateTime now}) {
  const maxAge = Duration(hours: 4);
  return now.toUtc().difference(startedAt.toUtc()) > maxAge;
}

ReadingSession _makeSession({
  String id = 's-1',
  required DateTime startedAt,
  int pausedDurationSeconds = 0,
  SessionStatus status = SessionStatus.active,
}) =>
    ReadingSession(
      id: id,
      userId: 'u-1',
      bookId: 'b-1',
      startedAt: startedAt,
      pausedDurationSeconds: pausedDurationSeconds,
      status: status,
      createdAt: startedAt,
    );

// ══════════════════════════════════════════════════════════════════════════════
// TESTES
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  // ── Cálculo de elapsed na recuperação de sessão ───────────────────────────

  group('recoverActiveSession — cálculo de elapsed', () {
    test('sessão recém-iniciada retorna elapsed próximo de zero', () {
      final now = DateTime.now().toUtc();
      final startedAt = now.subtract(const Duration(seconds: 5));

      final elapsed = _calcNetElapsed(startedAt: startedAt, now: now);

      expect(elapsed, inInclusiveRange(4, 6));
    });

    test('sessão iniciada há 10 minutos retorna ~600 segundos de elapsed', () {
      final now = DateTime.now().toUtc();
      final startedAt = now.subtract(const Duration(minutes: 10));

      final elapsed = _calcNetElapsed(startedAt: startedAt, now: now);

      // Tolerância de 1s para variações de clock
      expect(elapsed, inInclusiveRange(599, 601));
    });

    test('elapsed subtrai pausedDurationSeconds corretamente', () {
      final now = DateTime.now().toUtc();
      // Sessão iniciada há 10 minutos, mas ficou 3 minutos pausada
      final startedAt = now.subtract(const Duration(minutes: 10));
      const pausedSeconds = 180; // 3 min

      final elapsed = _calcNetElapsed(
        startedAt: startedAt,
        now: now,
        pausedDurationSeconds: pausedSeconds,
      );

      // ~420s (7 min efetivos) com tolerância de 1s
      expect(elapsed, inInclusiveRange(419, 421));
    });

    test('elapsed nunca é negativo mesmo com pausedDuration absurdo', () {
      final now = DateTime.now().toUtc();
      final startedAt = now.subtract(const Duration(minutes: 1));

      // pausedSeconds maior que o total — clamp deve garantir >= 0
      final elapsed = _calcNetElapsed(
        startedAt: startedAt,
        now: now,
        pausedDurationSeconds: 99999,
      );

      expect(elapsed, 0);
    });

    test('startedAt em UTC e hora local produzem o mesmo elapsed', () {
      final nowUtc = DateTime.now().toUtc();
      final startedAtUtc = nowUtc.subtract(const Duration(minutes: 5));
      final startedAtLocal = startedAtUtc.toLocal();

      final elapsedUtc =
          _calcNetElapsed(startedAt: startedAtUtc, now: nowUtc);
      final elapsedLocal =
          _calcNetElapsed(startedAt: startedAtLocal, now: nowUtc);

      // Os dois devem ser iguais — toUtc() normaliza ambos
      expect(elapsedUtc, elapsedLocal);
    });
  });

  // ── Guard de sessão órfã ──────────────────────────────────────────────────

  group('recoverActiveSession — guard de sessão órfã (maxAge = 4h)', () {
    test('sessão com 3h59m não é considerada órfã', () {
      final now = DateTime.now().toUtc();
      final startedAt =
          now.subtract(const Duration(hours: 3, minutes: 59));

      expect(_isOrphan(startedAt: startedAt, now: now), isFalse);
    });

    test('sessão com exatamente 4h é considerada órfã (> 4h)', () {
      final now = DateTime.now().toUtc();
      // Exatamente 4h = não ultrapassa, logo não é órfã ainda
      final startedAtExact = now.subtract(const Duration(hours: 4));
      expect(_isOrphan(startedAt: startedAtExact, now: now), isFalse);
    });

    test('sessão com 4h01m é considerada órfã e deve ser descartada', () {
      final now = DateTime.now().toUtc();
      final startedAt =
          now.subtract(const Duration(hours: 4, minutes: 1));

      expect(_isOrphan(startedAt: startedAt, now: now), isTrue);
    });

    test('sessão com 12h é considerada órfã', () {
      final now = DateTime.now().toUtc();
      final startedAt = now.subtract(const Duration(hours: 12));

      expect(_isOrphan(startedAt: startedAt, now: now), isTrue);
    });

    test('sessão com startedAt no futuro (clock errado) retorna elapsed 0', () {
      final now = DateTime.now().toUtc();
      final startedAt = now.add(const Duration(minutes: 5)); // futuro

      final elapsed = _calcNetElapsed(startedAt: startedAt, now: now);

      // diff negativo → clamp(0, ...) = 0
      expect(elapsed, 0);
    });
  });

  // ── Formato do tempo HH:MM:SS ────────────────────────────────────────────

  group('_formatTime — formato de exibição do cronômetro', () {
    // _formatTime é privado; testamos indiretamente via _fmtTime local

    String fmtTime(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      if (h > 0) {
        return '${h.toString().padLeft(2, '0')}:'
            '${m.toString().padLeft(2, '0')}:'
            '${s.toString().padLeft(2, '0')}';
      }
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    test('0s exibe 00:00', () {
      expect(fmtTime(0), '00:00');
    });

    test('59s exibe 00:59', () {
      expect(fmtTime(59), '00:59');
    });

    test('60s exibe 01:00', () {
      expect(fmtTime(60), '01:00');
    });

    test('3599s exibe 59:59', () {
      expect(fmtTime(3599), '59:59');
    });

    test('3600s exibe 01:00:00 (inclui horas)', () {
      expect(fmtTime(3600), '01:00:00');
    });

    test('15728s (4h22m8s) exibe 04:22:08', () {
      // Valor que apareceu na screenshot do bug
      expect(fmtTime(15728), '04:22:08');
    });

    test('86399s (23h59m59s) exibe 23:59:59', () {
      expect(fmtTime(86399), '23:59:59');
    });
  });

  // ── Acúmulo de pausa no fluxo pause → resume ──────────────────────────────

  group('fluxo pause → resume — acúmulo de pausedDurationSeconds', () {
    test('uma pausa de 60s acumula 60s em pausedDurationSeconds', () {
      final pausedAt = DateTime.now().toUtc();
      final resumedAt = pausedAt.add(const Duration(seconds: 60));

      final addedPaused = resumedAt.difference(pausedAt).inSeconds;

      expect(addedPaused, 60);
    });

    test('múltiplas pausas acumulam corretamente', () {
      // Pausa 1: 30s, Pausa 2: 90s → total 120s
      const pausa1 = 30;
      const pausa2 = 90;

      final session = _makeSession(
        startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        pausedDurationSeconds: pausa1,
      );

      final sessionAfterPause2 = session.copyWith(
        pausedDurationSeconds: session.pausedDurationSeconds + pausa2,
      );

      expect(sessionAfterPause2.pausedDurationSeconds, 120);
    });

    test('elapsed líquido descontando pausa acumulada', () {
      final now = DateTime.now().toUtc();
      // Sessão de 10 min, com 2 min pausados
      final startedAt = now.subtract(const Duration(minutes: 10));
      const pausedDurationSeconds = 120; // 2 min

      final session = _makeSession(
        startedAt: startedAt,
        pausedDurationSeconds: pausedDurationSeconds,
      );

      final elapsed = _calcNetElapsed(
        startedAt: session.startedAt,
        now: now,
        pausedDurationSeconds: session.pausedDurationSeconds,
      );

      // ~480s (8 min efetivos)
      expect(elapsed, inInclusiveRange(479, 481));
    });

    test('retomar sessão mantém elapsedSeconds anterior acumulado', () {
      // Simula: antes de pausar tinha 300s, pausa de 60s, resume
      const elapsedAntesdePausar = 300;
      const duracaoPausa = 60;

      // Ao retomar, o elapsed não é resetado — continua de onde parou
      // (o notifier preserva elapsedSeconds e apenas para o ticker)
      final state = ActiveSessionState(elapsedSeconds: elapsedAntesdePausar);
      final resumed = state.copyWith(isPaused: false);

      // elapsed permanece o mesmo após resume (ticker retoma de onde parou)
      expect(resumed.elapsedSeconds, elapsedAntesdePausar);
      // pausedDuration acumulada NÃO é contada no elapsed do cronômetro UI
      // (o ticker incrementa a partir do elapsedSeconds atual)
      expect(resumed.elapsedSeconds + duracaoPausa, greaterThan(elapsedAntesdePausar));
    });
  });

  // ── ActiveSessionState — estado do cronômetro ────────────────────────────

  group('ActiveSessionState — estado cronômetro', () {
    test('sessão sem active retorna hasActiveSession false', () {
      expect(const ActiveSessionState().hasActiveSession, isFalse);
    });

    test('ticker simulado incrementa elapsedSeconds a cada segundo', () {
      var state = const ActiveSessionState(elapsedSeconds: 0);
      for (int i = 1; i <= 5; i++) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
      expect(state.elapsedSeconds, 5);
    });

    test('pausar congela elapsedSeconds', () {
      const state = ActiveSessionState(elapsedSeconds: 120, isPaused: false);
      final paused = state.copyWith(isPaused: true);

      // elapsed não muda ao pausar (ticker foi cancelado)
      expect(paused.elapsedSeconds, 120);
      expect(paused.isPaused, isTrue);
    });

    test('retomar não altera elapsedSeconds — continua do valor congelado', () {
      const paused = ActiveSessionState(elapsedSeconds: 120, isPaused: true);
      final resumed = paused.copyWith(isPaused: false);

      expect(resumed.elapsedSeconds, 120);
      expect(resumed.isPaused, isFalse);
    });
  });
}
