import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/social_feed.dart';

class SocialFeedRepository {
  final SupabaseClient _client;

  SocialFeedRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Feed de amigos ────────────────────────────────────────────────────────

  Future<List<FeedItem>> fetchFeed({int limit = 30}) async {
    final data = await _client
        .from('social_feed')
        .select(
          'id, user_id, event_type, book_title, book_author, rating, '
          'streak_days, achievement_name, goal_description, likes_count, created_at, '
          'profile:profiles(name, avatar_url)',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    final List<Map<String, dynamic>> rows =
        List<Map<String, dynamic>>.from(data as List);

    // Verifica quais foram curtidos pelo usuário atual
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final likesData = await _client
        .from('feed_likes')
        .select('feed_id')
        .eq('user_id', _userId)
        .filter('feed_id', 'in', '(${ids.map((id) => '"$id"').join(',')})');

    final likedIds =
        Set<String>.from((likesData as List).map((e) => e['feed_id']));

    return rows.map((row) {
      return FeedItem.fromMap({...row, 'liked_by_me': likedIds.contains(row['id'])});
    }).toList();
  }

  // ── Publicar eventos ──────────────────────────────────────────────────────

  Future<void> publishFinishedBook({
    required String bookTitle,
    String? bookAuthor,
    int? rating,
  }) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'finished_book',
      'book_title': bookTitle,
      'book_author': bookAuthor,
      'rating': rating,
    });
  }

  Future<void> publishStartedBook({
    required String bookTitle,
    String? bookAuthor,
  }) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'started_book',
      'book_title': bookTitle,
      'book_author': bookAuthor,
    });
  }

  Future<void> publishStreak(int days) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'streak',
      'streak_days': days,
    });
  }

  Future<void> publishAchievement(String achievementName) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'achievement',
      'achievement_name': achievementName,
    });
  }

  Future<void> publishGoalCompleted(String goalDescription) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'goal_completed',
      'goal_description': goalDescription,
    });
  }

  // ── Curtidas ──────────────────────────────────────────────────────────────

  Future<void> toggleLike(String feedId, {required bool currentlyLiked}) async {
    if (currentlyLiked) {
      await _client
          .from('feed_likes')
          .delete()
          .eq('feed_id', feedId)
          .eq('user_id', _userId);
    } else {
      await _client.from('feed_likes').insert({
        'feed_id': feedId,
        'user_id': _userId,
      });
    }
  }

  // ── Deletar post próprio ──────────────────────────────────────────────────

  Future<void> deletePost(String feedId) async {
    await _client
        .from('social_feed')
        .delete()
        .eq('id', feedId)
        .eq('user_id', _userId);
  }
}
