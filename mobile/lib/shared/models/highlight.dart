class Highlight {
  final String id;
  final String userId;
  final String bookId;
  final String text;
  final int? pageNumber;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.text,
    this.pageNumber,
    required this.createdAt,
  });

  factory Highlight.fromMap(Map<String, dynamic> map) => Highlight(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        bookId: map['book_id'] as String,
        text: map['text'] as String,
        pageNumber: map['page_number'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
