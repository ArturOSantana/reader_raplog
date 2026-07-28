/// Interface da Search Platform da plataforma Lumen.
///
/// Desacopla a lógica de busca de qualquer implementação concreta
/// (Supabase FTS, Algolia, Typesense, Meilisearch, etc.).
library;

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

enum SearchEntityType { book, author, club, user, review, list }

class SearchResult {
  final String id;
  final SearchEntityType type;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double score;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.score = 1.0,
  });
}

class UnifiedSearchResult {
  final List<SearchResult> books;
  final List<SearchResult> authors;
  final List<SearchResult> clubs;
  final List<SearchResult> users;
  final List<SearchResult> reviews;
  final List<SearchResult> lists;

  const UnifiedSearchResult({
    this.books   = const [],
    this.authors = const [],
    this.clubs   = const [],
    this.users   = const [],
    this.reviews = const [],
    this.lists   = const [],
  });

  bool get isEmpty =>
      books.isEmpty && authors.isEmpty && clubs.isEmpty &&
      users.isEmpty && reviews.isEmpty && lists.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class SearchProvider {
  /// Busca unificada: retorna resultados agrupados por tipo.
  Future<UnifiedSearchResult> search(
    String query, {
    List<SearchEntityType> types = SearchEntityType.values,
    int limit = 10,
  });

  /// Sugestões de autocomplete enquanto o usuário digita.
  Future<List<String>> autocomplete(String prefix, {int limit = 8});

  /// Registra a pesquisa no histórico do usuário autenticado.
  Future<void> recordSearch(String query, {String? userId});

  /// Retorna os termos mais pesquisados em um período.
  Future<List<String>> trending({int limit = 10});
}
