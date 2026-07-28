import 'package:equatable/equatable.dart';

/// Status possíveis de uma sessão de leitura.
enum SessionStatus { active, paused, finished }

/// Objetivo opcional que o usuário pode definir ao iniciar a sessão.
enum SessionGoal { byTime, byPage, dailyGoal, freeReading }

/// Humor do leitor ao finalizar a sessão (base para Diário do Livro — V3).
enum SessionMood { happy, neutral, confused, bored, excited }

extension SessionMoodX on SessionMood {
  String get dbValue => name;

  String get emoji {
    switch (this) {
      case SessionMood.happy:    return '😊';
      case SessionMood.neutral:  return '😐';
      case SessionMood.confused: return '🤔';
      case SessionMood.bored:    return '😴';
      case SessionMood.excited:  return '🤩';
    }
  }

  String get label {
    switch (this) {
      case SessionMood.happy:    return 'Animado';
      case SessionMood.neutral:  return 'Neutro';
      case SessionMood.confused: return 'Confuso';
      case SessionMood.bored:    return 'Entediado';
      case SessionMood.excited:  return 'Empolgado';
    }
  }

  static SessionMood? fromDb(String? v) {
    if (v == null) return null;
    return SessionMood.values.firstWhere(
      (e) => e.name == v,
      orElse: () => SessionMood.neutral,
    );
  }
}

class ReadingSession extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  /// Segundos totais já pausados (acumula cada intervalo de pausa).
  final int pausedDurationSeconds;
  final int? startPage;
  final int? endPage;
  final int? pagesRead;
  final String? notes;
  final SessionStatus status;
  /// Objetivo selecionado antes de iniciar (null = leitura livre).
  final SessionGoal? sessionGoal;
  /// Valor numérico do objetivo: minutos ou número de página destino.
  final int? goalValue;
  /// Humor do leitor ao finalizar a sessão (opcional).
  final SessionMood? mood;
  /// Impressão rápida da sessão — base para o Diário do Livro. Máx. 500 chars.
  final String? miniReview;
  final DateTime createdAt;

  const ReadingSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.pausedDurationSeconds = 0,
    this.startPage,
    this.endPage,
    this.pagesRead,
    this.notes,
    this.status = SessionStatus.active,
    this.sessionGoal,
    this.goalValue,
    this.mood,
    this.miniReview,
    required this.createdAt,
  });

  ReadingSession copyWith({
    DateTime? endedAt,
    int? durationMinutes,
    int? pausedDurationSeconds,
    int? endPage,
    int? pagesRead,
    String? notes,
    SessionStatus? status,
    SessionGoal? sessionGoal,
    int? goalValue,
    SessionMood? mood,
    String? miniReview,
  }) =>
      ReadingSession(
        id: id,
        userId: userId,
        bookId: bookId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        pausedDurationSeconds:
            pausedDurationSeconds ?? this.pausedDurationSeconds,
        startPage: startPage,
        endPage: endPage ?? this.endPage,
        pagesRead: pagesRead ?? this.pagesRead,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        sessionGoal: sessionGoal ?? this.sessionGoal,
        goalValue: goalValue ?? this.goalValue,
        mood: mood ?? this.mood,
        miniReview: miniReview ?? this.miniReview,
        createdAt: createdAt,
      );

  factory ReadingSession.fromMap(Map<String, dynamic> map) => ReadingSession(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        bookId: map['book_id'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'] as String)
            : null,
        durationMinutes: map['duration_minutes'] as int?,
        pausedDurationSeconds: (map['paused_duration_seconds'] as int?) ?? 0,
        startPage: map['start_page'] as int?,
        endPage: map['end_page'] as int?,
        pagesRead: map['pages_read'] as int?,
        notes: map['notes'] as String?,
        status: SessionStatus.values.firstWhere(
          (s) => s.name == (map['status'] as String? ?? 'active'),
          orElse: () => SessionStatus.active,
        ),
        sessionGoal: map['session_goal'] != null
            ? SessionGoal.values.firstWhere(
                (g) => g.name == map['session_goal'],
                orElse: () => SessionGoal.freeReading,
              )
            : null,
        goalValue: map['goal_value'] as int?,
        mood: SessionMoodX.fromDb(map['mood'] as String?),
        miniReview: map['mini_review'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'book_id': bookId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'paused_duration_seconds': pausedDurationSeconds,
        'start_page': startPage,
        'end_page': endPage,
        'pages_read': pagesRead,
        'notes': notes,
        'status': status.name,
        'session_goal': sessionGoal?.name,
        'goal_value': goalValue,
        'mood': mood?.dbValue,
        'mini_review': miniReview,
      };

  @override
  List<Object?> get props => [id, userId, bookId, startedAt, mood];
}
