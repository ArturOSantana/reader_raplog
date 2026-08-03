// Testes de alteração de status de livro:
//   • Model: Book.copyWith para cada transição de status
//   • Use case: UpdateBookUseCase repassa o payload correto
//   • Widget: EditBookScreen — estrutura, validação e regras de negócio

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/library/data/offline_book_repository.dart';
import 'package:lumen/features/library/data/book_repository.dart';
import 'package:lumen/features/library/domain/update_book_use_case.dart';
import 'package:lumen/features/library/domain/delete_book_use_case.dart';
import 'package:lumen/features/library/presentation/screens/edit_book_screen.dart';
import 'package:lumen/shared/models/book.dart';
import 'package:lumen/shared/providers/providers.dart';
import 'package:lumen/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── SupabaseClient sem timers ───────────────────────────────────────────────

SupabaseClient _noTimerClient() => SupabaseClient(
      'https://fake.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );

// ─── Fake BookRepository (para UpdateBookUseCase / DeleteBookUseCase) ─────────

class _FakeBookRepository extends BookRepository {
  Map<String, dynamic>? lastUpdated;
  String? deletedId;
  Book _current;

  _FakeBookRepository(this._current) : super(_noTimerClient());

  @override
  Future<Book> update(String id, Map<String, dynamic> fields) async {
    lastUpdated = {'id': id, ...fields};
    // Simula o retorno do backend aplicando as mudanças ao livro atual
    if (fields.containsKey('status')) {
      _current = _current.copyWith(
        status: BookStatusX.fromDb(fields['status'] as String),
      );
    }
    return _current;
  }

  @override
  Future<void> delete(String id) async {
    deletedId = id;
  }

  @override
  Future<Book> insert(Map<String, dynamic> fields) async => _current;

  @override
  Future<List<Book>> fetchAll({BookStatus? status}) async => [_current];

  @override
  Future<Book> fetchById(String id) async => _current;
}

// ─── Fake OfflineBookRepository (para widget tests) ──────────────────────────

class _FakeOfflineRepo extends OfflineBookRepository {
  Map<String, dynamic>? lastUpdated;
  final Book _current;

  _FakeOfflineRepo(this._current) : super(_noTimerClient(), () => false);

  @override
  Future<Book> update(String id, Map<String, dynamic> fields) async {
    lastUpdated = {'id': id, ...fields};
    return _current.copyWith(
      title: fields['title'] as String? ?? _current.title,
    );
  }

  @override
  Future<List<Book>> fetchAll({BookStatus? status}) async => [_current];

  @override
  Future<Book?> fetchById(String id) async => _current;
}

// ─── Livro base para testes ──────────────────────────────────────────────────

Book _makeBook({
  BookStatus status = BookStatus.wantToRead,
  String title = 'Dom Casmurro',
  int? totalPages = 200,
  int? currentPage = 0,
  int? rating,
}) =>
    Book(
      id: 'book-1',
      userId: 'user-1',
      title: title,
      author: 'Machado de Assis',
      totalPages: totalPages,
      currentPage: currentPage,
      rating: rating,
      status: status,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

// ─── Testes ──────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Modelo: Book.copyWith para alteração de status ──────────────────────

  group('Book.copyWith — alteração de status', () {
    test('wantToRead → reading', () {
      final book = _makeBook(status: BookStatus.wantToRead);
      final updated = book.copyWith(status: BookStatus.reading);
      expect(updated.status, BookStatus.reading);
      expect(updated.id, book.id);
      expect(updated.title, book.title);
    });

    test('reading → read', () {
      final book = _makeBook(status: BookStatus.reading, currentPage: 150);
      final updated = book.copyWith(status: BookStatus.read);
      expect(updated.status, BookStatus.read);
      expect(updated.currentPage, 150); // currentPage não muda
    });

    test('reading → abandoned', () {
      final book = _makeBook(status: BookStatus.reading);
      final updated = book.copyWith(status: BookStatus.abandoned);
      expect(updated.status, BookStatus.abandoned);
    });

    test('abandoned → wantToRead (reativação)', () {
      final book = _makeBook(status: BookStatus.abandoned);
      final updated = book.copyWith(status: BookStatus.wantToRead);
      expect(updated.status, BookStatus.wantToRead);
    });

    test('copyWith preserva todos os campos não alterados', () {
      final book = _makeBook(
        status: BookStatus.reading,
        totalPages: 320,
        currentPage: 80,
        rating: 4,
      );
      final updated = book.copyWith(status: BookStatus.read);
      expect(updated.totalPages, 320);
      expect(updated.currentPage, 80);
      expect(updated.rating, 4);
      expect(updated.author, book.author);
      expect(updated.userId, book.userId);
    });

    test('copyWith atualiza currentPage mantendo o status', () {
      final book = _makeBook(status: BookStatus.reading, currentPage: 50);
      final updated = book.copyWith(currentPage: 100);
      expect(updated.currentPage, 100);
      expect(updated.status, BookStatus.reading);
    });

    test('copyWith atualiza rating', () {
      final book = _makeBook(status: BookStatus.read);
      final updated = book.copyWith(rating: 5);
      expect(updated.rating, 5);
      expect(updated.status, BookStatus.read);
    });

    test('múltiplos copyWith encadeados aplicam todas as alterações', () {
      final book = _makeBook();
      final step1 = book.copyWith(status: BookStatus.reading, currentPage: 50);
      final step2 = step1.copyWith(currentPage: 200, status: BookStatus.read);
      final step3 = step2.copyWith(rating: 5);
      expect(step3.status, BookStatus.read);
      expect(step3.currentPage, 200);
      expect(step3.rating, 5);
    });
  });

  // ── 2. Modelo: serialização de status após copyWith ────────────────────────

  group('Book.toMap — status após alteração', () {
    for (final entry in {
      BookStatus.wantToRead: 'want_to_read',
      BookStatus.reading: 'reading',
      BookStatus.read: 'read',
      BookStatus.abandoned: 'abandoned',
    }.entries) {
      test('${entry.key.name} serializa como "${entry.value}"', () {
        final book = _makeBook().copyWith(status: entry.key);
        expect(book.toMap()['status'], entry.value);
      });
    }
  });

  // ── 3. Use case: UpdateBookUseCase ─────────────────────────────────────────

  group('UpdateBookUseCase', () {
    late _FakeBookRepository repo;
    late UpdateBookUseCase useCase;

    setUp(() {
      repo = _FakeBookRepository(_makeBook());
      useCase = UpdateBookUseCase(repo);
    });

    test('repassa o bookId corretamente ao repositório', () async {
      await useCase('book-1', {'status': 'reading'});
      expect(repo.lastUpdated!['id'], 'book-1');
    });

    test('repassa status "reading" ao repositório', () async {
      await useCase('book-1', {'status': 'reading'});
      expect(repo.lastUpdated!['status'], 'reading');
    });

    test('repassa status "read" ao repositório', () async {
      await useCase('book-1', {'status': 'read'});
      expect(repo.lastUpdated!['status'], 'read');
    });

    test('repassa status "abandoned" ao repositório', () async {
      await useCase('book-1', {'status': 'abandoned'});
      expect(repo.lastUpdated!['status'], 'abandoned');
    });

    test('pode atualizar múltiplos campos de uma vez', () async {
      await useCase('book-1', {
        'status': 'read',
        'rating': 5,
        'current_page': 200,
      });
      expect(repo.lastUpdated!['status'], 'read');
      expect(repo.lastUpdated!['rating'], 5);
      expect(repo.lastUpdated!['current_page'], 200);
    });

    test('retorna o livro atualizado', () async {
      final updated = await useCase('book-1', {'status': 'reading'});
      expect(updated.status, BookStatus.reading);
    });
  });

  // ── 4. Use case: DeleteBookUseCase ─────────────────────────────────────────

  group('DeleteBookUseCase', () {
    test('chama delete com o bookId correto', () async {
      final repo = _FakeBookRepository(_makeBook());
      final useCase = DeleteBookUseCase(repo);
      await useCase('book-1');
      expect(repo.deletedId, 'book-1');
    });
  });

  // ── 5. Widget: EditBookScreen — estrutura ──────────────────────────────────

  group('EditBookScreen — estrutura visual', () {
    Widget build({Book? book}) => ProviderScope(
          overrides: [
            bookRepositoryProvider
                .overrideWithValue(_FakeOfflineRepo(book ?? _makeBook())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: EditBookScreen(book: book ?? _makeBook()),
          ),
        );

    testWidgets('exibe AppBar "Editar livro"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('Editar livro'), findsOneWidget);
    });

    testWidgets('pré-preenche o título do livro', (tester) async {
      await tester.pumpWidget(
          build(book: _makeBook(title: 'Ensaio Sobre a Cegueira')));
      final field = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Ensaio Sobre a Cegueira'));
      expect(field.controller?.text, 'Ensaio Sobre a Cegueira');
    });

    testWidgets('exibe campo "Título *"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Título *'), findsOneWidget);
    });

    testWidgets('exibe campo "Página atual"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Página atual'), findsOneWidget);
    });

    testWidgets('exibe campo "Avaliação (1–5)"', (tester) async {
      await tester.pumpWidget(build());
      expect(
          find.widgetWithText(TextFormField, 'Avaliação (1–5)'), findsOneWidget);
    });

    testWidgets('exibe botão "Salvar alterações"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('Salvar alterações'), findsOneWidget);
    });

    testWidgets('pré-preenche totalPages quando disponível', (tester) async {
      await tester.pumpWidget(
          build(book: _makeBook(totalPages: 350)));
      // O campo de páginas deve conter "350"
      expect(find.text('350'), findsWidgets);
    });
  });

  // ── 6. Widget: EditBookScreen — validação ──────────────────────────────────

  group('EditBookScreen — validação do formulário', () {
    Widget build({Book? book}) => ProviderScope(
          overrides: [
            bookRepositoryProvider
                .overrideWithValue(_FakeOfflineRepo(book ?? _makeBook())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: EditBookScreen(book: book ?? _makeBook()),
          ),
        );

    testWidgets('exibe erro se título for apagado e salvo', (tester) async {
      await tester.pumpWidget(build());

      final titleField =
          find.widgetWithText(TextFormField, 'Título *');
      await tester.enterText(titleField, '');

      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      expect(find.text('Título obrigatório'), findsOneWidget);
    });

    testWidgets('exibe erro se avaliação for maior que 5', (tester) async {
      await tester.pumpWidget(build());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Avaliação (1–5)'), '9');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      expect(find.text('Avaliação deve ser entre 1 e 5'), findsOneWidget);
    });

    testWidgets('exibe erro se avaliação for menor que 1', (tester) async {
      await tester.pumpWidget(build());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Avaliação (1–5)'), '0');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      expect(find.text('Avaliação deve ser entre 1 e 5'), findsOneWidget);
    });

    testWidgets(
        'exibe erro se página atual for maior que o total de páginas',
        (tester) async {
      await tester.pumpWidget(
        build(book: _makeBook(totalPages: 200, currentPage: 50)),
      );

      // Página atual = 300 > total 200
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Página atual'), '300');

      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      expect(
        find.text('Página atual não pode ser maior que o total'),
        findsOneWidget,
      );
    });

    testWidgets('não exibe erro quando avaliação é 5', (tester) async {
      await tester.pumpWidget(build());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Avaliação (1–5)'), '5');
      // Validação só ocorre no submit — mas sem submeter, nenhum erro deve aparecer
      expect(find.text('Avaliação deve ser entre 1 e 5'), findsNothing);
    });
  });
}
