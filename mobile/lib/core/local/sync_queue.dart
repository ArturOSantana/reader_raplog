import 'dart:convert';
import '../local/local_database.dart';

/// Representa uma operação que ainda não foi enviada ao Supabase.
class PendingOperation {
  final int id;
  final String entity;
  final String operation; // 'insert' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingOperation({
    required this.id,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  factory PendingOperation.fromMap(Map<String, dynamic> map) =>
      PendingOperation(
        id: map['id'] as int,
        entity: map['entity'] as String,
        operation: map['operation'] as String,
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  Future<void> enqueue({
    required String entity,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDatabase.instance.db;
    await db.insert('sync_queue', {
      'entity': entity,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PendingOperation>> fetchPending() async {
    final db = await LocalDatabase.instance.db;
    final rows = await db.query('sync_queue', orderBy: 'id ASC');
    return rows.map(PendingOperation.fromMap).toList();
  }

  Future<void> remove(int id) async {
    final db = await LocalDatabase.instance.db;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await LocalDatabase.instance.db;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM sync_queue');
    return (result.first['c'] as int?) ?? 0;
  }
}
