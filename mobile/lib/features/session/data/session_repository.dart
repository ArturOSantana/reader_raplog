import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/reading_session.dart';

class SessionRepository {
  final SupabaseClient _client;

  SessionRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  Future<ReadingSession> startSession({
    required String bookId,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    final now = DateTime.now();
    final data = await _client
        .from('reading_sessions')
        .insert({
          'user_id': _userId,
          'book_id': bookId,
          'start_page': startPage,
          'started_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'status': 'active',
          'paused_duration_seconds': 0,
          if (goal != null) 'session_goal': goal.name,
          if (goalValue != null) 'goal_value': goalValue,
        })
        .select()
        .single();

    // Atualiza presença em tempo real (fire-and-forget — erro não bloqueia sessão)
    _client.rpc('update_my_presence').catchError((_) {});

    return ReadingSession.fromMap(data);
  }

  Future<ReadingSession> finishSession({
    required String sessionId,
    required int endPage,
    String? notes,
    int pausedDurationSeconds = 0,
    SessionMood? mood,
    String? miniReview,
  }) async {
    final now = DateTime.now();
    final session = await _client
        .from('reading_sessions')
        .select()
        .eq('id', sessionId)
        .single();

    final startedAt = DateTime.parse(session['started_at'] as String);
    // Duração real = total desde início - segundos pausados
    final totalSeconds = now.difference(startedAt).inSeconds;
    final netSeconds =
        (totalSeconds - pausedDurationSeconds).clamp(0, totalSeconds);
    final durationMinutes = netSeconds ~/ 60;

    final startPage = session['start_page'] as int? ?? 0;
    final pagesRead = (endPage - startPage).clamp(0, 99999);

    final data = await _client
        .from('reading_sessions')
        .update({
          'ended_at': now.toIso8601String(),
          'end_page': endPage,
          'pages_read': pagesRead,
          'duration_minutes': durationMinutes,
          'paused_duration_seconds': pausedDurationSeconds,
          'notes': notes,
          'status': 'finished',
          if (mood != null) 'mood': mood.dbValue,
          if (miniReview != null && miniReview.isNotEmpty)
            'mini_review': miniReview,
        })
        .eq('id', sessionId)
        .eq('user_id', _userId)
        .select()
        .single();

    return ReadingSession.fromMap(data);
  }

  Future<void> cancelSession({required String sessionId}) async {
    await _client
        .from('reading_sessions')
        .update({'status': 'cancelled'})
        .eq('id', sessionId)
        .eq('user_id', _userId);
  }

  Future<List<ReadingSession>> fetchByBook(String bookId) async {
    final data = await _client
        .from('reading_sessions')
        .select()
        .eq('user_id', _userId)
        .eq('book_id', bookId)
        .neq('status', 'cancelled')
        .order('started_at', ascending: false);
    return (data as List).map((e) => ReadingSession.fromMap(e)).toList();
  }

  /// Retorna {total_minutes, total_sessions} somando todas as sessões do livro.
  Future<Map<String, int>> fetchBookTotalStats(String bookId) async {
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
  }

  Future<Map<String, dynamic>> fetchDailyStats() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await _client
        .from('daily_stats')
        .select()
        .eq('user_id', _userId)
        .eq('date', today)
        .maybeSingle();
    return data ?? {'total_minutes': 0, 'total_pages': 0, 'session_count': 0};
  }

  Future<int> fetchStreak() async {
    final data = await _client
        .rpc('calculate_streak', params: {'p_user_id': _userId});
    return (data as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchHeatmap({int days = 365}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final data = await _client
        .from('daily_stats')
        .select('date, total_minutes')
        .eq('user_id', _userId)
        .gte('date', from.toIso8601String().substring(0, 10))
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
