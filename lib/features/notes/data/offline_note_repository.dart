import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/note.dart';
import '../../../core/local/sync_queue.dart';
import 'local_note_repository.dart';

/// Repositório offline-first para notas.
class OfflineNoteRepository {
  final SupabaseClient _client;
  final bool Function() _isOnline;
  final LocalNoteRepository _local = LocalNoteRepository();
  final _uuid = const Uuid();

  OfflineNoteRepository(this._client, this._isOnline);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Note>> fetchByBook(String bookId) async {
    if (_isOnline()) {
      try {
        final data = await _client
            .from('notes')
            .select()
            .eq('user_id', _userId)
            .eq('book_id', bookId)
            .order('created_at', ascending: false);
        await _local
            .upsertAll(List<Map<String, dynamic>>.from(data as List));
        return (data as List).map((e) => Note.fromMap(e)).toList();
      } catch (_) {}
    }
    return _local.fetchByBook(bookId, _userId);
  }

  Future<Note> insert({
    required String bookId,
    required NoteType type,
    required String content,
    int? pageNumber,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    final fields = {
      'id': id,
      'user_id': _userId,
      'book_id': bookId,
      'type': type.dbValue,
      'content': content,
      'page_number': pageNumber,
      'created_at': now,
      'updated_at': now,
    };

    await _local.upsert(fields);

    if (_isOnline()) {
      try {
        final data =
            await _client.from('notes').insert(fields).select().single();
        await _local.upsert(data);
        return Note.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'note',
      operation: 'insert',
      payload: fields,
    );
    return Note.fromMap(fields);
  }

  Future<Note> update(String id,
      {required String content, int? pageNumber}) async {
    final fields = {'content': content, 'page_number': pageNumber};
    await _local.update(id, fields);

    if (_isOnline()) {
      try {
        final data = await _client
            .from('notes')
            .update(fields)
            .eq('id', id)
            .eq('user_id', _userId)
            .select()
            .single();
        await _local.upsert(data);
        return Note.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'note',
      operation: 'update',
      payload: {'id': id, ...fields},
    );
    return (await _local.fetchById(id))!;
  }

  Future<void> delete(String id) async {
    await _local.markDeleted(id);

    if (_isOnline()) {
      try {
        await _client
            .from('notes')
            .delete()
            .eq('id', id)
            .eq('user_id', _userId);
        return;
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'note',
      operation: 'delete',
      payload: {'id': id},
    );
  }
}
