import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/social_feed.dart';

class SocialFeedRepository {
  final SupabaseClient _client;

  SocialFeedRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  static const _feedSelect =
      'id, user_id, event_type, club_id, book_title, book_author, rating, review, '
      'reading_time_minutes, pages_read, current_page, session_minutes, '
      'streak_days, achievement_name, goal_description, '
      'likes_count, comments_count, reactions_summary, created_at, '
      'profile:profiles!social_feed_user_id_fkey(name, avatar_url)';

  // ── Enriquece rows com liked_by_me ────────────────────────────────────────
  Future<List<FeedItem>> _hydrateLikes(
      List<Map<String, dynamic>> rows) async {
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

  // ── Feed de amigos (global) ───────────────────────────────────────────────

  Future<List<FeedItem>> fetchFeed({int limit = 30}) async {
    final data = await _client
        .from('social_feed')
        .select(_feedSelect)
        .isFilter('club_id', null)
        .order('created_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(data as List);
    return _hydrateLikes(rows);
  }

  // ── Feed do clube ─────────────────────────────────────────────────────────

  Future<List<FeedItem>> fetchClubFeed(String clubId, {int limit = 40}) async {
    final data = await _client
        .from('social_feed')
        .select(_feedSelect)
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(data as List);
    return _hydrateLikes(rows);
  }

  // ── Publicar eventos ──────────────────────────────────────────────────────

  Future<void> publishFinishedBook({
    required String bookTitle,
    String? bookAuthor,
    int? rating,
    String? review,
    int? readingTimeMinutes,
  }) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'finished_book',
      'book_title': bookTitle,
      'book_author': bookAuthor,
      'rating': rating,
      if (review != null && review.isNotEmpty) 'review': review,
      if (readingTimeMinutes != null) 'reading_time_minutes': readingTimeMinutes,
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

  // ── Publicar check-in de sessão ───────────────────────────────────────────
  // Chamado manualmente como fallback; o trigger auto_checkin_after_session
  // cuida disso automaticamente no banco quando o livro é do clube.

  Future<void> publishReadingSession({
    required String bookTitle,
    required String clubId,
    int? pagesRead,
    int? currentPage,
    int? sessionMinutes,
    int? streakDays,
  }) async {
    await _client.from('social_feed').insert({
      'user_id': _userId,
      'event_type': 'reading_session',
      'club_id': clubId,
      'book_title': bookTitle,
      if (pagesRead != null) 'pages_read': pagesRead,
      if (currentPage != null) 'current_page': currentPage,
      if (sessionMinutes != null) 'session_minutes': sessionMinutes,
      if (streakDays != null) 'streak_days': streakDays,
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

  // ── Reações tipadas ───────────────────────────────────────────────────────

  Future<void> toggleReaction(String feedId, FeedReactionType type) async {
    final existing = await _client
        .from('feed_reactions')
        .select('feed_id')
        .eq('feed_id', feedId)
        .eq('user_id', _userId)
        .eq('reaction_type', type.dbValue)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('feed_reactions')
          .delete()
          .eq('feed_id', feedId)
          .eq('user_id', _userId)
          .eq('reaction_type', type.dbValue);
    } else {
      await _client.from('feed_reactions').insert({
        'feed_id': feedId,
        'user_id': _userId,
        'reaction_type': type.dbValue,
      });
    }
  }

  /// Retorna quais reaction_types o usuário já deu nesse post.
  Future<Set<String>> fetchMyReactions(String feedId) async {
    final data = await _client
        .from('feed_reactions')
        .select('reaction_type')
        .eq('feed_id', feedId)
        .eq('user_id', _userId);
    return Set<String>.from(
      (data as List).map((e) => e['reaction_type'] as String),
    );
  }

  // ── Comentários ───────────────────────────────────────────────────────────

  Future<List<FeedComment>> fetchComments(String feedId) async {
    final data = await _client
        .from('feed_comments')
        .select(
          'id, feed_id, user_id, parent_id, content, spoiler_level, created_at, '
          'profile:profiles!feed_comments_user_id_fkey(name, avatar_url)',
        )
        .eq('feed_id', feedId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data as List)
        .map(FeedComment.fromMap)
        .toList();
  }

  Future<FeedComment> addComment({
    required String feedId,
    required String content,
    String? parentId,
    String spoilerLevel = 'none',
  }) async {
    final row = await _client.from('feed_comments').insert({
      'feed_id': feedId,
      'user_id': _userId,
      'content': content,
      if (parentId != null) 'parent_id': parentId,
      'spoiler_level': spoilerLevel,
    }).select(
      'id, feed_id, user_id, parent_id, content, spoiler_level, created_at, '
      'profile:profiles!feed_comments_user_id_fkey(name, avatar_url)',
    ).single();

    return FeedComment.fromMap(row);
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('feed_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
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
