import 'package:equatable/equatable.dart';

// ── Tipo de Story ─────────────────────────────────────────────────────────────

enum StoryType { text, image, bookProgress }

extension StoryTypeX on StoryType {
  String get dbValue {
    switch (this) {
      case StoryType.text:         return 'text';
      case StoryType.image:        return 'image';
      case StoryType.bookProgress: return 'book_progress';
    }
  }

  static StoryType fromDb(String v) => StoryType.values.firstWhere(
        (e) => e.dbValue == v,
        orElse: () => StoryType.text,
      );
}

// ── Model ClubStory ───────────────────────────────────────────────────────────

class ClubStory extends Equatable {
  final String id;
  final String clubId;
  final StoryType storyType;
  final String? content;
  final String? imageUrl;
  final String? bookId;
  final String? caption;
  final DateTime expiresAt;
  final DateTime createdAt;
  // Autor
  final String authorId;
  final String? authorName;
  final String? authorAvatar;
  // Livro (quando bookProgress)
  final String? bookTitle;
  final String? bookCoverUrl;

  const ClubStory({
    required this.id,
    required this.clubId,
    required this.storyType,
    this.content,
    this.imageUrl,
    this.bookId,
    this.caption,
    required this.expiresAt,
    required this.createdAt,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    this.bookTitle,
    this.bookCoverUrl,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  Duration get timeLeft => expiresAt.difference(DateTime.now());

  String get timeLeftLabel {
    final h = timeLeft.inHours;
    final m = timeLeft.inMinutes % 60;
    if (h <= 0) return '${m}min restantes';
    if (h < 24) return '${h}h restantes';
    return 'Expira em breve';
  }

  factory ClubStory.fromMap(Map<String, dynamic> map) => ClubStory(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        storyType: StoryTypeX.fromDb(map['story_type'] as String),
        content: map['content'] as String?,
        imageUrl: map['image_url'] as String?,
        bookId: map['book_id'] as String?,
        caption: map['caption'] as String?,
        expiresAt: DateTime.parse(map['expires_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        authorId: map['author_id'] as String,
        authorName: map['author_name'] as String?,
        authorAvatar: map['author_avatar'] as String?,
        bookTitle: map['book_title'] as String?,
        bookCoverUrl: map['book_cover_url'] as String?,
      );

  @override
  List<Object?> get props => [id, clubId, authorId, createdAt];
}

// ── Model ClubTimeCapsule ─────────────────────────────────────────────────────

class ClubTimeCapsuleEntry extends Equatable {
  final String id;
  final String clubId;
  final String authorId;
  final String? authorName;
  final String message;
  final String? bookId;
  final String? bookTitle;
  final DateTime revealAt;
  final bool isRevealed;
  final DateTime? revealedAt;
  final DateTime createdAt;

  const ClubTimeCapsuleEntry({
    required this.id,
    required this.clubId,
    required this.authorId,
    this.authorName,
    required this.message,
    this.bookId,
    this.bookTitle,
    required this.revealAt,
    required this.isRevealed,
    this.revealedAt,
    required this.createdAt,
  });

  bool get isPending => !isRevealed;

  String get revealLabel {
    if (isRevealed) return 'Revelada';
    final diff = revealAt.difference(DateTime.now());
    if (diff.inDays > 0) return 'Em ${diff.inDays} dias';
    return 'Em breve';
  }

  factory ClubTimeCapsuleEntry.fromMap(Map<String, dynamic> map) =>
      ClubTimeCapsuleEntry(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        authorId: map['author_id'] as String,
        authorName: map['author_name'] as String?,
        message: map['message'] as String,
        bookId: map['book_id'] as String?,
        bookTitle: map['book_title'] as String?,
        revealAt: DateTime.parse(map['reveal_at'] as String),
        isRevealed: map['is_revealed'] as bool? ?? false,
        revealedAt: map['revealed_at'] != null
            ? DateTime.parse(map['revealed_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, clubId, authorId, revealAt];
}

// ── Model ClubMomentStatus ────────────────────────────────────────────────────

class ClubMomentStatus {
  final String? momentTime;   // ex: "21:00"
  final String? momentLabel;  // ex: "Momento do Livro"
  final bool isActive;
  final int confirmationsToday;
  final bool userConfirmedToday;

  const ClubMomentStatus({
    this.momentTime,
    this.momentLabel,
    required this.isActive,
    required this.confirmationsToday,
    required this.userConfirmedToday,
  });

  bool get isConfigured => isActive && momentTime != null;
}
