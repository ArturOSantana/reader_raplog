import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/highlight.dart';

class HighlightRepository {
  final SupabaseClient _client;

  HighlightRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  Future<List<Highlight>> fetchByBook(String bookId) async {
    final data = await _client
        .from('highlights')
        .select()
        .eq('user_id', _userId)
        .eq('book_id', bookId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Highlight.fromMap(e)).toList();
  }

  Future<Highlight> insert({
    required String bookId,
    required String text,
    int? pageNumber,
  }) async {
    final data = await _client
        .from('highlights')
        .insert({
          'user_id': _userId,
          'book_id': bookId,
          'text': text,
          'page_number': pageNumber,
        })
        .select()
        .single();
    return Highlight.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _client
        .from('highlights')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<int> countAll() async {
    final data = await _client
        .from('highlights')
        .select('id')
        .eq('user_id', _userId);
    return (data as List).length;
  }
}
