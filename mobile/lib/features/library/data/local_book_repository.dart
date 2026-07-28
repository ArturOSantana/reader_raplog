import 'package:sqflite/sqflite.dart';
import '../../../shared/models/book.dart';
import '../../../core/local/local_database.dart';

class LocalBookRepository {
  Future<List<Book>> fetchAll(String userId, {BookStatus? status}) async {
    final db = await LocalDatabase.instance.db;
    final conditions = ['user_id = ?', 'is_deleted = 0'];
    final args = <Object>[userId];
    if (status != null) {
      conditions.add('status = ?');
      args.add(status.dbValue);
    }
    final rows = await db.query(
      'books',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> fetchBySourceClub(String userId, String clubId) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'books',
      where: 'user_id = ? AND source_club_id = ? AND is_deleted = 0',
      whereArgs: [userId, clubId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<Book?> fetchById(String id) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'books',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<void> upsert(Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.insert(
      'books',
      {...fields, 'is_deleted': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    final db = await LocalDatabase.instance.db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'books',
        {...row, 'is_deleted': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.update(
      'books',
      {...fields, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDeleted(String id) async {
    final db = await LocalDatabase.instance.db;
    await db.update(
      'books',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
