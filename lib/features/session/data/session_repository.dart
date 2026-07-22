import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/reading_session.dart';

class SessionRepository {
  final SupabaseClient _client;

  SessionRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<ReadingSession> startSession({
    required String bookId,
    required int startPage,
  }) async {
    final data = await _client
        .from('reading_sessions')
        .insert({
          'user_id': _userId,
          'book_id': bookId,
          'start_page': startPage,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return ReadingSession.fromMap(data);
  }

  Future<ReadingSession> finishSession({
    required String sessionId,
    required int endPage,
    String? notes,
  }) async {
    final now = DateTime.now();
    final session = await _client
        .from('reading_sessions')
        .select()
        .eq('id', sessionId)
        .single();

    final startedAt = DateTime.parse(session['started_at'] as String);
    final durationMinutes = now.difference(startedAt).inMinutes;

    final data = await _client
        .from('reading_sessions')
        .update({
          'ended_at': now.toIso8601String(),
          'end_page': endPage,
          'duration_minutes': durationMinutes,
          'notes': notes,
        })
        .eq('id', sessionId)
        .eq('user_id', _userId)
        .select()
        .single();

    return ReadingSession.fromMap(data);
  }

  Future<List<ReadingSession>> fetchByBook(String bookId) async {
    final data = await _client
        .from('reading_sessions')
        .select()
        .eq('user_id', _userId)
        .eq('book_id', bookId)
        .order('started_at', ascending: false);
    return (data as List).map((e) => ReadingSession.fromMap(e)).toList();
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
    final data = await _client.rpc('calculate_streak', params: {'p_user_id': _userId});
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
