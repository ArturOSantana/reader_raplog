import 'package:equatable/equatable.dart';

enum FeedEventType {
  finishedBook,
  startedBook,
  streak,
  achievement,
  goalCompleted,
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
      default:
        return FeedEventType.finishedBook;
    }
  }
}

class FeedItem extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final FeedEventType eventType;
  final String? bookTitle;
  final String? bookAuthor;
  final int? rating;
  final String? review;
  final int? readingTimeMinutes;
  final int? streakDays;
  final String? achievementName;
  final String? goalDescription;
  final int likesCount;
  final bool likedByMe;
  final DateTime createdAt;

  const FeedItem({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.eventType,
    this.bookTitle,
    this.bookAuthor,
    this.rating,
    this.review,
    this.readingTimeMinutes,
    this.streakDays,
    this.achievementName,
    this.goalDescription,
    required this.likesCount,
    required this.likedByMe,
    required this.createdAt,
  });

  factory FeedItem.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    return FeedItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: profile['name'] as String?,
      userAvatarUrl: profile['avatar_url'] as String?,
      eventType: FeedEventTypeX.fromDb(map['event_type'] as String),
      bookTitle: map['book_title'] as String?,
      bookAuthor: map['book_author'] as String?,
      rating: map['rating'] as int?,
      review: map['review'] as String?,
      readingTimeMinutes: map['reading_time_minutes'] as int?,
      streakDays: map['streak_days'] as int?,
      achievementName: map['achievement_name'] as String?,
      goalDescription: map['goal_description'] as String?,
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      likedByMe: map['liked_by_me'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, eventType, createdAt];

  String get readingTimeLabel {
    if (readingTimeMinutes == null || readingTimeMinutes! <= 0) return '';
    final h = readingTimeMinutes! ~/ 60;
    final m = readingTimeMinutes! % 60;
    if (h == 0) return '${m}min';
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
