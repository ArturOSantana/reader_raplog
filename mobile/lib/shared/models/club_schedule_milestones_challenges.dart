import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ── Entrada do cronograma de leitura ─────────────────────────────────────────

class ClubReadingScheduleEntry extends Equatable {
  final String id;
  final String clubId;
  final int weekNumber;
  final String? title;
  final String? chapterFrom;
  final String? chapterTo;
  final int? pageFrom;
  final int? pageTo;
  final DateTime? targetDate;
  final String? notes;
  final DateTime createdAt;

  const ClubReadingScheduleEntry({
    required this.id,
    required this.clubId,
    required this.weekNumber,
    this.title,
    this.chapterFrom,
    this.chapterTo,
    this.pageFrom,
    this.pageTo,
    this.targetDate,
    this.notes,
    required this.createdAt,
  });

  /// Rótulo amigável para exibição no calendário / aba de ritmo.
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (chapterFrom != null && chapterTo != null) {
      return 'Semana $weekNumber — Cap. $chapterFrom a $chapterTo';
    }
    if (pageFrom != null && pageTo != null) {
      return 'Semana $weekNumber — Pág. $pageFrom–$pageTo';
    }
    return 'Semana $weekNumber';
  }

  bool get hasPastDeadline =>
      targetDate != null && targetDate!.isBefore(DateTime.now());

  factory ClubReadingScheduleEntry.fromMap(Map<String, dynamic> map) =>
      ClubReadingScheduleEntry(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        weekNumber: (map['week_number'] as num).toInt(),
        title: map['title'] as String?,
        chapterFrom: map['chapter_from'] as String?,
        chapterTo: map['chapter_to'] as String?,
        pageFrom: (map['page_from'] as num?)?.toInt(),
        pageTo: (map['page_to'] as num?)?.toInt(),
        targetDate: map['target_date'] != null
            ? DateTime.parse(map['target_date'] as String)
            : null,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'club_id': clubId,
        'week_number': weekNumber,
        'title': title,
        'chapter_from': chapterFrom,
        'chapter_to': chapterTo,
        'page_from': pageFrom,
        'page_to': pageTo,
        'target_date': targetDate?.toIso8601String().substring(0, 10),
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, clubId, weekNumber];
}

// ── Marco de progresso ────────────────────────────────────────────────────────

class ClubMilestone extends Equatable {
  final String id;
  final String clubId;
  final String? bookHistoryId;
  final int milestonePct;   // 25 | 50 | 75 | 100
  final String? title;
  final DateTime? unlockedAt;
  final DateTime createdAt;

  const ClubMilestone({
    required this.id,
    required this.clubId,
    this.bookHistoryId,
    required this.milestonePct,
    this.title,
    this.unlockedAt,
    required this.createdAt,
  });

  bool get isUnlocked => unlockedAt != null;

  String get label => title ?? '$milestonePct%';

  IconData get icon {
    switch (milestonePct) {
      case 25:  return Icons.eco_outlined;
      case 50:  return Icons.menu_book_outlined;
      case 75:  return Icons.local_fire_department_outlined;
      case 100: return Icons.emoji_events_outlined;
      default:  return Icons.flag_outlined;
    }
  }

