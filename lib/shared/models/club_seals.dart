import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ── Tipo de Selo ───────────────────────────────────────────────────────────────
//
// Selos são atribuídos automaticamente pelo sistema com base em eventos
// concretos (conclusão de desafio, mais páginas no ciclo, streak coletivo).
// O tipo 'custom' foi removido — selos manuais sem critério objetivo criam
// inconsistência e manutenção desnecessária para o admin.

enum SealType {
  bestReader,
  bestReviewer,
  mostConsistent,
  bestComment,
  mostEngaged,
  challengeWinner,
}

extension SealTypeX on SealType {
  String get dbValue {
    switch (this) {
      case SealType.bestReader:       return 'best_reader';
      case SealType.bestReviewer:     return 'best_reviewer';
      case SealType.mostConsistent:   return 'most_consistent';
      case SealType.bestComment:      return 'best_comment';
      case SealType.mostEngaged:      return 'most_engaged';
      case SealType.challengeWinner:  return 'challenge_winner';
    }
  }

  String get label {
    switch (this) {
      case SealType.bestReader:       return 'Leitor do Ciclo';
      case SealType.bestReviewer:     return 'Melhor Resenha';
      case SealType.mostConsistent:   return 'Mais Consistente';
      case SealType.bestComment:      return 'Melhor Comentário';
      case SealType.mostEngaged:      return 'Mais Engajado';
      case SealType.challengeWinner:  return 'Vencedor do Desafio';
    }
  }

  IconData get icon {
    switch (this) {
      case SealType.bestReader:       return Icons.menu_book_rounded;
      case SealType.bestReviewer:     return Icons.edit_note_rounded;
      case SealType.mostConsistent:   return Icons.local_fire_department_rounded;
      case SealType.bestComment:      return Icons.chat_bubble_outline_rounded;
      case SealType.mostEngaged:      return Icons.star_rounded;
      case SealType.challengeWinner:  return Icons.emoji_events_rounded;
    }
  }

  static SealType fromDb(String v) => SealType.values.firstWhere(
        (e) => e.dbValue == v,
        // Fallback gracioso: qualquer tipo desconhecido (ex: 'custom' legado)
        // é mapeado para mostEngaged para não quebrar a UI.
        orElse: () => SealType.mostEngaged,
      );
}

// ── Modelo ClubSeal ────────────────────────────────────────────────────────────

class ClubSeal extends Equatable {
  final String id;
  final String clubId;
  final SealType sealType;
  final String? description;
  final DateTime awardedAt;

  // Agraciado
  final String awardedTo;
  final String? awardedToName;
  final String? awardedToAvatar;

  // Concedente
  final String awardedBy;
  final String? awardedByName;

  // Contexto opcional
  final String? bookHistoryId;
  final String? challengeId;

  const ClubSeal({
    required this.id,
    required this.clubId,
    required this.sealType,
    this.description,
    required this.awardedAt,
    required this.awardedTo,
    this.awardedToName,
    this.awardedToAvatar,
    required this.awardedBy,
    this.awardedByName,
    this.bookHistoryId,
    this.challengeId,
  });

  /// Título exibido: prioridade → description → label do tipo.
  String get displayTitle {
    if (description?.isNotEmpty == true) return description!;
    return sealType.label;
  }

  factory ClubSeal.fromMap(Map<String, dynamic> map) => ClubSeal(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        sealType: SealTypeX.fromDb(map['seal_type'] as String),
        description: map['description'] as String?,
        awardedAt: DateTime.parse(map['awarded_at'] as String),
        awardedTo: map['awarded_to'] as String,
        awardedToName: map['awarded_to_name'] as String?,
        awardedToAvatar: map['awarded_to_avatar'] as String?,
        awardedBy: map['awarded_by'] as String,
        awardedByName: map['awarded_by_name'] as String?,
        bookHistoryId: map['book_history_id'] as String?,
        challengeId: map['challenge_id'] as String?,
      );

  @override
  List<Object?> get props => [id, clubId, sealType, awardedTo, awardedAt];
}

// ── Resumo de membro (usado em selos e na detail screen) ─────────────────────

class ClubMemberSummary {
  final String id;
  final String name;
  final String? avatarUrl;

  const ClubMemberSummary({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}
