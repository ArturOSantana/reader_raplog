/// Interface que desacopla a plataforma de qualquer fonte de metadados de livros.
///
/// Hoje: Google Books.
/// Futuro: Open Library, ISBNdb, Amazon, editoras.
///
/// Nenhuma outra camada do app deve importar o cliente Google Books diretamente
/// — apenas esta interface.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

class BookMetadata {
  final String id;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? publisher;
  final String? publishedDate;
  final String? description;
  final String? isbn10;
  final String? isbn13;
  final String? coverUrl;
  final int? pageCount;
  final List<String> categories;
  final String? language;
  final String sourceProvider;

  const BookMetadata({
    required this.id,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.publisher,
    this.publishedDate,
    this.description,
    this.isbn10,
    this.isbn13,
    this.coverUrl,
    this.pageCount,
    this.categories = const [],
    this.language,
    required this.sourceProvider,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class BookMetadataProvider {
  /// Pesquisa livros por termo livre (título, autor, ISBN).
  Future<List<BookMetadata>> search(String query, {int maxResults = 20});

  /// Busca um livro pelo ID específico do provider.
  Future<BookMetadata?> fetchById(String id);

  /// Busca por ISBN-10 ou ISBN-13.
  Future<BookMetadata?> fetchByIsbn(String isbn);

  /// Identificador do provider para fins de log e auditoria.
  String get providerName;
}
