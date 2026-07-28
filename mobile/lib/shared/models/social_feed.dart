import 'package:equatable/equatable.dart';

enum FeedEventType {
  finishedBook,
  startedBook,
  streak,
  achievement,
  goalCompleted,
  readingSession,
  joinedClub,
  betResolved,
  pollOpened,
  pollClosed,
  challengeStarted,
  challengeFinished,
  sealAwarded,
  bookReview,
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
      case FeedEventType.betResolved:
        return 'bet_resolved';
      case FeedEventType.pollOpened:
        return 'poll_opened';
      case FeedEventType.pollClosed:
        return 'poll_closed';
      case FeedEventType.challengeStarted:
        return 'challenge_started';
      case FeedEventType.challengeFinished:
        return 'challenge_finished';
      case FeedEventType.sealAwarded:
        return 'seal_awarded';
      case FeedEventType.bookReview:
        return 'book_review';
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
      case 'bet_resolved':
        return FeedEventType.betResolved;
      case 'poll_opened':
        return FeedEventType.pollOpened;
      case 'poll_closed':
        return FeedEventType.pollClosed;
      case 'challenge_started':
        return FeedEventType.challengeStarted;
      case 'challenge_finished':
        return FeedEventType.challengeFinished;
      case 'seal_awarded':
        return FeedEventType.sealAwarded;
      case 'book_review':
        return FeedEventType.bookReview;
      default:
        return FeedEventType.readingSession;
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

  /// Narrativa humanizada — substitui eventos "frios" por frases com contexto.
  ///
  /// Segue o princípio da estratégia de produto:
  /// "A diferença entre um produto de dados e um produto de emoção está
  /// na narrativa automática."
  String humanNarrative({String? viewerName}) {
    final name = userName ?? 'Alguém';
    switch (eventType) {
      case FeedEventType.readingSession:
        final pages = pagesRead;
        final mins = sessionMinutes ?? readingTimeMinutes;
        final book = bookTitle;
        if (pages != null && pages > 0 && book != null) {
          final timeStr = mins != null && mins > 0
              ? ' em ${_fmtMins(mins)}'
              : '';
          return '$name leu $pages página${pages == 1 ? '' : 's'} de "$book"$timeStr.';
        }
        if (pages != null && pages > 0) {
          return '$name leu $pages página${pages == 1 ? '' : 's'}.';
        }
        if (mins != null && mins > 0) {
          return '$name leu por ${_fmtMins(mins)}.';
        }
        return '$name registrou uma sessão de leitura.';

      case FeedEventType.finishedBook:
        final book = bookTitle ?? 'um livro';
        final timeStr = readingTimeMinutes != null && readingTimeMinutes! > 0
            ? ' em ${_fmtMins(readingTimeMinutes!)}'
            : '';
        return '$name terminou de ler "$book"$timeStr.';

      case FeedEventType.startedBook:
        final book = bookTitle ?? 'um livro';
        return '$name começou a ler "$book".';

      case FeedEventType.streak:
        final days = streakDays ?? 0;
        if (days >= 100) {
          return '$name atingiu $days dias seguidos lendo. Isso é mais do que 97% dos leitores.';
        }
        if (days >= 30) {
          return '$name está há $days dias lendo sem parar.';
        }
        return '$name mantém uma sequência de $days dia${days == 1 ? '' : 's'}.';

      case FeedEventType.achievement:
        final achv = achievementName ?? 'uma conquista';
        return '$name desbloqueou "$achv".';

      case FeedEventType.goalCompleted:
        final goal = goalDescription;
        return goal != null
            ? '$name completou a missão: $goal'
            : '$name completou a missão do dia.';

      case FeedEventType.joinedClub:
        return '$name entrou no clube.';

      case FeedEventType.challengeStarted:
        return '$name aceitou um novo desafio.';

      case FeedEventType.challengeFinished:
        return '$name concluiu um desafio de leitura.';

      case FeedEventType.sealAwarded:
        return '$name recebeu um selo do clube.';

      case FeedEventType.bookReview:
        final book = bookTitle ?? 'um livro';
        return '$name escreveu uma resenha de "$book".';

      case FeedEventType.betResolved:
        return '$name participou de uma aposta.';

      case FeedEventType.pollOpened:
        return 'Uma nova votação foi aberta no clube.';

      case FeedEventType.pollClosed:
        return 'A votação do clube foi encerrada.';
    }
  }

  static String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}min';
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
