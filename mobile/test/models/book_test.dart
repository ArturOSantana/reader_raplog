import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/shared/models/book.dart';

void main() {
  final now = DateTime(2024, 6, 1);

  Book makeBook({
    BookStatus status = BookStatus.reading,
    int? totalPages,
    int? currentPage,
    int? rating,
  }) =>
      Book(
        id: 'book-1',
        userId: 'user-1',
        title: 'Dom Casmurro',
        author: 'Machado de Assis',
        status: status,
        totalPages: totalPages,
        currentPage: currentPage,
        rating: rating,
        createdAt: now,
        updatedAt: now,
      );

  // ── BookStatusX ──────────────────────────────────────────────────────────

  group('BookStatusX', () {
    test('label retorna texto correto para cada status', () {
      expect(BookStatus.reading.label, 'Lendo');
      expect(BookStatus.wantToRead.label, 'Quero Ler');
      expect(BookStatus.read.label, 'Lido');
      expect(BookStatus.abandoned.label, 'Abandonado');
    });

    test('dbValue retorna string correta para cada status', () {
      expect(BookStatus.reading.dbValue, 'reading');
      expect(BookStatus.wantToRead.dbValue, 'want_to_read');
      expect(BookStatus.read.dbValue, 'read');
      expect(BookStatus.abandoned.dbValue, 'abandoned');
    });

    test('fromDb converte strings corretamente', () {
      expect(BookStatusX.fromDb('reading'), BookStatus.reading);
      expect(BookStatusX.fromDb('want_to_read'), BookStatus.wantToRead);
      expect(BookStatusX.fromDb('read'), BookStatus.read);
      expect(BookStatusX.fromDb('abandoned'), BookStatus.abandoned);
    });

    test('fromDb retorna wantToRead para valor desconhecido', () {
      expect(BookStatusX.fromDb('unknown_value'), BookStatus.wantToRead);
    });
  });

  // ── Book.fromMap ──────────────────────────────────────────────────────────

  group('Book.fromMap', () {
    final map = {
      'id': 'b-1',
      'user_id': 'u-1',
      'title': 'Ensaio Sobre a Cegueira',
      'author': 'José Saramago',
      'cover_url': null,
      'total_pages': 310,
      'genre': 'Ficção',
      'publisher': null,
      'status': 'read',
      'start_date': '2024-01-10',
      'end_date': '2024-02-20',
      'rating': 5,
      'current_page': 310,
      'created_at': '2024-01-10T00:00:00.000Z',
      'updated_at': '2024-02-20T00:00:00.000Z',
    };

    test('faz parse de todos os campos corretamente', () {
      final book = Book.fromMap(map);
      expect(book.id, 'b-1');
      expect(book.userId, 'u-1');
      expect(book.title, 'Ensaio Sobre a Cegueira');
      expect(book.author, 'José Saramago');
      expect(book.totalPages, 310);
      expect(book.currentPage, 310);
      expect(book.rating, 5);
      expect(book.status, BookStatus.read);
      expect(book.genre, 'Ficção');
      expect(book.startDate, DateTime(2024, 1, 10));
      expect(book.endDate, DateTime(2024, 2, 20));
    });

    test('aceita campos nulos opcionais', () {
      final sparse = {
        'id': 'b-2',
        'user_id': 'u-2',
        'title': 'Sem autor',
        'author': null,
        'cover_url': null,
        'total_pages': null,
        'genre': null,
        'publisher': null,
        'status': 'want_to_read',
        'start_date': null,
        'end_date': null,
        'rating': null,
        'current_page': null,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      final book = Book.fromMap(sparse);
      expect(book.author, isNull);
      expect(book.totalPages, isNull);
      expect(book.rating, isNull);
    });
  });

  // ── Book.toMap ────────────────────────────────────────────────────────────

  group('Book.toMap', () {
    test('converte o status para dbValue corretamente', () {
      final book = makeBook(status: BookStatus.read);
      expect(book.toMap()['status'], 'read');
    });
  });

  // ── Book.copyWith ─────────────────────────────────────────────────────────

  group('Book.copyWith', () {
    test('somente os campos passados são alterados', () {
      final original = makeBook(currentPage: 50, totalPages: 200);
      final updated = original.copyWith(currentPage: 100, rating: 4);
      expect(updated.currentPage, 100);
      expect(updated.rating, 4);
      expect(updated.totalPages, 200);
      expect(updated.title, original.title);
      expect(updated.id, original.id);
    });
  });

  // ── Book props / equatable ────────────────────────────────────────────────

  group('Book equality', () {
    test('dois books com o mesmo id são iguais via props', () {
      final a = makeBook();
      final b = makeBook();
      expect(a, equals(b));
    });
  });
}
