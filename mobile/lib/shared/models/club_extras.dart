import 'package:equatable/equatable.dart';

// ── Entrada de ranking do clube ───────────────────────────────────────────────

class ClubRankingEntry extends Equatable {
  final int position;
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final double score;
  final int totalPages;
  final int totalMinutes;
  final int totalSessions;

  const ClubRankingEntry({
    required this.position,
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.score,
    required this.totalPages,
    required this.totalMinutes,
    required this.totalSessions,
  });

  bool get isOnPodium => position <= 3;

  String get podiumLabel {
    switch (position) {
      case 1:  return '1°';
      case 2:  return '2°';
      case 3:  return '3°';
      default: return '#$position';
    }
  }

  factory ClubRankingEntry.fromMap(Map<String, dynamic> map) => ClubRankingEntry(
        position: (map['rank'] as num).toInt(),
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        score: (map['score'] as num).toDouble(),
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        totalMinutes: (map['total_minutes'] as num?)?.toInt() ?? 0,
        totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [position, userId, score];
}

// ── Estatísticas gerais do clube ──────────────────────────────────────────────

class ClubStats extends Equatable {
  final String clubId;
  final int memberCount;
  final int totalSessions;
  final int totalPages;
  final int totalMinutes;
  final double totalHours;
  final int booksFinished;

  const ClubStats({
    required this.clubId,
    required this.memberCount,
    required this.totalSessions,
    required this.totalPages,
    required this.totalMinutes,
    required this.totalHours,
    required this.booksFinished,
  });

  factory ClubStats.fromMap(String clubId, Map<String, dynamic> map) =>
      ClubStats(
        clubId: clubId,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
        totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        totalMinutes: (map['total_minutes'] as num?)?.toInt() ?? 0,
        totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0,
        booksFinished: (map['books_finished'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [clubId, totalPages, totalMinutes];
}

// ── Progresso de leitura coletiva ────────────────────────────────────────────

class ClubReadingProgress extends Equatable {
  final int totalPagesRead;
  final double avgCurrentPage;
  final int memberCount;
  final int totalPagesBook;
  final double percentComplete;
  final int membersReadToday;

  const ClubReadingProgress({
    required this.totalPagesRead,
    required this.avgCurrentPage,
    required this.memberCount,
    required this.totalPagesBook,
    required this.percentComplete,
    required this.membersReadToday,
  });

  factory ClubReadingProgress.fromMap(Map<String, dynamic> map) =>
      ClubReadingProgress(
        totalPagesRead: (map['total_pages_read'] as num?)?.toInt() ?? 0,
        avgCurrentPage: (map['avg_current_page'] as num?)?.toDouble() ?? 0,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
        totalPagesBook: (map['total_pages_book'] as num?)?.toInt() ?? 0,
        percentComplete: (map['percent_complete'] as num?)?.toDouble() ?? 0,
        membersReadToday: (map['members_read_today'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [totalPagesRead, percentComplete, membersReadToday];
}

// ── Membro lendo agora ────────────────────────────────────────────────────────

class ClubReadingNowEntry extends Equatable {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final DateTime startedAt;
  final int? currentPage;

  const ClubReadingNowEntry({
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.startedAt,
    this.currentPage,
  });

  /// Tempo desde que começou a sessão, formatado.
  String get elapsedLabel {
    final mins = DateTime.now().difference(startedAt).inMinutes;
    if (mins < 60) return 'há $mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? 'há ${h}h' : 'há ${h}h ${m}min';
  }

  factory ClubReadingNowEntry.fromMap(Map<String, dynamic> map) =>
      ClubReadingNowEntry(
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        startedAt: DateTime.parse(map['started_at'] as String),
        currentPage: (map['current_page'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [userId, startedAt];
}

// ── Hall da Fama ──────────────────────────────────────────────────────────────

class ClubHallOfFameEntry extends Equatable {
  final String id;
  final String clubId;
  final String bookTitle;
  final String? bookAuthor;
  final DateTime seasonEndedAt;

  final String? topReaderName;
  final int? topReaderPages;

  final String? topStreakName;
  final int? topStreakDays;

  final String? topSessionsName;
  final int? topSessionsCount;

  final int totalMembers;
  final int totalPages;
  final int totalMinutes;
  final int totalSessions;

  const ClubHallOfFameEntry({
    required this.id,
    required this.clubId,
    required this.bookTitle,
    this.bookAuthor,
    required this.seasonEndedAt,
    this.topReaderName,
    this.topReaderPages,
    this.topStreakName,
    this.topStreakDays,
    this.topSessionsName,
    this.topSessionsCount,
    required this.totalMembers,
    required this.totalPages,
    required this.totalMinutes,
    required this.totalSessions,
  });

  factory ClubHallOfFameEntry.fromMap(Map<String, dynamic> map) =>
      ClubHallOfFameEntry(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        bookTitle: map['book_title'] as String,
        bookAuthor: map['book_author'] as String?,
        seasonEndedAt: DateTime.parse(map['season_ended_at'] as String),
        topReaderName: map['top_reader_name'] as String?,
        topReaderPages: (map['top_reader_pages'] as num?)?.toInt(),
        topStreakName: map['top_streak_name'] as String?,
        topStreakDays: (map['top_streak_days'] as num?)?.toInt(),
        topSessionsName: map['top_sessions_name'] as String?,
        topSessionsCount: (map['top_sessions_count'] as num?)?.toInt(),
        totalMembers: (map['total_members'] as num?)?.toInt() ?? 0,
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        totalMinutes: (map['total_minutes'] as num?)?.toInt() ?? 0,
        totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, clubId, bookTitle, seasonEndedAt];
}
