import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/note.dart';

class NoteRepository {
  final SupabaseClient _client;

  NoteRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Note>> fetchByBook(String bookId) async {
    final data = await _client
        .from('notes')
        .select()
        .eq('user_id', _userId)
        .eq('book_id', bookId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Note.fromMap(e)).toList();
  }

  Future<Note> insert({
    required String bookId,
    required NoteType type,
    required String content,
    int? pageNumber,
  }) async {
    final data = await _client
        .from('notes')
        .insert({
          'user_id': _userId,
          'book_id': bookId,
          'type': type.dbValue,
          'content': content,
          'page_number': pageNumber,
        })
        .select()
        .single();
    return Note.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _client
        .from('notes')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<Note> update(String id, {required String content, int? pageNumber}) async {
    final data = await _client
        .from('notes')
        .update({'content': content, 'page_number': pageNumber})
        .eq('id', id)
        .eq('user_id', _userId)
        .select()
        .single();
    return Note.fromMap(data);
  }
}
