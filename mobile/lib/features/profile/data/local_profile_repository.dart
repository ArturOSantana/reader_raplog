import 'package:sqflite/sqflite.dart';
import '../../../shared/models/user_profile.dart';
import '../../../core/local/local_database.dart';

class LocalProfileRepository {
  Future<UserProfile?> fetch(String userId) async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query(
      'profile',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> upsert(Map<String, dynamic> fields) async {
    final db = await LocalDatabase.instance.db;
    await db.insert(
      'profile',
      fields,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
