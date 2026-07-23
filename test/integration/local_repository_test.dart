// Testes de integração — LocalBookRepository + LocalSessionRepository
//
// Usam sqflite_common_ffi para abrir um banco SQLite em memória,
// o mesmo schema do app real (LocalDatabase._onCreate).
// Nenhuma rede, nenhum Supabase, nenhum plugin nativo.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:readlog/core/local/local_database.dart';
import 'package:readlog/features/library/data/local_book_repository.dart';
import 'package:readlog/features/session/data/local_session_repository.dart';
import 'package:readlog/shared/models/book.dart';

// ─── Setup global ────────────────────────────────────────────────────────────

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Abre um banco em memória com o schema completo do app e injeta-o no
/// singleton [LocalDatabase.instance] antes de cada teste.
Future<void> _openInMemoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            author TEXT,
            cover_url TEXT,
            total_pages INTEGER,
            genre TEXT,
            publisher TEXT,
            status TEXT NOT NULL,
            start_date TEXT,
            end_date TEXT,
            rating INTEGER,
            current_page INTEGER,
            source_club_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE reading_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            duration_minutes INTEGER,
            paused_duration_seconds INTEGER NOT NULL DEFAULT 0,
            start_page INTEGER,
            end_page INTEGER,
            pages_read INTEGER,
            notes TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            session_goal TEXT,
            goal_value INTEGER,
            mood TEXT,
            mini_review TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            page_number INTEGER,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE profile (
            id TEXT PRIMARY KEY,
            name TEXT,
            bio TEXT,
            avatar_url TEXT,
            yearly_goal INTEGER,
            favorite_genre TEXT,
            favorite_authors TEXT,
            favorite_book TEXT,
            onboarding_completed INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_stats_cache (
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            total_minutes INTEGER NOT NULL DEFAULT 0,
            total_pages INTEGER NOT NULL DEFAULT 0,
            session_count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, date)
          )
        ''');
      },
    ),
  );
  // Injeta o banco in-memory no singleton para que os repositórios o usem
  LocalDatabase.instance.injectForTest(db);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _uid = 'user-test';

Map<String, dynamic> _bookMap({
  required String id,
  String title = 'Livro Teste',
  String status = 'want_to_read',
  String? author,
  int? totalPages,
  int? currentPage,
  int? rating,
  String? sourceClubId,
}) =>
    {
      'id': id,
      'user_id': _uid,
      'title': title,
      'author': author,
      'cover_url': null,
      'total_pages': totalPages,
      'genre': null,
      'publisher': null,
      'status': status,
      'start_date': null,
      'end_date': null,
      'rating': rating,
      'current_page': currentPage,
      'source_club_id': sourceClubId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

Map<String, dynamic> _sessionMap({
  required String id,
  required String bookId,
  String status = 'finished',
  int? durationMinutes,
  int? startPage,
  int? endPage,
  String? startedAt,
  String? mood,
  String? miniReview,
}) =>
    {
      'id': id,
      'user_id': _uid,
      'book_id': bookId,
      'started_at':
          startedAt ?? DateTime.now().toIso8601String(),
      'ended_at': DateTime.now().toIso8601String(),
      'duration_minutes': durationMinutes,
      'paused_duration_seconds': 0,
      'start_page': startPage,
      'end_page': endPage,
      'pages_read': (startPage != null && endPage != null && endPage > startPage)
          ? endPage - startPage
          : null,
      'notes': null,
      'status': status,
      'session_goal': null,
      'goal_value': null,
      'mood': mood,
      'mini_review': miniReview,
      'created_at': DateTime.now().toIso8601String(),
    };

// ═══════════════════════════════════════════════════════════════════════════════
// TESTES
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  setUpAll(_initFfi);
  setUp(_openInMemoryDb);
  tearDown(() async => await LocalDatabase.instance.close());

  // ══════════════════════════════════════════════════════════════════════════════
  // LocalBookRepository
  // ══════════════════════════════════════════════════════════════════════════════

  group('LocalBookRepository — criação (upsert)', () {
    test('insere um livro e fetchAll retorna esse livro', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1', title: 'Dom Casmurro'));

      final books = await repo.fetchAll();
      expect(books.length, 1);
      expect(books.first.title, 'Dom Casmurro');
    });

    test('insere livro com sourceClubId e mantém o campo', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1', sourceClubId: 'club-99'));

      final book = await repo.fetchById('b-1');
      expect(book?.sourceClubId, 'club-99');
    });

    test('insere múltiplos livros via upsertAll', () async {
      final repo = LocalBookRepository();
      await repo.upsertAll([
        _bookMap(id: 'b-1', title: 'Livro 1'),
        _bookMap(id: 'b-2', title: 'Livro 2'),
        _bookMap(id: 'b-3', title: 'Livro 3'),
      ]);

      final books = await repo.fetchAll();
      expect(books.length, 3);
    });

    test('upsert sobrescreve livro existente com mesmo id', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1', title: 'Versão 1'));
      await repo.upsert(_bookMap(id: 'b-1', title: 'Versão 2'));

      final books = await repo.fetchAll();
      expect(books.length, 1);
      expect(books.first.title, 'Versão 2');
    });
  });

  group('LocalBookRepository — fetch por id', () {
    test('retorna o livro correto por id', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1', title: 'Fundação'));
      await repo.upsert(_bookMap(id: 'b-2', title: 'Duna'));

      final book = await repo.fetchById('b-2');
      expect(book?.title, 'Duna');
    });

    test('retorna null para id inexistente', () async {
      final repo = LocalBookRepository();
      final book = await repo.fetchById('nao-existe');
      expect(book, isNull);
    });
  });

  group('LocalBookRepository — filtro por status', () {
    setUp(() async {
      final repo = LocalBookRepository();
      await repo.upsertAll([
        _bookMap(id: 'b-1', status: 'reading'),
        _bookMap(id: 'b-2', status: 'reading'),
        _bookMap(id: 'b-3', status: 'read'),
        _bookMap(id: 'b-4', status: 'want_to_read'),
        _bookMap(id: 'b-5', status: 'abandoned'),
      ]);
    });

    test('fetchAll sem filtro retorna todos os livros', () async {
      final books = await LocalBookRepository().fetchAll();
      expect(books.length, 5);
    });

    test('fetchAll(status: reading) retorna apenas os livros em leitura', () async {
      final books =
          await LocalBookRepository().fetchAll(status: BookStatus.reading);
      expect(books.length, 2);
      expect(books.every((b) => b.status == BookStatus.reading), isTrue);
    });

    test('fetchAll(status: read) retorna apenas os lidos', () async {
      final books =
          await LocalBookRepository().fetchAll(status: BookStatus.read);
      expect(books.length, 1);
      expect(books.first.status, BookStatus.read);
    });

    test('fetchAll(status: wantToRead) retorna apenas os que deseja ler', () async {
      final books =
          await LocalBookRepository().fetchAll(status: BookStatus.wantToRead);
      expect(books.length, 1);
      expect(books.first.status, BookStatus.wantToRead);
    });

    test('fetchAll(status: abandoned) retorna apenas os abandonados', () async {
      final books =
          await LocalBookRepository().fetchAll(status: BookStatus.abandoned);
      expect(books.length, 1);
      expect(books.first.status, BookStatus.abandoned);
    });
  });

  group('LocalBookRepository — atualização de status', () {
    test('update altera o status de wantToRead para reading', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1', status: 'want_to_read'));

      await repo.update('b-1', {'status': 'reading'});

      final book = await repo.fetchById('b-1');
      expect(book?.status, BookStatus.reading);
    });

    test('update altera o status de reading para read', () async {
      final repo = LocalBookRepository();
      await repo.upsert(
          _bookMap(id: 'b-1', status: 'reading', totalPages: 200, currentPage: 150));

      await repo.update('b-1', {'status': 'read', 'current_page': 200});

      final book = await repo.fetchById('b-1');
      expect(book?.status, BookStatus.read);
      expect(book?.currentPage, 200);
    });

    test('update altera rating', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1'));
      await repo.update('b-1', {'rating': 5});

      final book = await repo.fetchById('b-1');
      expect(book?.rating, 5);
    });

    test('update de currentPage não afeta outros campos', () async {
      final repo = LocalBookRepository();
      await repo.upsert(
          _bookMap(id: 'b-1', title: 'Fundação', totalPages: 320));

      await repo.update('b-1', {'current_page': 80});

      final book = await repo.fetchById('b-1');
      expect(book?.currentPage, 80);
      expect(book?.title, 'Fundação');
      expect(book?.totalPages, 320);
    });
  });

  group('LocalBookRepository — soft-delete', () {
    test('markDeleted oculta o livro de fetchAll', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1'));
      await repo.markDeleted('b-1');

      final books = await repo.fetchAll();
      expect(books.isEmpty, isTrue);
    });

    test('markDeleted oculta o livro de fetchById', () async {
      final repo = LocalBookRepository();
      await repo.upsert(_bookMap(id: 'b-1'));
      await repo.markDeleted('b-1');

      final book = await repo.fetchById('b-1');
      expect(book, isNull);
    });

    test('markDeleted de um livro não afeta os demais', () async {
      final repo = LocalBookRepository();
      await repo.upsertAll([
        _bookMap(id: 'b-1'),
        _bookMap(id: 'b-2', title: 'Livre'),
      ]);
      await repo.markDeleted('b-1');

      final books = await repo.fetchAll();
      expect(books.length, 1);
      expect(books.first.title, 'Livre');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════════
  // LocalSessionRepository
  // ══════════════════════════════════════════════════════════════════════════════

  group('LocalSessionRepository — criação e leitura', () {
    test('insert e fetchById retornam a sessão criada', () async {
      final repo = LocalSessionRepository();
      final map = _sessionMap(id: 's-1', bookId: 'b-1', durationMinutes: 30);
      await repo.insert(map);

      final session = await repo.fetchById('s-1');
      expect(session?.id, 's-1');
      expect(session?.durationMinutes, 30);
    });

    test('fetchByBook retorna todas as sessões do livro correto', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 's-1', bookId: 'b-1'));
      await repo.insert(_sessionMap(id: 's-2', bookId: 'b-1'));
      await repo.insert(_sessionMap(id: 's-3', bookId: 'b-2'));

      final sessions = await repo.fetchByBook('b-1');
      expect(sessions.length, 2);
      expect(sessions.every((s) => s.bookId == 'b-1'), isTrue);
    });

    test('upsertAll insere múltiplas sessões de uma vez', () async {
      final repo = LocalSessionRepository();
      await repo.upsertAll([
        _sessionMap(id: 's-1', bookId: 'b-1'),
        _sessionMap(id: 's-2', bookId: 'b-1'),
      ]);
      final sessions = await repo.fetchByBook('b-1');
      expect(sessions.length, 2);
    });

    test('sessão com mood e miniReview é persistida e recuperada', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(
        id: 's-1',
        bookId: 'b-1',
        mood: 'happy',
        miniReview: 'Ótima leitura!',
      ));
      final session = await repo.fetchById('s-1');
      expect(session?.mood?.name, 'happy');
      expect(session?.miniReview, 'Ótima leitura!');
    });
  });

  group('LocalSessionRepository — stats diárias', () {
    test('fetchDailyStats retorna zeros quando não há sessões hoje', () async {
      final repo = LocalSessionRepository();
      final stats = await repo.fetchDailyStats(_uid);
      expect(stats['total_minutes'], 0);
      expect(stats['total_pages'], 0);
    });

    test('fetchDailyStats acumula minutos das sessões do dia', () async {
      final repo = LocalSessionRepository();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      await repo.insert(_sessionMap(
        id: 's-1',
        bookId: 'b-1',
        durationMinutes: 45,
        startedAt: '${today}T09:00:00.000Z',
      ));
      await repo.insert(_sessionMap(
        id: 's-2',
        bookId: 'b-1',
        durationMinutes: 30,
        startedAt: '${today}T14:00:00.000Z',
      ));

      final stats = await repo.fetchDailyStats(_uid);
      expect(stats['total_minutes'], 75);
    });

    test('fetchDailyStats acumula páginas (end_page - start_page)', () async {
      final repo = LocalSessionRepository();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      await repo.insert(_sessionMap(
        id: 's-1',
        bookId: 'b-1',
        startPage: 50,
        endPage: 80,
        startedAt: '${today}T09:00:00.000Z',
      ));
      await repo.insert(_sessionMap(
        id: 's-2',
        bookId: 'b-1',
        startPage: 80,
        endPage: 100,
        startedAt: '${today}T14:00:00.000Z',
      ));

      final stats = await repo.fetchDailyStats(_uid);
      expect(stats['total_pages'], 50); // 30 + 20
    });

    test('fetchDailyStats usa cache quando disponível', () async {
      final repo = LocalSessionRepository();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Injeta diretamente no cache
      await repo.upsertDailyStats(
        userId: _uid,
        date: today,
        totalMinutes: 120,
        totalPages: 60,
        sessionCount: 2,
      );

      final stats = await repo.fetchDailyStats(_uid);
      expect(stats['total_minutes'], 120);
      expect(stats['total_pages'], 60);
    });
  });

  group('LocalSessionRepository — streak', () {
    test('retorna 0 quando não há sessões', () async {
      final streak = await LocalSessionRepository().fetchStreak(_uid);
      expect(streak, 0);
    });

    test('retorna 1 quando há sessão apenas hoje', () async {
      final repo = LocalSessionRepository();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await repo.insert(_sessionMap(
        id: 's-1',
        bookId: 'b-1',
        startedAt: '${today}T10:00:00.000Z',
      ));
      final streak = await repo.fetchStreak(_uid);
      expect(streak, 1);
    });

    test('retorna 3 quando há sessões nos últimos 3 dias consecutivos', () async {
      final repo = LocalSessionRepository();
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final day = now
            .subtract(Duration(days: i))
            .toIso8601String()
            .substring(0, 10);
        await repo.insert(_sessionMap(
          id: 's-$i',
          bookId: 'b-1',
          startedAt: '${day}T10:00:00.000Z',
        ));
      }
      final streak = await repo.fetchStreak(_uid);
      expect(streak, 3);
    });

    test('quebra o streak quando há um dia faltando', () async {
      final repo = LocalSessionRepository();
      final now = DateTime.now();

      // Hoje e há 3 dias (pulando ontem e anteontem)
      final today = now.toIso8601String().substring(0, 10);
      final threeDaysAgo = now
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .substring(0, 10);

      await repo.insert(_sessionMap(
          id: 's-1', bookId: 'b-1', startedAt: '${today}T10:00:00.000Z'));
      await repo.insert(_sessionMap(
          id: 's-2', bookId: 'b-1', startedAt: '${threeDaysAgo}T10:00:00.000Z'));

      final streak = await repo.fetchStreak(_uid);
      // Apenas hoje conta como streak contínuo
      expect(streak, 1);
    });
  });
}
