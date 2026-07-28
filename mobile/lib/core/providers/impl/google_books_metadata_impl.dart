/// Implementação do [BookMetadataProvider] usando a Google Books API.
///
/// Esta classe é a ÚNICA no codebase que pode importar ou chamar a Google Books.
/// Todo o resto do app usa [BookMetadataProvider].
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../book_metadata_provider.dart';

class GoogleBooksMetadataImpl implements BookMetadataProvider {
  final String _apiKey;
  final http.Client _httpClient;

  static const _base = 'https://www.googleapis.com/books/v1';

  GoogleBooksMetadataImpl({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'google_books';

  @override
  Future<List<BookMetadata>> search(String query, {int maxResults = 20}) async {
    final uri = Uri.parse(
      '$_base/volumes?q=${Uri.encodeComponent(query)}'
      '&maxResults=$maxResults&key=$_apiKey',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return [];
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? [];
    return items
        .map((i) => _fromJson(i as Map<String, dynamic>))
        .whereType<BookMetadata>()
        .toList();
  }

  @override
  Future<BookMetadata?> fetchById(String id) async {
    final uri = Uri.parse('$_base/volumes/$id?key=$_apiKey');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return null;
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<BookMetadata?> fetchByIsbn(String isbn) async {
    final clean = isbn.replaceAll('-', '').replaceAll(' ', '');
    final results = await search('isbn:$clean', maxResults: 1);
    return results.isEmpty ? null : results.first;
  }

  // ── Normalização interna ──────────────────────────────────────────────────

  BookMetadata? _fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;

    final info = json['volumeInfo'] as Map<String, dynamic>? ?? {};

    final isbns = (info['industryIdentifiers'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final isbn13 = isbns
        .where((i) => i['type'] == 'ISBN_13')
        .map((i) => i['identifier'] as String)
        .firstOrNull;
    final isbn10 = isbns
        .where((i) => i['type'] == 'ISBN_10')
        .map((i) => i['identifier'] as String)
        .firstOrNull;

    final imageLinks = info['imageLinks'] as Map<String, dynamic>? ?? {};
    String? coverUrl = (imageLinks['thumbnail'] as String?) ??
        (imageLinks['smallThumbnail'] as String?);
    // Forçar HTTPS
    if (coverUrl != null) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    return BookMetadata(
      id: id,
      title: info['title'] as String? ?? 'Sem título',
      subtitle: info['subtitle'] as String?,
      authors: List<String>.from(info['authors'] as List? ?? []),
      publisher: info['publisher'] as String?,
      publishedDate: info['publishedDate'] as String?,
      description: info['description'] as String?,
      isbn10: isbn10,
      isbn13: isbn13,
      coverUrl: coverUrl,
      pageCount: info['pageCount'] as int?,
      categories: List<String>.from(info['categories'] as List? ?? []),
      language: info['language'] as String?,
      sourceProvider: providerName,
    );
  }
}
