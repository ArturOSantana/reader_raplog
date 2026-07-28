/// Versão com cache do [BookSearchService].
///
/// Adiciona cache entre o chamador e as APIs externas:
///
/// ```
/// Busca solicitada
///   ↓
/// CacheProvider (SharedPrefs)
///   ↓ miss
/// GoogleBooksService + OpenLibraryService (paralelo)
///   ↓
/// Merge + deduplica
///   ↓
/// Salva no cache (TTL: 6h por padrão)
///   ↓
/// Retorna ao chamador
/// ```
///
/// Mantém [BookSearchService] original intocado (compatibilidade).
library;

import '../../../core/providers/cache_provider.dart';
import 'book_search_result.dart';
import 'book_search_service.dart';

class CachedBookSearchService {
  CachedBookSearchService({
    required BookSearchService delegate,
    required CacheProvider cache,
    this.searchTtl = const Duration(hours: 6),
  })  : _delegate = delegate,
        _cache = cache;

  final BookSearchService _delegate;
  final CacheProvider _cache;
  final Duration searchTtl;

  static const _prefix = 'book_search:';

  Future<List<BookSearchResult>> search(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final key = '$_prefix$q';

    // 1. Cache hit
    final cached = await _cache.get<List<dynamic>>(key);
    if (cached != null) {
      return cached.cast<Map<String, dynamic>>().map(_fromMap).toList();
    }

    // 2. Cache miss — consulta as APIs
    final results = await _delegate.search(q);

    // 3. Persiste apenas se houver resultados
    if (results.isNotEmpty) {
      await _cache.set(key, results.map(_toMap).toList(), ttl: searchTtl);
    }

    return results;
  }

  // ── Serialização ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _toMap(BookSearchResult r) => {
        'title': r.title,
        'author': r.author,
        'coverUrl': r.coverUrl,
        'totalPages': r.totalPages,
        'genre': r.genre,
        'publisher': r.publisher,
        'isbn': r.isbn,
        'source': r.source,
      };

  static BookSearchResult _fromMap(Map<String, dynamic> m) => BookSearchResult(
        title: m['title'] as String? ?? '',
        author: m['author'] as String?,
        coverUrl: m['coverUrl'] as String?,
        totalPages: m['totalPages'] as int?,
        genre: m['genre'] as String?,
        publisher: m['publisher'] as String?,
        isbn: m['isbn'] as String?,
        source: m['source'] as String? ?? 'cache',
      );
}
