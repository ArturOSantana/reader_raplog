/// Modelo unificado retornado por qualquer fonte de busca.
class BookSearchResult {
  final String title;
  final String? author;
  final String? coverUrl;
  final int? totalPages;
  final String? genre;
  final String? publisher;
  final String? isbn;
  /// Fonte que originou o resultado, para debug / preferência de capa.
  final String source;

  const BookSearchResult({
    required this.title,
    required this.source,
    this.author,
    this.coverUrl,
    this.totalPages,
    this.genre,
    this.publisher,
    this.isbn,
  });

  /// Chave de deduplicação: normaliza título + autor.
  String get dedupeKey {
    final t = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final a = (author ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return '$t|$a';
  }

  BookSearchResult copyWith({String? coverUrl}) => BookSearchResult(
        title: title,
        source: source,
        author: author,
        coverUrl: coverUrl ?? this.coverUrl,
        totalPages: totalPages,
        genre: genre,
        publisher: publisher,
        isbn: isbn,
      );
}
