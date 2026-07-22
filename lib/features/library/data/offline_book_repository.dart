import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/book.dart';
import '../../../core/local/sync_queue.dart';
import 'local_book_repository.dart';

/// Repositório offline-first para livros.
///
/// Quando online: lê/escreve no Supabase e mantém o cache local atualizado.
/// Quando offline: lê/escreve apenas no SQLite e enfileira para sincronização.
class OfflineBookRepository {
  final SupabaseClient _client;
  final bool Function() _isOnline;
  final LocalBookRepository _local = LocalBookRepository();
  final _uuid = const Uuid();

  OfflineBookRepository(this._client, this._isOnline);

  String get _userId => _client.auth.currentUser!.id;

  // ── Fetch ────────────────────────────────────────────────────────────────

  Future<List<Book>> fetchAll({BookStatus? status}) async {
    if (_isOnline()) {
      try {
        var query = _client
            .from('books')
            .select()
            .eq('user_id', _userId)
            .order('updated_at', ascending: false);

        if (status != null) {
          query = _client
              .from('books')
              .select()
              .eq('user_id', _userId)
              .eq('status', status.dbValue)
              .order('updated_at', ascending: false);
        }

        final data = await query;
        await _local.upsertAll(
            List<Map<String, dynamic>>.from(data as List));
        return (data as List).map((e) => Book.fromMap(e)).toList();
      } catch (_) {
        // Sem rede — usa cache
      }
    }
    return _local.fetchAll(status: status);
  }

  Future<Book?> fetchById(String id) async {
    if (_isOnline()) {
      try {
        final data = await _client
            .from('books')
            .select()
            .eq('id', id)
            .eq('user_id', _userId)
            .single();
        await _local.upsert(data);
        return Book.fromMap(data);
      } catch (_) {}
    }
    return _local.fetchById(id);
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<Book> insert(Map<String, dynamic> fields) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    final full = {
      ...fields,
      'id': id,
      'user_id': _userId,
      'created_at': now,
      'updated_at': now,
    };

    // Persiste localmente primeiro (otimistic)
    await _local.upsert(full);

    if (_isOnline()) {
      try {
        final data =
            await _client.from('books').insert(full).select().single();
        await _local.upsert(data);
        return Book.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'book',
      operation: 'insert',
      payload: full,
    );
    return Book.fromMap(full);
  }

  Future<Book> update(String id, Map<String, dynamic> fields) async {
    await _local.update(id, fields);

    if (_isOnline()) {
      try {
        final data = await _client
            .from('books')
            .update(fields)
            .eq('id', id)
            .eq('user_id', _userId)
            .select()
            .single();
        await _local.upsert(data);
        return Book.fromMap(data);
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'book',
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
            .from('books')
            .delete()
            .eq('id', id)
            .eq('user_id', _userId);
        return;
      } catch (_) {}
    }

    await SyncQueue.instance.enqueue(
      entity: 'book',
      operation: 'delete',
      payload: {'id': id},
    );
  }
}
