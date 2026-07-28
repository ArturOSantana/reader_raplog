import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/book.dart';

class BookRepository {
  final SupabaseClient _client;

  BookRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  Future<List<Book>> fetchAll({BookStatus? status}) async {
    final userId = _userId;
    final query = _client
        .from('books')
        .select()
        .eq('user_id', userId);

    if (status != null) {
      query.eq('status', status.dbValue);
    }

    final data = await query.order('updated_at', ascending: false);
    return (data as List).map((e) => Book.fromMap(e)).toList();
  }

  Future<Book> fetchById(String id) async {
    final data = await _client
        .from('books')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .single();
    return Book.fromMap(data);
  }

  Future<Book> insert(Map<String, dynamic> fields) async {
    final data = await _client
        .from('books')
        .insert({...fields, 'user_id': _userId})
        .select()
        .single();
    return Book.fromMap(data);
  }

  Future<Book> update(String id, Map<String, dynamic> fields) async {
    final data = await _client
        .from('books')
        .update(fields)
        .eq('id', id)
        .eq('user_id', _userId)
        .select()
        .single();
    return Book.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _client
        .from('books')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
