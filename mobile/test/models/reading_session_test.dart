import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/shared/models/reading_session.dart';

void main() {
  final now = DateTime(2024, 6, 1, 10, 0, 0);

  ReadingSession makeSession({
    SessionStatus status = SessionStatus.active,
    int pausedSeconds = 0,
    SessionGoal? goal,
    int? goalValue,
  }) =>
      ReadingSession(
        id: 'session-1',
        userId: 'user-1',
        bookId: 'book-1',
        startedAt: now,
        status: status,
        pausedDurationSeconds: pausedSeconds,
        sessionGoal: goal,
        goalValue: goalValue,
        createdAt: now,
      );

  // ── SessionStatus / SessionGoal enums ────────────────────────────────────

  group('SessionStatus', () {
    test('contém os três estados esperados', () {
      expect(SessionStatus.values.length, 3);
      expect(SessionStatus.values, containsAll([
        SessionStatus.active,
        SessionStatus.paused,
        SessionStatus.finished,
      ]));
    });
  });

  group('SessionGoal', () {
    test('contém os quatro objetivos esperados', () {
      expect(SessionGoal.values.length, 4);
      expect(SessionGoal.values, containsAll([
        SessionGoal.byTime,
        SessionGoal.byPage,
        SessionGoal.dailyGoal,
        SessionGoal.freeReading,
      ]));
    });
  });

  // ── ReadingSession.fromMap ────────────────────────────────────────────────

  group('ReadingSession.fromMap', () {
    final map = {
      'id': 'session-1',
      'user_id': 'user-1',
      'book_id': 'book-1',
      'started_at': '2024-06-01T10:00:00.000Z',
      'ended_at': '2024-06-01T11:00:00.000Z',
      'duration_minutes': 60,
      'paused_duration_seconds': 120,
      'start_page': 50,
      'end_page': 80,
      'pages_read': 30,
      'notes': 'Ótima sessão',
      'status': 'finished',
      'session_goal': 'byTime',
      'goal_value': 60,
      'created_at': '2024-06-01T10:00:00.000Z',
    };

    test('faz parse de todos os campos corretamente', () {
      final s = ReadingSession.fromMap(map);
      expect(s.id, 'session-1');
      expect(s.userId, 'user-1');
      expect(s.bookId, 'book-1');
      expect(s.durationMinutes, 60);
      expect(s.pausedDurationSeconds, 120);
      expect(s.startPage, 50);
      expect(s.endPage, 80);
      expect(s.pagesRead, 30);
      expect(s.notes, 'Ótima sessão');
      expect(s.status, SessionStatus.finished);
      expect(s.sessionGoal, SessionGoal.byTime);
      expect(s.goalValue, 60);
      expect(s.endedAt, isNotNull);
    });

    test('usa SessionStatus.active como fallback quando status é desconhecido', () {
      final m = Map<String, dynamic>.from(map);
      m['status'] = 'invalid_status';
      expect(ReadingSession.fromMap(m).status, SessionStatus.active);
    });

    test('usa SessionGoal.freeReading como fallback quando goal é desconhecido', () {
      final m = Map<String, dynamic>.from(map);
      m['session_goal'] = 'unknown_goal';
      expect(ReadingSession.fromMap(m).sessionGoal, SessionGoal.freeReading);
    });

    test('aceita session_goal nulo', () {
      final m = Map<String, dynamic>.from(map);
      m['session_goal'] = null;
      expect(ReadingSession.fromMap(m).sessionGoal, isNull);
    });

    test('aceita campos opcionais nulos', () {
      final sparse = {
        'id': 's-1',
        'user_id': 'u-1',
        'book_id': 'b-1',
        'started_at': '2024-06-01T10:00:00.000Z',
        'ended_at': null,
        'duration_minutes': null,
        'paused_duration_seconds': null,
        'start_page': null,
        'end_page': null,
        'pages_read': null,
        'notes': null,
        'status': null,
        'session_goal': null,
        'goal_value': null,
        'created_at': '2024-06-01T10:00:00.000Z',
      };
      final s = ReadingSession.fromMap(sparse);
      expect(s.endedAt, isNull);
      expect(s.durationMinutes, isNull);
      expect(s.pausedDurationSeconds, 0); // default
    });
  });

  // ── ReadingSession.toMap ──────────────────────────────────────────────────

  group('ReadingSession.toMap', () {
    test('serializa o status como string', () {
      final s = makeSession(status: SessionStatus.paused);
      expect(s.toMap()['status'], 'paused');
    });

    test('serializa o sessionGoal como string', () {
      final s = makeSession(goal: SessionGoal.byPage, goalValue: 100);
      expect(s.toMap()['session_goal'], 'byPage');
      expect(s.toMap()['goal_value'], 100);
    });

    test('sessionGoal nulo serializa como nulo', () {
      final s = makeSession();
      expect(s.toMap()['session_goal'], isNull);
    });
  });

  // ── ReadingSession.copyWith ───────────────────────────────────────────────

  group('ReadingSession.copyWith', () {
    test('somente os campos passados são alterados', () {
      final original = makeSession(pausedSeconds: 30);
      final updated = original.copyWith(
        status: SessionStatus.finished,
        durationMinutes: 45,
        endPage: 90,
      );
      expect(updated.status, SessionStatus.finished);
      expect(updated.durationMinutes, 45);
      expect(updated.endPage, 90);
      // campos não alterados
      expect(updated.id, original.id);
      expect(updated.pausedDurationSeconds, 30);
    });
  });
}
