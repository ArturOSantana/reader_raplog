import 'package:equatable/equatable.dart';

// ── Presença em tempo real ─────────────────────────────────────────────────────

class ClubPresenceMember extends Equatable {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final DateTime lastSeenAt;
  final int minutesAgo;
  final bool isActive; // < 5 min = "lendo agora"

  const ClubPresenceMember({
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.lastSeenAt,
    required this.minutesAgo,
    required this.isActive,
  });

  /// Label de exibição: "há X min" ou "lendo agora"
  String get presenceLabel {
    if (isActive) return 'lendo agora';
    if (minutesAgo < 60) return 'há $minutesAgo min';
    final h = minutesAgo ~/ 60;
    return 'há ${h}h';
  }

  factory ClubPresenceMember.fromMap(Map<String, dynamic> map) =>
      ClubPresenceMember(
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
        minutesAgo: (map['minutes_ago'] as num?)?.toInt() ?? 0,
        isActive: map['is_active'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [userId, lastSeenAt];
}

// ── Estatísticas coletivas do clube ───────────────────────────────────────────

class ClubCollectiveStats extends Equatable {
  final int totalPages;
  final int totalMinutes;
  final int totalSessions;
  final int totalBooksRead;
  final int totalMembers;
  final int activeMembers30d;
  final double myPagesPct;
  final double myMinutesPct;
  final String pagesFormatted;
  final int minutesToHours;

  const ClubCollectiveStats({
    required this.totalPages,
    required this.totalMinutes,
    required this.totalSessions,
    required this.totalBooksRead,
    required this.totalMembers,
    required this.activeMembers30d,
    required this.myPagesPct,
    required this.myMinutesPct,
    required this.pagesFormatted,
    required this.minutesToHours,
  });

  factory ClubCollectiveStats.fromMap(Map<String, dynamic> map) =>
      ClubCollectiveStats(
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        totalMinutes: (map['total_minutes'] as num?)?.toInt() ?? 0,
        totalSessions: (map['total_sessions'] as num?)?.toInt() ?? 0,
        totalBooksRead: (map['total_books_read'] as num?)?.toInt() ?? 0,
        totalMembers: (map['total_members'] as num?)?.toInt() ?? 0,
        activeMembers30d: (map['active_members_30d'] as num?)?.toInt() ?? 0,
        myPagesPct: (map['my_pages_pct'] as num?)?.toDouble() ?? 0,
        myMinutesPct: (map['my_minutes_pct'] as num?)?.toDouble() ?? 0,
        pagesFormatted: map['pages_formatted'] as String? ?? '0',
        minutesToHours: (map['minutes_to_hours'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [totalPages, totalSessions, myPagesPct];
}

// ── Heatmap social (um dia) ───────────────────────────────────────────────────

class ClubHeatmapDay extends Equatable {
  final DateTime day;
  final int totalPages;
  final int totalMinutes;
  final int activeMembers;
  final int intensity; // 0–4

  const ClubHeatmapDay({
    required this.day,
    required this.totalPages,
    required this.totalMinutes,
    required this.activeMembers,
    required this.intensity,
  });

  factory ClubHeatmapDay.fromMap(Map<String, dynamic> map) => ClubHeatmapDay(
        day: DateTime.parse(map['day'] as String),
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        totalMinutes: (map['total_minutes'] as num?)?.toInt() ?? 0,
        activeMembers: (map['active_members'] as num?)?.toInt() ?? 0,
        intensity: (map['intensity'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [day, totalPages];
}
