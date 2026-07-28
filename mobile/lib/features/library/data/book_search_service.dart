import 'dart:async';
import 'book_search_result.dart';
import 'google_books_service.dart';
import 'open_library_service.dart';

/// Agrega resultados de múltiplas fontes, deduplica e rankeia.
///
/// Fontes utilizadas:
/// 1. **Google Books** — melhor cobertura, capas em alta resolução
/// 2. **Open Library** (openlibrary.org) — gratuito, sem chave de API,
///    excelente para livros brasileiros e ISBNs físicos
///
/// A deduplicação é feita pelo par (título normalizado + autor normalizado).
/// Quando o mesmo livro aparece nas duas fontes, o resultado do Google Books
/// é preferido para capa; os demais campos são completados com a Open Library
/// caso estejam ausentes.
class BookSearchService {
  BookSearchService({String? googleApiKey}) : _googleApiKey = googleApiKey;

  final String? _googleApiKey;
  final _google = GoogleBooksService();
  final _openLib = OpenLibraryService();

  Future<List<BookSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    // Dispara as duas buscas em paralelo; se uma falhar o outro continua.
    final (googleResults, openLibResults) = await (
      _safeSearch(() => _google.search(query, apiKey: _googleApiKey)),
      _safeSearch(() => _openLib.search(query)),
    ).wait;

    return _merge(googleResults, openLibResults);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static Future<List<BookSearchResult>> _safeSearch(
    Future<List<BookSearchResult>> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (_) {
      return [];
    }
  }

  /// Mescla resultados dando prioridade ao Google Books.
  /// Deduplicação por [BookSearchResult.dedupeKey].
  static List<BookSearchResult> _merge(
    List<BookSearchResult> google,
    List<BookSearchResult> openLib,
  ) {
    final seen = <String, BookSearchResult>{};

    // Primeiro passa o Google (prioridade)
    for (final r in google) {
      seen[r.dedupeKey] = r;
    }

    // Depois a Open Library — só adiciona se não duplicado,
    // mas aproveita dados ausentes (capa, páginas, gênero) do Google.
    for (final r in openLib) {
      final key = r.dedupeKey;
      if (seen.containsKey(key)) {
        final existing = seen[key]!;
        // Preenche capa ausente com a da Open Library
        if (existing.coverUrl == null && r.coverUrl != null) {
          seen[key] = existing.copyWith(coverUrl: r.coverUrl);
        }
      } else {
        seen[key] = r;
      }
    }

    return seen.values.toList();
  }
}
