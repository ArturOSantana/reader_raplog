// Testes de criação de livros:
//   • Model: Book.fromMap com o novo campo sourceClubId
//   • Use case: AddBookUseCase monta corretamente o Map passado ao repositório
//   • Widget: AddBookScreen — validação do formulário e campos renderizados

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/library/data/book_repository.dart';
import 'package:lumen/features/library/data/offline_book_repository.dart';
import 'package:lumen/features/library/domain/add_book_use_case.dart';
import 'package:lumen/features/library/presentation/screens/add_book_screen.dart';
import 'package:lumen/shared/models/book.dart';
import 'package:lumen/shared/providers/providers.dart';
import 'package:lumen/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── SupabaseClient sem timers (reutilizado nos fakes) ───────────────────────

SupabaseClient _noTimerClient() => SupabaseClient(
      'https://fake.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );

// ─── Fake de BookRepository (para AddBookUseCase) ────────────────────────────

class _FakeBookRepository extends BookRepository {
  Map<String, dynamic>? lastInserted;
  final Book _stub;

  _FakeBookRepository(this._stub) : super(_noTimerClient());

  @override
  Future<Book> insert(Map<String, dynamic> fields) async {
    lastInserted = fields;
    return _stub;
  }

  @override
  Future<List<Book>> fetchAll({BookStatus? status}) async => [];

  @override
  Future<Book> fetchById(String id) async => _stub;

  @override
  Future<Book> update(String id, Map<String, dynamic> fields) async => _stub;

  @override
  Future<void> delete(String id) async {}
}

// ─── Fake de OfflineBookRepository (para widget tests) ───────────────────────

class _FakeOfflineRepo extends OfflineBookRepository {
  _FakeOfflineRepo() : super(_noTimerClient(), () => false);

  @override
  Future<Book> insert(Map<String, dynamic> fields) async => Book(
        id: 'new-book',
        userId: 'u-1',
        title: fields['title'] as String,
        status: BookStatus.wantToRead,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  @override
  Future<List<Book>> fetchAll({BookStatus? status}) async => [];

  @override
  Future<Book?> fetchById(String id) async => null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseMap({
  String id = 'b-1',
  String status = 'want_to_read',
  String? sourceClubId,
}) =>
    {
      'id': id,
      'user_id': 'u-1',
      'title': 'Fundação',
      'author': 'Isaac Asimov',
      'cover_url': null,
      'total_pages': 320,
      'genre': 'Ficção Científica',
      'publisher': 'Aleph',
      'status': status,
      'start_date': null,
      'end_date': null,
      'rating': null,
      'current_page': null,
      'source_club_id': sourceClubId,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    };

Book _stubBook({String title = 'Dom Casmurro'}) => Book(
      id: 'new',
      userId: 'u-1',
      title: title,
      status: BookStatus.wantToRead,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

// ─── Testes ──────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Modelo: criação via fromMap ─────────────────────────────────────────

  group('Book.fromMap — criação', () {
    test('cria Book com todos os campos preenchidos', () {
      final book = Book.fromMap(_baseMap());
      expect(book.id, 'b-1');
      expect(book.title, 'Fundação');
      expect(book.author, 'Isaac Asimov');
      expect(book.totalPages, 320);
      expect(book.genre, 'Ficção Científica');
      expect(book.publisher, 'Aleph');
      expect(book.status, BookStatus.wantToRead);
      expect(book.sourceClubId, isNull);
    });

    test('cria Book com sourceClubId preenchido', () {
      final book = Book.fromMap(_baseMap(sourceClubId: 'club-99'));
      expect(book.sourceClubId, 'club-99');
    });

    test('cria Book com status "reading"', () {
      final book = Book.fromMap(_baseMap(status: 'reading'));
      expect(book.status, BookStatus.reading);
    });

    test('cria Book com status "read"', () {
      final book = Book.fromMap(_baseMap(status: 'read'));
      expect(book.status, BookStatus.read);
    });

    test('cria Book com status "abandoned"', () {
      final book = Book.fromMap(_baseMap(status: 'abandoned'));
      expect(book.status, BookStatus.abandoned);
    });

    test('todos os campos opcionais ficam null quando não fornecidos', () {
      final book = Book.fromMap({
        'id': 'b-2',
        'user_id': 'u-1',
        'title': 'Título mínimo',
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
        'source_club_id': null,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });
      expect(book.author, isNull);
      expect(book.totalPages, isNull);
      expect(book.genre, isNull);
      expect(book.publisher, isNull);
      expect(book.sourceClubId, isNull);
    });

    test('parseia startDate e endDate corretamente', () {
      final book = Book.fromMap({
        ..._baseMap(status: 'read'),
        'start_date': '2024-01-10',
        'end_date': '2024-03-20',
      });
      expect(book.startDate, DateTime(2024, 1, 10));
      expect(book.endDate, DateTime(2024, 3, 20));
    });
  });

  // ── 2. Modelo: toMap serializa corretamente ────────────────────────────────

  group('Book.toMap — serialização na criação', () {
    test('serializa source_club_id quando preenchido', () {
      final book = Book.fromMap(_baseMap(sourceClubId: 'club-99'));
      expect(book.toMap()['source_club_id'], 'club-99');
    });

    test('serializa source_club_id como null quando ausente', () {
      final book = Book.fromMap(_baseMap());
      expect(book.toMap()['source_club_id'], isNull);
    });

    test('serializa status como dbValue correto', () {
      final book = Book.fromMap(_baseMap(status: 'reading'));
      expect(book.toMap()['status'], 'reading');
    });

    test('serializa start_date no formato yyyy-MM-dd', () {
      final book = Book.fromMap({
        ..._baseMap(status: 'read'),
        'start_date': '2024-06-15',
        'end_date': null,
      });
      expect(book.toMap()['start_date'], '2024-06-15');
    });

    test('round-trip fromMap → toMap preserva os campos principais', () {
      final map = _baseMap(sourceClubId: 'club-1');
      final book = Book.fromMap(map);
      final out = book.toMap();
      expect(out['title'], map['title']);
      expect(out['author'], map['author']);
      expect(out['total_pages'], map['total_pages']);
      expect(out['genre'], map['genre']);
      expect(out['publisher'], map['publisher']);
      expect(out['source_club_id'], 'club-1');
    });
  });

  // ── 3. Use case: AddBookUseCase ────────────────────────────────────────────

  group('AddBookUseCase', () {
    late _FakeBookRepository repo;
    late AddBookUseCase useCase;

    setUp(() {
      repo = _FakeBookRepository(_stubBook());
      useCase = AddBookUseCase(repo);
    });

    test('chama insert com title e status padrão "want_to_read"', () async {
      await useCase(title: 'Dom Casmurro');
      expect(repo.lastInserted!['title'], 'Dom Casmurro');
      expect(repo.lastInserted!['status'], 'want_to_read');
    });

    test('usa status explicitamente passado', () async {
      await useCase(title: 'Dom Casmurro', status: BookStatus.reading);
      expect(repo.lastInserted!['status'], 'reading');
    });

    test('omite campos nulos do payload (author, coverUrl, totalPages)', () async {
      await useCase(title: 'Dom Casmurro');
      expect(repo.lastInserted!.containsKey('author'), isFalse);
      expect(repo.lastInserted!.containsKey('cover_url'), isFalse);
      expect(repo.lastInserted!.containsKey('total_pages'), isFalse);
    });

    test('inclui author quando fornecido', () async {
      await useCase(title: 'Dom Casmurro', author: 'Machado de Assis');
      expect(repo.lastInserted!['author'], 'Machado de Assis');
    });

    test('inclui totalPages quando fornecido', () async {
      await useCase(title: 'Dom Casmurro', totalPages: 256);
      expect(repo.lastInserted!['total_pages'], 256);
    });

    test('inclui genre quando fornecido', () async {
      await useCase(title: 'Dom Casmurro', genre: 'Romance');
      expect(repo.lastInserted!['genre'], 'Romance');
    });

    test('inclui publisher quando fornecido', () async {
      await useCase(title: 'Dom Casmurro', publisher: 'Companhia das Letras');
      expect(repo.lastInserted!['publisher'], 'Companhia das Letras');
    });

    test('inclui rating quando fornecido', () async {
      await useCase(title: 'Dom Casmurro', rating: 5);
      expect(repo.lastInserted!['rating'], 5);
    });

    test('inclui coverUrl quando fornecido', () async {
      await useCase(
          title: 'Dom Casmurro', coverUrl: 'https://covers.example.com/a.jpg');
      expect(repo.lastInserted!['cover_url'], 'https://covers.example.com/a.jpg');
    });

    test('retorna o Book devolvido pelo repositório', () async {
      final result = await useCase(title: 'Dom Casmurro');
      expect(result.title, 'Dom Casmurro');
      expect(result.id, 'new');
    });
  });

  // ── 4. Widget: AddBookScreen — estrutura ───────────────────────────────────

  group('AddBookScreen — estrutura visual', () {
    Widget build() => ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(_FakeOfflineRepo()),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AddBookScreen()),
        );

    testWidgets('exibe AppBar "Adicionar livro"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('Adicionar livro'), findsOneWidget);
    });

    testWidgets('exibe campo "Título *"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Título *'), findsOneWidget);
    });

    testWidgets('exibe campo "Autor"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Autor'), findsOneWidget);
    });

    testWidgets('exibe campo "Número de páginas"', (tester) async {
      await tester.pumpWidget(build());
      expect(
          find.widgetWithText(TextFormField, 'Número de páginas'), findsOneWidget);
    });

    testWidgets('exibe campo "Gênero"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Gênero'), findsOneWidget);
    });

    testWidgets('exibe campo "Editora"', (tester) async {
      await tester.pumpWidget(build());
      expect(find.widgetWithText(TextFormField, 'Editora'), findsOneWidget);
    });

    testWidgets('exibe campo de busca por ISBN', (tester) async {
      await tester.pumpWidget(build());
      expect(
          find.widgetWithText(TextFormField, 'Buscar por ISBN'), findsOneWidget);
    });

    testWidgets('exibe botão "Salvar" na AppBar', (tester) async {
      await tester.pumpWidget(build());
      // O botão "Salvar" da AppBar está sempre visível sem scroll
      expect(find.text('Salvar'), findsOneWidget);
    });
  });

  // ── 5. Widget: AddBookScreen — validação ───────────────────────────────────

  group('AddBookScreen — validação do formulário', () {
    Widget build() => ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(_FakeOfflineRepo()),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AddBookScreen()),
        );

    testWidgets('exibe "Título obrigatório" ao salvar sem título', (tester) async {
      await tester.pumpWidget(build());
      // Usa o botão "Salvar" do AppBar (sempre visível, sem scroll)
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(find.text('Título obrigatório'), findsOneWidget);
    });

    testWidgets('não exibe erro de título quando campo preenchido', (tester) async {
      await tester.pumpWidget(build());
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Título *'), 'Dom Casmurro');
      expect(find.text('Título obrigatório'), findsNothing);
    });

    testWidgets(
        'título com apenas espaços em branco causa erro "Título obrigatório"',
        (tester) async {
      await tester.pumpWidget(build());
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Título *'), '   ');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(find.text('Título obrigatório'), findsOneWidget);
    });
  });
}
