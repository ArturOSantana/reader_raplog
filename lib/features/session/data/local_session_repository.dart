import 'package:sqflite/sqflite.dart';
import '../../../shared/models/reading_session.dart';
import '../../../core/local/local_database.dart';

class LocalSessionRepository {
  Future<void> insert(Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.insert(
      'reading_sessions',
      fields,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.update(
      'reading_sessions',
      fields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ReadingSession?> fetchById(String id) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'reading_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReadingSession.fromMap(rows.first);
  }

  Future<List<ReadingSession>> fetchByBook(String bookId) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'reading_sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'started_at DESC',
    );
    return rows.map(ReadingSession.fromMap).toList();
  }

  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    final db = await LocalDatabase.instance.db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'reading_sessions',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Stats calculadas localmente (sem RPC)
  Future<Map<String, dynamic>> fetchDailyStats(String userId) async {
    final db = await LocalDatabase.instance.db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Primeiro tenta a cache
    final cached = await db.query(
      'daily_stats_cache',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
      limit: 1,
    );
    if (cached.isNotEmpty) {
      return Map<String, dynamic>.from(cached.first);
    }

    // Calcula a partir das sessões locais do dia
    final rows = await db.query(
      'reading_sessions',
      where: 'user_id = ? AND started_at LIKE ?',
      whereArgs: [userId, '$today%'],
    );

    int totalMinutes = 0;
    int totalPages = 0;
    for (final row in rows) {
      totalMinutes += (row['duration_minutes'] as int?) ?? 0;
      final start = (row['start_page'] as int?) ?? 0;
      final end = (row['end_page'] as int?) ?? 0;
      if (end > start) totalPages += end - start;
    }

    return {
      'total_minutes': totalMinutes,
      'total_pages': totalPages,
      'session_count': rows.length,
    };
  }

  Future<void> upsertDailyStats({
    required String userId,
    required String date,
    required int totalMinutes,
    required int totalPages,
    required int sessionCount,
  }) async {
    final db = await LocalDatabase.instance.db;
    await db.insert(
      'daily_stats_cache',
      {
        'user_id': userId,
        'date': date,
        'total_minutes': totalMinutes,
        'total_pages': totalPages,
        'session_count': sessionCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> fetchHeatmap(
      String userId, int days) async {
    final db = await LocalDatabase.instance.db;
    final from = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final cached = await db.query(
      'daily_stats_cache',
      columns: ['date', 'total_minutes'],
      where: 'user_id = ? AND date >= ?',
      whereArgs: [userId, from],
      orderBy: 'date ASC',
    );

    if (cached.isNotEmpty) {
      return List<Map<String, dynamic>>.from(cached);
    }

    // Fallback: agrega sessões locais por dia
    final rows = await db.rawQuery('''
      SELECT
        substr(started_at, 1, 10) AS date,
        SUM(duration_minutes) AS total_minutes
      FROM reading_sessions
      WHERE user_id = ? AND started_at >= ?
      GROUP BY substr(started_at, 1, 10)
      ORDER BY date ASC
    ''', [userId, from]);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> fetchPeriodStats(
      String userId, String fromDate) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'reading_sessions',
      where: 'user_id = ? AND started_at >= ?',
      whereArgs: [userId, fromDate],
    );
    int totalMinutes = 0;
    int totalPages = 0;
    for (final row in rows) {
      totalMinutes += (row['duration_minutes'] as int?) ?? 0;
      final start = (row['start_page'] as int?) ?? 0;
      final end = (row['end_page'] as int?) ?? 0;
      if (end > start) totalPages += end - start;
    }
    return {'total_minutes': totalMinutes, 'total_pages': totalPages};
  }

  Future<int> fetchStreak(String userId) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT substr(started_at, 1, 10) AS date
      FROM reading_sessions
      WHERE user_id = ?
      ORDER BY date DESC
    ''', [userId]);

    if (rows.isEmpty) return 0;

    int streak = 0;
    DateTime cursor = DateTime.now();

    for (final row in rows) {
      final date = DateTime.parse(row['date'] as String);
      final diff = cursor.difference(date).inDays;
      if (diff <= 1) {
        streak++;
        cursor = date;
      } else {
        break;
      }
    }
    return streak;
  }
}
