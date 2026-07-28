import 'dart:convert';
import 'package:http/http.dart' as http;
import 'book_search_result.dart';

/// Mantido por compatibilidade — aponta para o modelo unificado.
typedef GoogleBookResult = BookSearchResult;

class GoogleBooksService {
  static const _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  /// Busca livros na Google Books API.
  ///
  /// Retorna até [maxResults] resultados. Não restringe idioma para cobrir
  /// livros em inglês, espanhol etc. que o usuário possa estar buscando.
  Future<List<BookSearchResult>> search(
    String query, {
    int maxResults = 10,
    String? apiKey,
  }) async {
    if (query.trim().isEmpty) return [];

    final params = <String, String>{
      'q': query.trim(),
      'maxResults': maxResults.toString(),
      'printType': 'books',
      'orderBy': 'relevance',
      'fields':
          'items(id,volumeInfo(title,authors,publisher,pageCount,categories,imageLinks,industryIdentifiers))',
    };
    if (apiKey != null && apiKey.isNotEmpty) params['key'] = apiKey;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>?;
      if (items == null) return [];

      return items
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .where((b) => b.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static BookSearchResult _fromJson(Map<String, dynamic> json) {
    final info = json['volumeInfo'] as Map<String, dynamic>? ?? {};

    final authors = (info['authors'] as List<dynamic>?)?.cast<String>();
    final categories = (info['categories'] as List<dynamic>?)?.cast<String>();

    final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
    final cover = _bestCover(imageLinks);

    // ISBN-13 ou ISBN-10
    final ids = (info['industryIdentifiers'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    final isbn13Entry = ids?.firstWhere(
      (e) => e['type'] == 'ISBN_13',
      orElse: () => <String, dynamic>{},
    );
    final isbn13 = isbn13Entry != null && isbn13Entry.isNotEmpty
        ? isbn13Entry['identifier'] as String?
        : null;

    final isbn10Entry = ids?.firstWhere(
      (e) => e['type'] == 'ISBN_10',
      orElse: () => <String, dynamic>{},
    );
    final isbn10 = isbn10Entry != null && isbn10Entry.isNotEmpty
        ? isbn10Entry['identifier'] as String?
        : null;

    return BookSearchResult(
      title: (info['title'] as String?) ?? '',
      author: authors?.join(', '),
      coverUrl: cover,
      totalPages: info['pageCount'] as int?,
      genre: (categories?.isNotEmpty ?? false) ? categories!.first : null,
      publisher: info['publisher'] as String?,
      isbn: isbn13 ?? isbn10,
      source: 'google',
    );
  }

  /// Retorna a melhor URL de capa disponível, forçando HTTPS e maior zoom.
  static String? _bestCover(Map<String, dynamic>? imageLinks) {
    if (imageLinks == null) return null;

    // Preferência: extraLarge > large > medium > thumbnail > smallThumbnail
    final candidates = [
      'extraLarge',
      'large',
      'medium',
      'thumbnail',
      'smallThumbnail',
    ];
    String? cover;
    for (final key in candidates) {
      cover = imageLinks[key] as String?;
      if (cover != null) break;
    }
    if (cover == null) return null;

    // Força HTTPS
    cover = cover.replaceFirst('http://', 'https://');
    // Remove zoom=1 (imagens pequenas) e força zoom=2 (maior)
    cover = cover.replaceAll(RegExp(r'&zoom=\d'), '').replaceAll(RegExp(r'zoom=\d&'), '');
    if (!cover.contains('zoom=')) cover = '$cover&zoom=2';

    return cover;
  }
}
