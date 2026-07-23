import 'package:equatable/equatable.dart';

// ── Aposta Amistosa ───────────────────────────────────────────────────────────

enum BetStakeType { pizza, cafe, livro, valePresente, dinheiroRegistrado, outro }

extension BetStakeTypeX on BetStakeType {
  String get dbValue {
    switch (this) {
      case BetStakeType.pizza:               return 'pizza';
      case BetStakeType.cafe:                return 'cafe';
      case BetStakeType.livro:               return 'livro';
      case BetStakeType.valePresente:        return 'vale_presente';
      case BetStakeType.dinheiroRegistrado:  return 'dinheiro_registrado';
      case BetStakeType.outro:               return 'outro';
    }
  }

  String get emoji {
    switch (this) {
      case BetStakeType.pizza:              return '🍕';
      case BetStakeType.cafe:               return '☕';
      case BetStakeType.livro:              return '📚';
      case BetStakeType.valePresente:       return '🎁';
      case BetStakeType.dinheiroRegistrado: return '💵';
      case BetStakeType.outro:              return '🤝';
    }
  }

  static BetStakeType fromDb(String v) =>
      BetStakeType.values.firstWhere(
        (e) => e.dbValue == v,
        orElse: () => BetStakeType.outro,
      );
}

enum BetStatus { open, closed, resolved }

extension BetStatusX on BetStatus {
  String get dbValue => name;

  static BetStatus fromDb(String v) =>
      BetStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => BetStatus.open,
      );
}

class ClubBet extends Equatable {
  final String id;
  final String clubId;
  final String createdBy;
  final String description;
  final BetStakeType stakeType;
  final String? stakeDescription;
  final String? resolutionCriteria;
  final String sideALabel;
  final String sideBLabel;
  final BetStatus status;
  final String? winnerSide;      // 'a' | 'b' | null
  final DateTime? resolvesAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final DateTime createdAt;

  const ClubBet({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.description,
    required this.stakeType,
    this.stakeDescription,
    this.resolutionCriteria,
    required this.sideALabel,
    required this.sideBLabel,
    required this.status,
    this.winnerSide,
    this.resolvesAt,
    this.resolvedAt,
    this.resolvedBy,
    required this.createdAt,
  });

  bool get isOpen     => status == BetStatus.open;
  bool get isResolved => status == BetStatus.resolved;

  String? get winnerLabel {
    if (winnerSide == 'a') return sideALabel;
    if (winnerSide == 'b') return sideBLabel;
    return null;
  }

  factory ClubBet.fromMap(Map<String, dynamic> map) => ClubBet(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        createdBy: map['created_by'] as String,
        description: map['description'] as String,
        stakeType: BetStakeTypeX.fromDb(map['stake_type'] as String),
        stakeDescription: map['stake_description'] as String?,
        resolutionCriteria: map['resolution_criteria'] as String?,
        sideALabel: map['side_a_label'] as String? ?? 'Sim',
        sideBLabel: map['side_b_label'] as String? ?? 'Não',
        status: BetStatusX.fromDb(map['status'] as String),
        winnerSide: map['winner_side'] as String?,
        resolvesAt: map['resolves_at'] != null
            ? DateTime.parse(map['resolves_at'] as String)
            : null,
        resolvedAt: map['resolved_at'] != null
            ? DateTime.parse(map['resolved_at'] as String)
            : null,
        resolvedBy: map['resolved_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, clubId, status];
}

// ── Participante da aposta ────────────────────────────────────────────────────

class ClubBetParticipant extends Equatable {
  final String betId;
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final String side;  // 'a' | 'b'
  final DateTime joinedAt;

  const ClubBetParticipant({
    required this.betId,
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.side,
    required this.joinedAt,
  });

  factory ClubBetParticipant.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>? ?? {};
    return ClubBetParticipant(
      betId: map['bet_id'] as String,
      userId: map['user_id'] as String,
      userName: profile['name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      side: map['side'] as String,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  @override
  List<Object?> get props => [betId, userId];
}

// ── Leaderboard de apostas ───────────────────────────────────────────────────

class BetLeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String? userName;
  final String? avatarUrl;
  final int totalBets;
  final int totalWins;
  final int totalLosses;
  final double winRatePct;

  const BetLeaderboardEntry({
    required this.rank,
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.totalBets,
    required this.totalWins,
    required this.totalLosses,
    required this.winRatePct,
  });

  bool get isOnPodium => rank <= 3;

  String get podiumEmoji {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '#$rank';
    }
  }

  factory BetLeaderboardEntry.fromMap(Map<String, dynamic> map) =>
      BetLeaderboardEntry(
        rank: (map['rank'] as num).toInt(),
        userId: map['user_id'] as String,
        userName: map['user_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        totalBets: (map['total_bets'] as num).toInt(),
        totalWins: (map['total_wins'] as num).toInt(),
        totalLosses: (map['total_losses'] as num).toInt(),
        winRatePct: (map['win_rate_pct'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [rank, userId, winRatePct];
}

// ── Votação Livre (Open Poll) ─────────────────────────────────────────────────

enum OpenPollStatus { open, closed }

extension OpenPollStatusX on OpenPollStatus {
  String get dbValue => name;

  static OpenPollStatus fromDb(String v) =>
      OpenPollStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OpenPollStatus.open,
      );
}

/// Opção individual de uma votação livre.
class OpenPollOption {
  final String id;
  final String label;

  const OpenPollOption({required this.id, required this.label});

  factory OpenPollOption.fromMap(Map<String, dynamic> map) => OpenPollOption(
        id: map['id'] as String,
        label: map['label'] as String,
      );

  Map<String, dynamic> toMap() => {'id': id, 'label': label};
}

class ClubOpenPoll extends Equatable {
  final String id;
  final String clubId;
  final String createdBy;
  final String question;
  final List<OpenPollOption> options;
  final bool multiSelect;
  final OpenPollStatus status;
  final DateTime opensAt;
  final DateTime? closesAt;
  final DateTime createdAt;

  const ClubOpenPoll({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.question,
    required this.options,
    required this.multiSelect,
    required this.status,
    required this.opensAt,
    this.closesAt,
    required this.createdAt,
  });

  bool get isOpen => status == OpenPollStatus.open;

  factory ClubOpenPoll.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'] as List<dynamic>? ?? [];
    return ClubOpenPoll(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      createdBy: map['created_by'] as String,
      question: map['question'] as String,
      options: rawOptions
          .map((o) => OpenPollOption.fromMap(o as Map<String, dynamic>))
          .toList(),
      multiSelect: map['multi_select'] as bool? ?? false,
      status: OpenPollStatusX.fromDb(map['status'] as String),
      opensAt: DateTime.parse(map['opens_at'] as String),
      closesAt: map['closes_at'] != null
          ? DateTime.parse(map['closes_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, clubId, status];
}

// ── Resultado de uma opção da votação livre ───────────────────────────────────

class OpenPollOptionResult extends Equatable {
  final String optionId;
  final String optionLabel;
  final int voteCount;
  final double pct;
  final bool votedByMe;

  const OpenPollOptionResult({
    required this.optionId,
    required this.optionLabel,
    required this.voteCount,
    required this.pct,
    required this.votedByMe,
  });

  factory OpenPollOptionResult.fromMap(Map<String, dynamic> map) =>
      OpenPollOptionResult(
        optionId: map['option_id'] as String,
        optionLabel: map['option_label'] as String,
        voteCount: (map['vote_count'] as num).toInt(),
        pct: (map['pct'] as num).toDouble(),
        votedByMe: map['voted_by_me'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [optionId, voteCount, votedByMe];
}
