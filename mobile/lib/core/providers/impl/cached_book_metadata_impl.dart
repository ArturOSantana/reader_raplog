/// Cache Layer para [BookMetadataProvider].
///
/// Implementa o padrão Cache-Aside:
///
/// ```
/// Usuário pesquisa
///   ↓
/// CacheProvider (SharedPrefs / Redis)
///   ↓ miss
/// Provider real (Google Books, Open Library…)
///   ↓
/// BookMetadata normalizado
///   ↓
/// Salva no cache (TTL configurável)
///   ↓
/// Responde ao chamador
/// ```
///
/// Nunca consulta o provider real duas vezes para a mesma query/id/isbn.
library;

import '../book_metadata_provider.dart';
import '../cache_provider.dart';

class CachedBookMetadataImpl implements BookMetadataProvider {
  CachedBookMetadataImpl({
    required BookMetadataProvider delegate,
    required CacheProvider cache,
    Duration searchTtl    = const Duration(hours: 6),
    Duration fetchByIdTtl = const Duration(days: 30),
  })  : _delegate = delegate,
        _cache = cache,
        _searchTtl = searchTtl,
        _fetchByIdTtl = fetchByIdTtl;

  final BookMetadataProvider _delegate;
  final CacheProvider _cache;
  final Duration _searchTtl;
  final Duration _fetchByIdTtl;

  @override
  String get providerName => 'cached::${_delegate.providerName}';

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  Future<List<BookMetadata>> search(String query, {int maxResults = 20}) async {
    final key = 'gbooks:q:${query.toLowerCase().trim()}:$maxResults';

    final cached = await _cache.get<List<dynamic>>(key);
    if (cached != null) {
      return cached
          .cast<Map<String, dynamic>>()
          .map(_fromMap)
          .toList();
    }

    final results = await _delegate.search(query, maxResults: maxResults);
    if (results.isNotEmpty) {
      await _cache.set(key, results.map(_toMap).toList(), ttl: _searchTtl);
    }
    return results;
  }

  // ── Fetch by ID ───────────────────────────────────────────────────────────

  @override
  Future<BookMetadata?> fetchById(String id) async {
    final key = 'gbooks:id:$id';
    final cached = await _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return _fromMap(cached);

    final result = await _delegate.fetchById(id);
    if (result != null) {
      await _cache.set(key, _toMap(result), ttl: _fetchByIdTtl);
    }
    return result;
  }

  // ── Fetch by ISBN ─────────────────────────────────────────────────────────

  @override
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[\s-]'), '');
    final key = 'gbooks:isbn:$clean';
    final cached = await _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return _fromMap(cached);

    final result = await _delegate.fetchByIsbn(isbn);
    if (result != null) {
      await _cache.set(key, _toMap(result), ttl: _fetchByIdTtl);
    }
    return result;
  }

  // ── Serialização ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _toMap(BookMetadata m) => {
        'id': m.id,
        'title': m.title,
        'subtitle': m.subtitle,
        'authors': m.authors,
        'publisher': m.publisher,
        'publishedDate': m.publishedDate,
        'description': m.description,
        'isbn10': m.isbn10,
        'isbn13': m.isbn13,
        'coverUrl': m.coverUrl,
        'pageCount': m.pageCount,
        'categories': m.categories,
        'language': m.language,
        'sourceProvider': m.sourceProvider,
      };

  static BookMetadata _fromMap(Map<String, dynamic> m) => BookMetadata(
        id: m['id'] as String,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String?,
        authors: List<String>.from(m['authors'] as List? ?? []),
        publisher: m['publisher'] as String?,
        publishedDate: m['publishedDate'] as String?,
        description: m['description'] as String?,
        isbn10: m['isbn10'] as String?,
        isbn13: m['isbn13'] as String?,
        coverUrl: m['coverUrl'] as String?,
        pageCount: m['pageCount'] as int?,
        categories: List<String>.from(m['categories'] as List? ?? []),
        language: m['language'] as String?,
        sourceProvider: m['sourceProvider'] as String? ?? 'cache',
      );
}
