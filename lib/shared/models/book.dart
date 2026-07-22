import 'package:equatable/equatable.dart';

enum BookStatus { reading, wantToRead, read, abandoned }

extension BookStatusX on BookStatus {
  String get label {
    switch (this) {
      case BookStatus.reading:
        return 'Lendo';
      case BookStatus.wantToRead:
        return 'Quero Ler';
      case BookStatus.read:
        return 'Lido';
      case BookStatus.abandoned:
        return 'Abandonado';
    }
  }

  String get dbValue {
    switch (this) {
      case BookStatus.reading:
        return 'reading';
      case BookStatus.wantToRead:
        return 'want_to_read';
      case BookStatus.read:
        return 'read';
      case BookStatus.abandoned:
        return 'abandoned';
    }
  }

  static BookStatus fromDb(String value) {
    switch (value) {
      case 'reading':
        return BookStatus.reading;
      case 'want_to_read':
        return BookStatus.wantToRead;
      case 'read':
        return BookStatus.read;
      case 'abandoned':
        return BookStatus.abandoned;
      default:
        return BookStatus.wantToRead;
    }
  }
}

class Book extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? author;
  final String? coverUrl;
  final int? totalPages;
  final String? genre;
  final String? publisher;
  final BookStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? rating;
  final int? currentPage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Book({
    required this.id,
    required this.userId,
    required this.title,
    this.author,
    this.coverUrl,
    this.totalPages,
    this.genre,
    this.publisher,
    required this.status,
    this.startDate,
    this.endDate,
    this.rating,
    this.currentPage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        author: map['author'] as String?,
        coverUrl: map['cover_url'] as String?,
        totalPages: map['total_pages'] as int?,
        genre: map['genre'] as String?,
        publisher: map['publisher'] as String?,
        status: BookStatusX.fromDb(map['status'] as String),
        startDate: map['start_date'] != null
            ? DateTime.parse(map['start_date'] as String)
            : null,
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        rating: map['rating'] as int?,
        currentPage: map['current_page'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'author': author,
        'cover_url': coverUrl,
        'total_pages': totalPages,
        'genre': genre,
        'publisher': publisher,
        'status': status.dbValue,
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'rating': rating,
        'current_page': currentPage,
      };

  Book copyWith({
    String? title,
    String? author,
    String? coverUrl,
    int? totalPages,
    String? genre,
    String? publisher,
    BookStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? rating,
    int? currentPage,
  }) =>
      Book(
        id: id,
        userId: userId,
        title: title ?? this.title,
        author: author ?? this.author,
        coverUrl: coverUrl ?? this.coverUrl,
        totalPages: totalPages ?? this.totalPages,
        genre: genre ?? this.genre,
        publisher: publisher ?? this.publisher,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        rating: rating ?? this.rating,
        currentPage: currentPage ?? this.currentPage,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, userId, title, author, status, rating, currentPage];
}
