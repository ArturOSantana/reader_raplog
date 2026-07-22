class WishlistItem {
  final String id;
  final String userId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? notes;
  final bool acquired;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.title,
    this.author,
    this.coverUrl,
    this.notes,
    required this.acquired,
    required this.createdAt,
  });

  factory WishlistItem.fromMap(Map<String, dynamic> map) => WishlistItem(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        author: map['author'] as String?,
        coverUrl: map['cover_url'] as String?,
        notes: map['notes'] as String?,
        acquired: map['acquired'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
