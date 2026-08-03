import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/shared/models/highlight.dart';

void main() {
  // ── Highlight.fromMap ─────────────────────────────────────────────────────

  group('Highlight.fromMap', () {
    final map = {
      'id': 'h-1',
      'user_id': 'user-1',
      'book_id': 'book-1',
      'text': 'Frase marcante do livro.',
      'page_number': 77,
      'created_at': '2024-06-01T10:00:00.000Z',
    };

    test('faz parse de todos os campos corretamente', () {
      final h = Highlight.fromMap(map);
      expect(h.id, 'h-1');
      expect(h.userId, 'user-1');
      expect(h.bookId, 'book-1');
      expect(h.text, 'Frase marcante do livro.');
      expect(h.pageNumber, 77);
      expect(h.createdAt, DateTime.parse('2024-06-01T10:00:00.000Z'));
    });

    test('aceita pageNumber nulo', () {
      final m = Map<String, dynamic>.from(map);
      m['page_number'] = null;
      final h = Highlight.fromMap(m);
      expect(h.pageNumber, isNull);
    });
  });

  // ── Construtor direto ─────────────────────────────────────────────────────

  group('Highlight constructor', () {
    test('cria highlight com todos os campos obrigatórios', () {
      final h = Highlight(
        id: 'h-2',
        userId: 'u-2',
        bookId: 'b-2',
        text: 'Outra frase',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(h.pageNumber, isNull);
      expect(h.text, 'Outra frase');
    });
  });
}
