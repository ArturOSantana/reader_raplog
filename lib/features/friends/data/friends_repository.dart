import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/friend.dart';

class FriendsRepository {
  final SupabaseClient _client;

  FriendsRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Busca ────────────────────────────────────────────────

  Future<List<PublicProfile>> searchByName(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client
        .from('profiles')
        .select('id, name, bio, avatar_url, favorite_genre')
        .ilike('name', '%${query.trim()}%')
        .neq('id', _userId)
        .limit(20);
    return (data as List)
        .map((m) => PublicProfile.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<PublicProfile?> fetchPublicProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id, name, bio, avatar_url, favorite_genre')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return PublicProfile.fromMap(data);
  }

  // ── Amigos confirmados ───────────────────────────────────

  Future<List<Friend>> listFriends() async {
    final data = await _client
        .from('friends')
        .select('id, friend_id, created_at, friend_profile:profiles!friends_friend_id_fkey(name, avatar_url, bio)')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((m) => Friend.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeFriend(String friendId) async {
    // Remove as duas entradas bidirecional
    await _client
        .from('friends')
        .delete()
        .or('and(user_id.eq.$_userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$_userId)');
  }

  // ── Solicitações ─────────────────────────────────────────

  /// Retorna todas as solicitações pendentes RECEBIDAS pelo usuário atual.
  Future<List<FriendRequest>> listPendingReceived() async {
    final data = await _client
        .from('friend_requests')
        .select(
          'id, sender_id, receiver_id, status, created_at, '
          'sender_profile:profiles!friend_requests_sender_id_fkey(name, avatar_url)',
        )
        .eq('receiver_id', _userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((m) => FriendRequest.fromMap(m as Map<String, dynamic>, _userId))
        .toList();
  }

  /// Retorna solicitações pendentes ENVIADAS pelo usuário atual.
  Future<List<FriendRequest>> listPendingSent() async {
    final data = await _client
        .from('friend_requests')
        .select(
          'id, sender_id, receiver_id, status, created_at, '
          'receiver_profile:profiles!friend_requests_receiver_id_fkey(name, avatar_url)',
        )
        .eq('sender_id', _userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((m) => FriendRequest.fromMap(m as Map<String, dynamic>, _userId))
        .toList();
  }

  /// Envia solicitação de amizade para [receiverId].
  Future<void> sendRequest(String receiverId) async {
    await _client.from('friend_requests').insert({
      'sender_id': _userId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// Aceita via RPC (garante atomicidade e RLS server-side).
  Future<void> acceptRequest(String requestId) async {
    await _client.rpc('accept_friend_request', params: {'p_request_id': requestId});
  }

  Future<void> declineRequest(String requestId) async {
    await _client
        .from('friend_requests')
        .update({'status': 'declined'})
        .eq('id', requestId)
        .eq('receiver_id', _userId);
  }

  Future<void> cancelRequest(String requestId) async {
    await _client
        .from('friend_requests')
        .delete()
        .eq('id', requestId)
        .eq('sender_id', _userId);
  }

  /// Verifica o status de relacionamento com [otherUserId].
  /// Retorna 'friend' | 'pending_sent' | 'pending_received' | 'none'.
  Future<String> relationshipStatus(String otherUserId) async {
    // Verifica amizade
    final friendRow = await _client
        .from('friends')
        .select('id')
        .eq('user_id', _userId)
        .eq('friend_id', otherUserId)
        .maybeSingle();
    if (friendRow != null) return 'friend';

    // Verifica solicitação enviada
    final sentRow = await _client
        .from('friend_requests')
        .select('id')
        .eq('sender_id', _userId)
        .eq('receiver_id', otherUserId)
        .eq('status', 'pending')
        .maybeSingle();
    if (sentRow != null) return 'pending_sent';

    // Verifica solicitação recebida
    final receivedRow = await _client
        .from('friend_requests')
        .select('id')
        .eq('sender_id', otherUserId)
        .eq('receiver_id', _userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (receivedRow != null) return 'pending_received';

    return 'none';
  }
}
