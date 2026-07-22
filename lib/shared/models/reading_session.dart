import 'package:equatable/equatable.dart';

class ReadingSession extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final int? startPage;
  final int? endPage;
  final int? pagesRead;
  final String? notes;
  final DateTime createdAt;

  const ReadingSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.startPage,
    this.endPage,
    this.pagesRead,
    this.notes,
    required this.createdAt,
  });

  factory ReadingSession.fromMap(Map<String, dynamic> map) => ReadingSession(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        bookId: map['book_id'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'] as String)
            : null,
        durationMinutes: map['duration_minutes'] as int?,
        startPage: map['start_page'] as int?,
        endPage: map['end_page'] as int?,
        pagesRead: map['pages_read'] as int?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'book_id': bookId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'start_page': startPage,
        'end_page': endPage,
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, userId, bookId, startedAt];
}
