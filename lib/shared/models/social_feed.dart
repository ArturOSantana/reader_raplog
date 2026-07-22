import 'package:equatable/equatable.dart';

enum FeedEventType {
  finishedBook,
  startedBook,
  streak,
  achievement,
  goalCompleted,
  readingSession,
  joinedClub,
}

extension FeedEventTypeX on FeedEventType {
  String get dbValue {
    switch (this) {
      case FeedEventType.finishedBook:
        return 'finished_book';
      case FeedEventType.startedBook:
        return 'started_book';
      case FeedEventType.streak:
        return 'streak';
      case FeedEventType.achievement:
        return 'achievement';
      case FeedEventType.goalCompleted:
        return 'goal_completed';
      case FeedEventType.readingSession:
        return 'reading_session';
      case FeedEventType.joinedClub:
        return 'joined_club';
    }
  }

  static FeedEventType fromDb(String value) {
    switch (value) {
      case 'finished_book':
        return FeedEventType.finishedBook;
      case 'started_book':
        return FeedEventType.startedBook;
      case 'streak':
        return FeedEventType.streak;
      case 'achievement':
        return FeedEventType.achievement;
      case 'goal_completed':
        return FeedEventType.goalCompleted;
      case 'reading_session':
        return FeedEventType.readingSession;
      case 'joined_club':
        return FeedEventType.joinedClub;
      default:
        return FeedEventType.finishedBook;
    }
  }
}

enum FeedReactionType {
  heart,
  book,
  fire,
  clap,
  brain,
  coffee,
  loveEyes;

  String get dbValue {
    switch (this) {
      case FeedReactionType.heart:
        return 'heart';
      case FeedReactionType.book:
        return 'book';
      case FeedReactionType.fire:
        return 'fire';
      case FeedReactionType.clap:
        return 'clap';
      case FeedReactionType.brain:
        return 'brain';
      case FeedReactionType.coffee:
        return 'coffee';
      case FeedReactionType.loveEyes:
        return 'love_eyes';
    }
  }

  String get emoji {
    switch (this) {
      case FeedReactionType.heart:
        return '❤️';
      case FeedReactionType.book:
        return '📚';
      case FeedReactionType.fire:
        return '🔥';
      case FeedReactionType.clap:
        return '👏';
      case FeedReactionType.brain:
        return '🧠';
      case FeedReactionType.coffee:
        return '☕';
      case FeedReactionType.loveEyes:
        return '😍';
    }
  }

  static FeedReactionType? fromDb(String value) {
    switch (value) {
      case 'heart':     return FeedReactionType.heart;
      case 'book':      return FeedReactionType.book;
      case 'fire':      return FeedReactionType.fire;
      case 'clap':      return FeedReactionType.clap;
      case 'brain':     return FeedReactionType.brain;
      case 'coffee':    return FeedReactionType.coffee;
      case 'love_eyes': return FeedReactionType.loveEyes;
      default:          return null;
    }
  }
}

class FeedComment extends Equatable {
  final String id;
  final String feedId;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? parentId;
  final String content;
  final String spoilerLevel; // 'none' | 'partial' | 'full'
  final DateTime createdAt;

  const FeedComment({
    required this.id,
    required this.feedId,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    this.parentId,
    required this.content,
    this.spoilerLevel = 'none',
    required this.createdAt,
  });

  bool get hasSpoiler => spoilerLevel != 'none';

  factory FeedComment.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    return FeedComment(
      id: map['id'] as String,
      feedId: map['feed_id'] as String,
      userId: map['user_id'] as String,
      userName: profile['name'] as String?,
      userAvatarUrl: profile['avatar_url'] as String?,
      parentId: map['parent_id'] as String?,
      content: map['content'] as String,
      spoilerLevel: map['spoiler_level'] as String? ?? 'none',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, feedId, userId, createdAt];
}

class FeedItem extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final FeedEventType eventType;
  final String? clubId;
  final String? bookTitle;
  final String? bookAuthor;
  final int? rating;
  final String? review;
  final int? readingTimeMinutes;
  final int? pagesRead;
  final int? currentPage;
  final int? sessionMinutes;
  final int? streakDays;
  final String? achievementName;
  final String? goalDescription;
  final int likesCount;
  final bool likedByMe;
  final int commentsCount;
  final Map<String, int> reactionsSummary;
  final DateTime createdAt;

  const FeedItem({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.eventType,
    this.clubId,
    this.bookTitle,
    this.bookAuthor,
    this.rating,
    this.review,
    this.readingTimeMinutes,
    this.pagesRead,
    this.currentPage,
    this.sessionMinutes,
    this.streakDays,
    this.achievementName,
    this.goalDescription,
    required this.likesCount,
    required this.likedByMe,
    this.commentsCount = 0,
    this.reactionsSummary = const {},
    required this.createdAt,
  });

  factory FeedItem.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    final reactionsRaw = map['reactions_summary'] as Map<String, dynamic>? ?? {};
    return FeedItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: profile['name'] as String?,
      userAvatarUrl: profile['avatar_url'] as String?,
      eventType: FeedEventTypeX.fromDb(map['event_type'] as String),
      clubId: map['club_id'] as String?,
      bookTitle: map['book_title'] as String?,
      bookAuthor: map['book_author'] as String?,
      rating: map['rating'] as int?,
      review: map['review'] as String?,
      readingTimeMinutes: map['reading_time_minutes'] as int?,
      pagesRead: (map['pages_read'] as num?)?.toInt(),
      currentPage: (map['current_page'] as num?)?.toInt(),
      sessionMinutes: (map['session_minutes'] as num?)?.toInt(),
      streakDays: map['streak_days'] as int?,
      achievementName: map['achievement_name'] as String?,
      goalDescription: map['goal_description'] as String?,
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      likedByMe: map['liked_by_me'] as bool? ?? false,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      reactionsSummary: reactionsRaw.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, eventType, createdAt];

  bool get isClubPost => clubId != null;

  String get readingTimeLabel {
    final mins = sessionMinutes ?? readingTimeMinutes;
    if (mins == null || mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}min';
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  int totalReactions() =>
      reactionsSummary.values.fold(0, (a, b) => a + b);
}
