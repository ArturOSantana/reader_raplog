import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/reading_session.dart';
import '../../../core/local/sync_queue.dart';
import 'local_session_repository.dart';

/// Repositório offline-first para sessões de leitura.
class OfflineSessionRepository {
  final SupabaseClient _client;
  final bool Function() _isOnline;
  final LocalSessionRepository _local = LocalSessionRepository();
  final _uuid = const Uuid();

  OfflineSessionRepository(this._client, this._isOnline);

  String get _userId => _client.auth.currentUser!.id;

  // ── Start / Finish / Cancel ───────────────────────────────────────────────

  Future<ReadingSession> startSession({
    required String bookId,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final fields = {
      'id': id,
      'user_id': _userId,
      'book_id': bookId,
      'start_page': startPage,
      'started_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'status': 'active',
      'paused_duration_seconds': 0,
      if (goal != null) 'session_goal': goal.name,
      if (goalValue != null) 'goal_value': goalValue,
    };

    await _local.insert(fields);

    if (_isOnline()) {
      try {
        final data = await _client
            .from('reading_sessions')
            .insert(fields)
            .select()
            .single();
        await _local.insert(data);
        return ReadingSession.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'session',
      operation: 'insert',
      payload: fields,
    );
    return ReadingSession.fromMap(fields);
  }

  Future<ReadingSession> finishSession({
    required String sessionId,
    required int endPage,
    String? notes,
    int pausedDurationSeconds = 0,
  }) async {
    final now = DateTime.now();

    final localSession = await _local.fetchById(sessionId);
    final startedAt = localSession?.startedAt ?? now;

    final totalSeconds = now.difference(startedAt).inSeconds;
    final netSeconds =
        (totalSeconds - pausedDurationSeconds).clamp(0, totalSeconds);
    final durationMinutes = netSeconds ~/ 60;

    final startPage = localSession?.startPage ?? 0;
    final pagesRead = (endPage - startPage).clamp(0, 99999);

    final updateFields = {
      'ended_at': now.toIso8601String(),
      'end_page': endPage,
      'pages_read': pagesRead,
      'duration_minutes': durationMinutes,
      'paused_duration_seconds': pausedDurationSeconds,
      'notes': notes,
      'status': 'finished',
    };

    await _local.update(sessionId, updateFields);

    if (_isOnline()) {
      try {
        final data = await _client
            .from('reading_sessions')
            .update(updateFields)
            .eq('id', sessionId)
            .eq('user_id', _userId)
            .select()
            .single();
        await _local.update(sessionId, data);
        return ReadingSession.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'session',
      operation: 'update',
      payload: {'id': sessionId, ...updateFields},
    );
    return (await _local.fetchById(sessionId))!;
  }

  Future<void> cancelSession({required String sessionId}) async {
    await _local.update(sessionId, {'status': 'cancelled'});

    if (_isOnline()) {
      try {
        await _client
            .from('reading_sessions')
            .update({'status': 'cancelled'})
            .eq('id', sessionId)
            .eq('user_id', _userId);
        return;
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'session',
      operation: 'update',
      payload: {'id': sessionId, 'status': 'cancelled'},
    );
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<List<ReadingSession>> fetchByBook(String bookId) async {
    if (_isOnline()) {
      try {
        final data = await _client
            .from('reading_sessions')
            .select()
            .eq('user_id', _userId)
            .eq('book_id', bookId)
            .neq('status', 'cancelled')
            .order('started_at', ascending: false);
        await _local
            .upsertAll(List<Map<String, dynamic>>.from(data as List));
        return (data as List)
            .map((e) => ReadingSession.fromMap(e))
            .toList();
      } catch (_) {}
    }
    return _local.fetchByBook(bookId);
  }

  Future<Map<String, dynamic>> fetchDailyStats() async {
    if (_isOnline()) {
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final data = await _client
            .from('daily_stats')
            .select()
            .eq('user_id', _userId)
            .eq('date', today)
            .maybeSingle();
        final result = data ??
            {'total_minutes': 0, 'total_pages': 0, 'session_count': 0};

        await _local.upsertDailyStats(
          userId: _userId,
          date: today,
          totalMinutes: result['total_minutes'] as int,
          totalPages: result['total_pages'] as int,
          sessionCount: result['session_count'] as int,
        );
        return result;
      } catch (_) {}
    }
    return _local.fetchDailyStats(_userId);
  }

  Future<int> fetchStreak() async {
    if (_isOnline()) {
      try {
        final data = await _client
            .rpc('calculate_streak', params: {'p_user_id': _userId});
        return (data as int?) ?? 0;
      } catch (_) {}
    }
    return _local.fetchStreak(_userId);
  }

  Future<Map<String, dynamic>> fetchPeriodStats({required String period}) async {
    final now = DateTime.now();
    String fromDate;
    switch (period) {
      case 'week':
        fromDate = now
            .subtract(Duration(days: now.weekday - 1))
            .toIso8601String()
            .substring(0, 10);
        break;
      case 'month':
        fromDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        break;
      case 'year':
        fromDate = '${now.year}-01-01';
        break;
      default:
        fromDate = now.toIso8601String().substring(0, 10);
    }

    if (_isOnline()) {
      try {
        final data = await _client
            .from('daily_stats')
            .select()
            .eq('user_id', _userId)
            .gte('date', fromDate);

        int totalMinutes = 0;
        int totalPages = 0;
        for (final row in (data as List)) {
          totalMinutes += (row['total_minutes'] as num?)?.toInt() ?? 0;
          totalPages += (row['total_pages'] as num?)?.toInt() ?? 0;
        }
        return {'total_minutes': totalMinutes, 'total_pages': totalPages};
      } catch (_) {}
    }
    return _local.fetchPeriodStats(_userId, fromDate);
  }

  /// Retorna {total_minutes, total_sessions} somando todas as sessões do livro.
  Future<Map<String, int>> fetchBookTotalStats(String bookId) async {
    if (_isOnline()) {
      try {
        final data = await _client
            .from('reading_sessions')
            .select('duration_minutes')
            .eq('user_id', _userId)
            .eq('book_id', bookId)
            .eq('status', 'finished');
        final list = data as List;
        int totalMinutes = 0;
        for (final row in list) {
          totalMinutes += (row['duration_minutes'] as int? ?? 0);
        }
        return {'total_minutes': totalMinutes, 'total_sessions': list.length};
      } catch (_) {}
    }
    final sessions = await _local.fetchByBook(bookId);
    int totalMinutes = 0;
    int count = 0;
    for (final s in sessions) {
      if (s.status == SessionStatus.finished && s.durationMinutes != null) {
        totalMinutes += s.durationMinutes!;
        count++;
      }
    }
    return {'total_minutes': totalMinutes, 'total_sessions': count};
  }

  Future<List<Map<String, dynamic>>> fetchHeatmap({int days = 365}) async {
    if (_isOnline()) {
      try {
        final from = DateTime.now().subtract(Duration(days: days));
        final data = await _client
            .from('daily_stats')
            .select('date, total_minutes')
            .eq('user_id', _userId)
            .gte('date', from.toIso8601String().substring(0, 10))
            .order('date', ascending: true);
        return List<Map<String, dynamic>>.from(data as List);
      } catch (_) {}
    }
    return _local.fetchHeatmap(_userId, days);
  }
}
