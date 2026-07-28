import 'package:equatable/equatable.dart';

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
