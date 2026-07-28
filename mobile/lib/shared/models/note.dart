import 'package:equatable/equatable.dart';

enum NoteType { observation, reflection, highlight }

extension NoteTypeX on NoteType {
  String get label {
    switch (this) {
      case NoteType.observation:
        return 'Observacao';
      case NoteType.reflection:
        return 'Reflexao';
      case NoteType.highlight:
        return 'Destaque';
    }
  }

  String get dbValue {
    switch (this) {
      case NoteType.observation:
        return 'observation';
      case NoteType.reflection:
        return 'reflection';
      case NoteType.highlight:
        return 'highlight';
    }
  }

  static NoteType fromDb(String value) {
    switch (value) {
      case 'reflection':
        return NoteType.reflection;
      case 'highlight':
        return NoteType.highlight;
      default:
        return NoteType.observation;
    }
  }
}

class Note extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final NoteType type;
  final String content;
  final int? pageNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.type,
    required this.content,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        bookId: map['book_id'] as String,
        type: NoteTypeX.fromDb(map['type'] as String),
        content: map['content'] as String,
        pageNumber: map['page_number'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  @override
  List<Object?> get props => [id, bookId, type, content];
}