  factory ClubMilestone.fromMap(Map<String, dynamic> map) => ClubMilestone(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        bookHistoryId: map['book_history_id'] as String?,
        milestonePct: (map['milestone_pct'] as num).toInt(),
        title: map['title'] as String?,
        unlockedAt: map['unlocked_at'] != null
            ? DateTime.parse(map['unlocked_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, clubId, milestonePct];
}

// ── Tópico de discussão de um marco ──────────────────────────────────────────

class ClubMilestoneTopic extends Equatable {
  final String id;
  final String milestoneId;
  final String clubId;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? parentId;
  final String content;
  final String spoilerLevel; // 'none' | 'partial' | 'full'
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClubMilestoneTopic({
    required this.id,
    required this.milestoneId,
    required this.clubId,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    this.parentId,
    required this.content,
    this.spoilerLevel = 'none',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSpoiler => spoilerLevel != 'none';
  bool get isReply => parentId != null;

  factory ClubMilestoneTopic.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    return ClubMilestoneTopic(
      id: map['id'] as String,
      milestoneId: map['milestone_id'] as String,
      clubId: map['club_id'] as String,
      userId: map['user_id'] as String,
      userName: profile['name'] as String?,
      userAvatarUrl: profile['avatar_url'] as String?,
      parentId: map['parent_id'] as String?,
      content: map['content'] as String,
      spoilerLevel: map['spoiler_level'] as String? ?? 'none',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, milestoneId, userId, createdAt];
}

// ── Desafio do Clube ──────────────────────────────────────────────────────────

enum ChallengeGoalType { pages, minutes, checkins, sessions }

extension ChallengeGoalTypeX on ChallengeGoalType {
  String get dbValue => name;

  String get label {
    switch (this) {
      case ChallengeGoalType.pages:    return 'Páginas';
      case ChallengeGoalType.minutes:  return 'Minutos';
      case ChallengeGoalType.checkins: return 'Dias de leitura';
      case ChallengeGoalType.sessions: return 'Sessões';
    }
  }

  String get unit {
    switch (this) {
      case ChallengeGoalType.pages:    return 'pág.';
      case ChallengeGoalType.minutes:  return 'min';
      case ChallengeGoalType.checkins: return 'dias';
      case ChallengeGoalType.sessions: return 'sessões';
    }
  }

  static ChallengeGoalType fromDb(String v) =>
      ChallengeGoalType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ChallengeGoalType.pages,
      );
}

enum ChallengeStatus { active, finished, cancelled }

extension ChallengeStatusX on ChallengeStatus {
  String get dbValue => name;

  static ChallengeStatus fromDb(String v) =>
      ChallengeStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ChallengeStatus.active,
      );
}

class ClubChallenge extends Equatable {
  final String id;
  final String clubId;
  final String createdBy;
  final String title;
  final String? description;
  final ChallengeGoalType goalType;
  final int goalValue;
  final DateTime startsAt;
  final DateTime endsAt;
  final ChallengeStatus status;
  final DateTime createdAt;

  const ClubChallenge({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.goalType,
    required this.goalValue,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == ChallengeStatus.active;

  bool get isOngoing =>
      isActive &&
      DateTime.now().isAfter(startsAt) &&
      DateTime.now().isBefore(endsAt);

  Duration get timeLeft => endsAt.difference(DateTime.now());

  String get daysLeftLabel {
    final days = timeLeft.inDays;
    if (days < 0) return 'Encerrado';
    if (days == 0) return 'Último dia!';
    return '$days dias restantes';
  }

  factory ClubChallenge.fromMap(Map<String, dynamic> map) => ClubChallenge(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        createdBy: map['created_by'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        goalType: ChallengeGoalTypeX.fromDb(map['goal_type'] as String),
        goalValue: (map['goal_value'] as num).toInt(),
        startsAt: DateTime.parse(map['starts_at'] as String),
        endsAt: DateTime.parse(map['ends_at'] as String),
        status: ChallengeStatusX.fromDb(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, clubId, status];
}

// ── Progresso individual no desafio ──────────────────────────────────────────

class ChallengeProgressEntry extends Equatable {
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final int currentValue;
  final int goalValue;
  final double pctComplete;
  final int rank;

  const ChallengeProgressEntry({
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.currentValue,
    required this.goalValue,
    required this.pctComplete,
    required this.rank,
  });

  bool get isComplete => pctComplete >= 100;

  String podiumLabel() {
    switch (rank) {
      case 1: return '1°';
      case 2: return '2°';
      case 3: return '3°';
      default: return '#$rank';
    }
  }

  factory ChallengeProgressEntry.fromMap(Map<String, dynamic> map) =>
      ChallengeProgressEntry(
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        currentValue: (map['current_value'] as num).toInt(),
        goalValue: (map['goal_value'] as num).toInt(),
        pctComplete: (map['pct_complete'] as num).toDouble(),
        rank: (map['rank'] as num).toInt(),
      );

  @override
  List<Object?> get props => [userId, rank, pctComplete];
}
