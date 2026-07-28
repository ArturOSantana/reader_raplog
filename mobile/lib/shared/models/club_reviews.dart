import 'package:equatable/equatable.dart';

// ── Enum: recomendação ────────────────────────────────────────────────────────

enum WouldRecommend { yes, no, withReservations }

extension WouldRecommendX on WouldRecommend {
  String get dbValue {
    switch (this) {
      case WouldRecommend.yes:              return 'yes';
      case WouldRecommend.no:               return 'no';
      case WouldRecommend.withReservations: return 'with_reservations';
    }
  }

  String get label {
    switch (this) {
      case WouldRecommend.yes:              return 'Sim';
      case WouldRecommend.no:               return 'Não';
      case WouldRecommend.withReservations: return 'Com ressalvas';
    }
  }

  static WouldRecommend fromDb(String v) =>
      WouldRecommend.values.firstWhere(
        (e) => e.dbValue == v,
        orElse: () => WouldRecommend.yes,
      );
}

// ── Enum: nível de spoiler (reusa lógica das discussões de marco) ─────────────

enum ReviewSpoilerLevel { none, partial, full }

extension ReviewSpoilerLevelX on ReviewSpoilerLevel {
  String get dbValue => name;

  String get label {
    switch (this) {
      case ReviewSpoilerLevel.none:    return 'Sem spoiler';
      case ReviewSpoilerLevel.partial: return 'Parcial';
      case ReviewSpoilerLevel.full:    return 'Spoiler total';
    }
  }

  static ReviewSpoilerLevel fromDb(String v) =>
      ReviewSpoilerLevel.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ReviewSpoilerLevel.none,
      );
}

// ── Model: Resenha ────────────────────────────────────────────────────────────

class ClubReview extends Equatable {
  final String id;
  final String clubId;
  final String bookHistoryId;
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final int rating;               // 1–5
  final String? whatWorked;
  final String? whatDidnt;
  final WouldRecommend wouldRecommend;
  final ReviewSpoilerLevel spoilerLevel;
  final double? avgRating;        // média do ciclo, preenchida pelo RPC
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ClubReview({
    required this.id,
    required this.clubId,
    required this.bookHistoryId,
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.rating,
    this.whatWorked,
    this.whatDidnt,
    required this.wouldRecommend,
    required this.spoilerLevel,
    this.avgRating,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasSpoiler => spoilerLevel != ReviewSpoilerLevel.none;

  factory ClubReview.fromMap(Map<String, dynamic> map) => ClubReview(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        bookHistoryId: map['book_history_id'] as String,
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        rating: (map['rating'] as num).toInt(),
        whatWorked: map['what_worked'] as String?,
        whatDidnt: map['what_didnt'] as String?,
        wouldRecommend:
            WouldRecommendX.fromDb(map['would_recommend'] as String),
        spoilerLevel:
            ReviewSpoilerLevelX.fromDb(map['spoiler_level'] as String? ?? 'none'),
        avgRating: (map['avg_rating'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, clubId, bookHistoryId, userId];
}

// ── Model: stats de resenhas de um clube ─────────────────────────────────────

class ClubReviewStats extends Equatable {
  final String bookHistoryId;
  final String bookTitle;
  final int reviewCount;
  final double avgRating;
  final double ratingStddev;  // alta stddev = livro controverso

  const ClubReviewStats({
    required this.bookHistoryId,
    required this.bookTitle,
    required this.reviewCount,
    required this.avgRating,
    required this.ratingStddev,
  });

  factory ClubReviewStats.fromMap(Map<String, dynamic> map) => ClubReviewStats(
        bookHistoryId: map['book_history_id'] as String,
        bookTitle: map['book_title'] as String,
        reviewCount: (map['review_count'] as num).toInt(),
        avgRating: (map['avg_rating'] as num).toDouble(),
        ratingStddev: (map['rating_stddev'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [bookHistoryId, reviewCount, avgRating];
}
