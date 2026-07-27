import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/friend.dart';

class FriendsRepository {
  final SupabaseClient _client;

  FriendsRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  // ── Busca ────────────────────────────────────────────────

  Future<List<PublicProfile>> searchByName(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client
        .from('profiles')
        .select(
          'id, name, username, bio, avatar_url, location, member_since, '
          'favorite_genre, favorite_authors, favorite_book, preferred_format, '
          'privacy_current_book, privacy_calendar, privacy_clubs, '
          'privacy_wishlist, privacy_library, privacy_activity, privacy_compatibility',
        )
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
        .select(
          'id, name, username, bio, avatar_url, location, member_since, '
          'favorite_genre, favorite_authors, favorite_book, preferred_format, '
          'yearly_goal, '
          'privacy_current_book, privacy_calendar, privacy_clubs, '
          'privacy_wishlist, privacy_library, privacy_activity, privacy_compatibility',
        )
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return PublicProfile.fromMap(data);
  }

  /// Busca estatísticas públicas agregadas de um usuário.
  Future<FriendPublicStats> fetchPublicStats(String userId) async {
    // Streak atual
    final streakRows = await _client
        .from('reading_sessions')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(400);
    final streak = _computeStreak(streakRows as List);

    // Totais de sessões
    final sessionAgg = await _client
        .rpc('public_session_stats', params: {'p_user_id': userId})
        .maybeSingle();

    // Contagem de conquistas
    final achCount = await _client
        .from('user_achievements')
        .select('id')
        .eq('user_id', userId);

    // Contagens da biblioteca
    final libRows = await _client
        .from('books')
        .select('status')
        .eq('user_id', userId);

    int libReading = 0, libWishlist = 0, libRead = 0, libAbandoned = 0;
    for (final row in (libRows as List)) {
      switch (row['status'] as String?) {
        case 'reading':
          libReading++;
          break;
        case 'wishlist':
          libWishlist++;
          break;
        case 'completed':
          libRead++;
          break;
        case 'abandoned':
          libAbandoned++;
          break;
      }
    }

    // Meta anual
    final profileRow = await _client
        .from('profiles')
        .select('yearly_goal')
        .eq('id', userId)
        .maybeSingle();
    final yearlyGoal = profileRow?['yearly_goal'] as int?;

    final now = DateTime.now();

    // Livros concluídos este ano (pelo campo updated_at quando status=completed)
    final booksThisYear = await _client
        .from('books')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .gte('updated_at', '${now.year}-01-01');

    final stats = sessionAgg ?? {};
    final booksThisYearCount = (booksThisYear as List<dynamic>).length;

    return FriendPublicStats(
      streak: streak,
      booksCompleted: libRead,
      pagesRead: (stats['total_pages'] as num?)?.toInt() ?? 0,
      readingMinutes: (stats['total_minutes'] as num?)?.toInt() ?? 0,
      achievements: (achCount as List).length,
      bestStreak: (stats['best_streak'] as num?)?.toInt() ?? streak,
      bestSessionMinutes: (stats['best_session_minutes'] as num?)?.toInt() ?? 0,
      avgSessionMinutes: (stats['avg_session_minutes'] as num?)?.toInt() ?? 0,
      avgPagesPerSession: (stats['avg_pages_per_session'] as num?)?.toInt() ?? 0,
      booksThisYear: booksThisYearCount,
      libraryReading: libReading,
      libraryWishlist: libWishlist,
      libraryRead: libRead,
      libraryAbandoned: libAbandoned,
      yearlyGoal: yearlyGoal,
      yearlyProgress: booksThisYearCount,
    );
  }

  /// Retorna o livro atual do amigo (se privacidade permitir).
  Future<FriendCurrentBook?> fetchCurrentBook(String userId) async {
    final data = await _client
        .from('books')
        .select('title, author, cover_url, current_page, total_pages, updated_at')
        .eq('user_id', userId)
        .eq('status', 'reading')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;

    final startedAt = data['updated_at'] != null
        ? DateTime.tryParse(data['updated_at'] as String)
        : null;
    final daysReading = startedAt != null
        ? DateTime.now().difference(startedAt).inDays
        : 0;

    return FriendCurrentBook(
      title: data['title'] as String? ?? '',
      author: data['author'] as String?,
      coverUrl: data['cover_url'] as String?,
      currentPage: (data['current_page'] as num?)?.toInt() ?? 0,
      totalPages: (data['total_pages'] as num?)?.toInt() ?? 0,
      daysReading: daysReading,
    );
  }

  /// Heatmap de leitura público (apenas dias com sessão, sem detalhes).
  Future<List<DateTime>> fetchPublicCalendar(String userId) async {
    final rows = await _client
        .from('reading_sessions')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(365);
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final row in (rows as List)) {
      final dt = DateTime.tryParse(row['created_at'] as String);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      if (seen.add(key)) dates.add(dt);
    }
    return dates;
  }

  // ── Amigos confirmados ───────────────────────────────────

  Future<List<Friend>> listFriends() async {
    final data = await _client
        .from('friends')
        .select(
          'id, friend_id, created_at, '
          'friend_profile:profiles!friends_friend_id_fkey(name, avatar_url, bio, last_seen_at)',
        )
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

  // ── Helpers privados ────────────────────────────────────

  int _computeStreak(List rows) {
    if (rows.isEmpty) return 0;
    final days = <DateTime>{};
    for (final row in rows) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        days.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime expected = DateTime.now().subtract(const Duration(days: 0));
    expected = DateTime(expected.year, expected.month, expected.day);
    for (final day in sorted) {
      if (day == expected || day == expected.subtract(const Duration(days: 1))) {
        streak++;
        expected = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
