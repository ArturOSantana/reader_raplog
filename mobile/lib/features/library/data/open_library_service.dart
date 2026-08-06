import 'dart:convert';
import 'package:http/http.dart' as http;
import 'book_search_result.dart';

/// Integração com a Open Library (openlibrary.org) — 100% gratuita, sem chave.
///
/// Docs: https://openlibrary.org/dev/docs/api#anchor_searchapi
class OpenLibraryService {
  static const _searchUrl = 'https://openlibrary.org/search.json';
  static const _coverUrl = 'https://covers.openlibrary.org/b';

  Future<List<BookSearchResult>> search(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': query.trim(),
      'limit': limit.toString(),
      'fields':
          'key,title,author_name,number_of_pages_median,publisher,subject,isbn,cover_i,cover_edition_key',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = body['docs'] as List<dynamic>?;
      if (docs == null) return [];

      return docs
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .where((b) => b.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static BookSearchResult _fromJson(Map<String, dynamic> doc) {
    final authors = (doc['author_name'] as List<dynamic>?)?.cast<String>();
    final publishers = (doc['publisher'] as List<dynamic>?)?.cast<String>();
    final subjects = (doc['subject'] as List<dynamic>?)?.cast<String>();
    final isbns = (doc['isbn'] as List<dynamic>?)?.cast<String>();

    // ISBN-13 tem prioridade
    final isbn = isbns != null && isbns.isNotEmpty
        ? isbns.firstWhere((i) => i.length == 13, orElse: () => isbns.first)
        : null;

    // Capa: usa cover_i (ID numérico) se disponível, senão cover_edition_key
    String? coverUrl;
    final coverId = doc['cover_i'];
    final coverEditionKey = doc['cover_edition_key'] as String?;
    if (coverId != null) {
      coverUrl = '$_coverUrl/id/$coverId-L.jpg';
    } else if (coverEditionKey != null) {
      coverUrl = '$_coverUrl/olid/$coverEditionKey-L.jpg';
    }

    return BookSearchResult(
      title: (doc['title'] as String?) ?? '',
      author: authors?.take(3).join(', '),
      coverUrl: coverUrl,
      totalPages: doc['number_of_pages_median'] as int?,
      genre: subjects?.isNotEmpty ?? false ? subjects!.first : null,
      publisher: publishers?.isNotEmpty ?? false ? publishers!.first : null,
      isbn: (isbn != null && isbn.isNotEmpty) ? isbn : null,
      source: 'openlibrary',
    );
  }
}
