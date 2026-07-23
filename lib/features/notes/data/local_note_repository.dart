import 'package:sqflite/sqflite.dart';
import '../../../shared/models/note.dart';
import '../../../core/local/local_database.dart';

class LocalNoteRepository {
  Future<Note?> fetchById(String id) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'notes',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> fetchByBook(String bookId, String userId) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'notes',
      where: 'book_id = ? AND user_id = ? AND is_deleted = 0',
      whereArgs: [bookId, userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<void> upsert(Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.insert(
      'notes',
      {...fields, 'is_deleted': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    final db = await LocalDatabase.instance.db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'notes',
        {...row, 'is_deleted': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.update(
      'notes',
      {...fields, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDeleted(String id) async {
    final db = await LocalDatabase.instance.db;
    await db.update(
      'notes',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
