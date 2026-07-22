import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/wishlist_item.dart';

class WishlistRepository {
  final SupabaseClient _client;

  WishlistRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<WishlistItem>> fetchAll() async {
    final data = await _client
        .from('wishlist')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => WishlistItem.fromMap(e)).toList();
  }

  Future<WishlistItem> insert({
    required String title,
    String? author,
    String? coverUrl,
    String? notes,
  }) async {
    final data = await _client
        .from('wishlist')
        .insert({
          'user_id': _userId,
          'title': title,
          'author': author,
          'cover_url': coverUrl,
          'notes': notes,
        })
        .select()
        .single();
    return WishlistItem.fromMap(data);
  }

  Future<void> markAcquired(String id) async {
    await _client
        .from('wishlist')
        .update({'acquired': true})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> delete(String id) async {
    await _client
        .from('wishlist')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
