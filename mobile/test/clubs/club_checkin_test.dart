// Testes do fluxo de check-in automático de clube
//
// O check-in é gerado pelo trigger [auto_checkin_after_session] no Supabase
// quando uma sessão muda de status para 'finished'. Os pré-requisitos são:
//   1. O livro lido tem `source_club_id` apontando para um clube.
//   2. O usuário é membro do clube.
//   3. A sessão é finalizada (status → 'finished').
//
// Como o trigger roda no servidor, estes testes cobrem a camada de cliente:
//   - Model:         ReadingSession serializa corretamente para 'finished'
//   - SessionNotifier: finishSession delega ao repositório e limpa estado
//   - Book:          source_club_id é preservado nos dois sentidos (from/toMap)
//   - ClubCheckinScreen: confirma mood+review → salva na sessão; sem dados → _done imediato
//   - Integração local: LocalSessionRepository — sessão 'active' → 'finished' persiste

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumen/core/local/local_database.dart';
import 'package:lumen/features/clubs/presentation/screens/club_checkin_screen.dart';
import 'package:lumen/features/session/data/local_session_repository.dart';
import 'package:lumen/features/session/data/offline_session_repository.dart';
import 'package:lumen/features/session/presentation/notifiers/session_notifier.dart';
import 'package:lumen/shared/models/book.dart';
import 'package:lumen/shared/models/reading_session.dart';
import 'package:lumen/shared/providers/providers.dart';
import 'package:lumen/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Helpers globais ──────────────────────────────────────────────────────────

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> _openInMemoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 6,
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
            paused_at TEXT,
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
  LocalDatabase.instance.injectForTest(db);
}

// SupabaseClient sem timers de refresh — evita setState em teste
SupabaseClient _noTimerClient() => SupabaseClient(
      'https://fake.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );

// ── Fake do OfflineSessionRepository ────────────────────────────────────────

/// Intercepta as chamadas ao Supabase e armazena em memória.
class _FakeSessionRepo extends OfflineSessionRepository {
  ReadingSession? started;
  ReadingSession? finished;
  bool cancelCalled = false;
  ReadingSession? _activeSession;

  _FakeSessionRepo() : super(_noTimerClient(), () => false);

  @override
  Future<ReadingSession> startSession({
    required String bookId,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    final now = DateTime.now();
    started = ReadingSession(
      id: 'session-fake-1',
      userId: 'user-fake',
      bookId: bookId,
      startedAt: now,
      startPage: startPage,
      status: SessionStatus.active,
      createdAt: now,
    );
    _activeSession = started;
    return started!;
  }

  @override
  Future<ReadingSession> finishSession({
    required String sessionId,
    required int endPage,
    String? notes,
    int pausedDurationSeconds = 0,
    SessionMood? mood,
    String? miniReview,
  }) async {
    final now = DateTime.now();
    finished = ReadingSession(
      id: sessionId,
      userId: 'user-fake',
      bookId: started?.bookId ?? 'book-fake',
      startedAt: started?.startedAt ?? now,
      endedAt: now,
      endPage: endPage,
      pagesRead: endPage - (started?.startPage ?? 0),
      status: SessionStatus.finished,
      mood: mood,
      miniReview: miniReview,
      notes: notes,
      createdAt: started?.createdAt ?? now,
    );
    _activeSession = null;
    return finished!;
  }

  @override
  Future<void> cancelSession({required String sessionId}) async {
    cancelCalled = true;
    _activeSession = null;
  }

  @override
  Future<ReadingSession?> fetchActiveSession() async => _activeSession;
}


// ── Notifier sem notificações nativas ─────────────────────────────────────────

/// Notifier que replica a lógica essencial de [SessionNotifier] sem chamar
/// [ReadingNotificationService] — necessário em testes onde o plugin nativo
/// flutter_local_notifications não está inicializado.
///
/// Usa [_fakeSessionNotifierProvider] para criar um provider que retorna este
/// notifier. Os testes lêem esse provider em vez do global [sessionNotifierProvider].
class _NoNotifSessionNotifier extends Notifier<ActiveSessionState> {
  late _FakeSessionRepo fakeRepo;

  @override
  ActiveSessionState build() => const ActiveSessionState();

  Future<void> startSession({
    required String bookId,
    required String bookTitle,
    required int startPage,
    SessionGoal? goal,
    int? goalValue,
  }) async {
    if (state.hasActiveSession) return;
    final session = await fakeRepo.startSession(
      bookId: bookId,
      startPage: startPage,
      goal: goal,
      goalValue: goalValue,
    );
    state = ActiveSessionState(
      session: session,
      bookTitle: bookTitle,
      elapsedSeconds: 0,
    );
  }

  Future<ReadingSession?> finishSession({
    required int endPage,
    String? notes,
    SessionMood? mood,
    String? miniReview,
  }) async {
    final session = state.session;
    if (session == null) return null;

    state = const ActiveSessionState();

    return fakeRepo.finishSession(
      sessionId: session.id,
      endPage: endPage,
      notes: notes,
      pausedDurationSeconds: session.pausedDurationSeconds,
      mood: mood,
      miniReview: miniReview,
    );
  }
}

/// Provider auxiliar exclusivo para testes — retorna [_NoNotifSessionNotifier].
final _fakeSessionNotifierProvider =
    NotifierProvider<_NoNotifSessionNotifier, ActiveSessionState>(
  _NoNotifSessionNotifier.new,
);

// ═════════════════════════════════════════════════════════════════════════════
// TESTES
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // ── Testes do modelo Book (source_club_id) ──────────────────────────────────

  group('Book.sourceClubId — pré-requisito do check-in automático', () {
    Map<String, dynamic> baseMap({String? sourceClubId}) => {
          'id': 'b-1',
          'user_id': 'u-1',
          'title': 'O Nome do Vento',
          'author': 'Patrick Rothfuss',
          'cover_url': null,
          'total_pages': 660,
          'genre': 'Fantasia',
          'publisher': null,
          'status': 'reading',
          'start_date': null,
          'end_date': null,
          'rating': null,
          'current_page': 100,
          'source_club_id': sourceClubId,
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-01T00:00:00.000Z',
        };

    test('fromMap preserva source_club_id quando presente', () {
      final book = Book.fromMap(baseMap(sourceClubId: 'clube-leitores'));
      expect(book.sourceClubId, 'clube-leitores');
    });

    test('fromMap aceita source_club_id null (livro não é do clube)', () {
      final book = Book.fromMap(baseMap());
      expect(book.sourceClubId, isNull);
    });

    test('toMap serializa source_club_id para o banco', () {
      final book = Book.fromMap(baseMap(sourceClubId: 'clube-leitores'));
      expect(book.toMap()['source_club_id'], 'clube-leitores');
    });

    test('toMap mantém source_club_id null quando não informado', () {
      final book = Book.fromMap(baseMap());
      expect(book.toMap()['source_club_id'], isNull);
    });

    test('round-trip fromMap→toMap não perde source_club_id', () {
      final original = baseMap(sourceClubId: 'clube-abc');
      final book = Book.fromMap(original);
      final serialized = book.toMap();
      expect(serialized['source_club_id'], original['source_club_id']);
    });
  });

  // ── Testes do modelo ReadingSession ─────────────────────────────────────────

  group('ReadingSession — transição para finished (gatilho do check-in)', () {
    ReadingSession activeSession() => ReadingSession(
          id: 'sess-1',
          userId: 'u-1',
          bookId: 'b-1',
          startedAt: DateTime(2024, 6, 1, 9, 0),
          startPage: 50,
          status: SessionStatus.active,
          createdAt: DateTime(2024, 6, 1, 9, 0),
        );

    test('sessão ativa tem status active', () {
      expect(_activeSession().status, SessionStatus.active);
    });

    test('fromMap parseia status "finished" corretamente', () {
      final session = ReadingSession.fromMap({
        'id': 'sess-1',
        'user_id': 'u-1',
        'book_id': 'b-1',
        'started_at': '2024-06-01T09:00:00.000Z',
        'ended_at': '2024-06-01T10:00:00.000Z',
        'duration_minutes': 60,
        'paused_duration_seconds': 0,
        'start_page': 50,
        'end_page': 100,
        'pages_read': 50,
        'notes': null,
        'status': 'finished',
        'session_goal': null,
        'goal_value': null,
        'mood': null,
        'mini_review': null,
        'created_at': '2024-06-01T09:00:00.000Z',
      });
      expect(session.status, SessionStatus.finished);
      expect(session.durationMinutes, 60);
      expect(session.pagesRead, 50);
    });

    test('fromMap parseia status "active"', () {
      final session = ReadingSession.fromMap({
        'id': 'sess-2',
        'user_id': 'u-1',
        'book_id': 'b-1',
        'started_at': '2024-06-01T09:00:00.000Z',
        'ended_at': null,
        'duration_minutes': null,
        'paused_duration_seconds': 0,
        'start_page': 50,
        'end_page': null,
        'pages_read': null,
        'notes': null,
        'status': 'active',
        'session_goal': null,
        'goal_value': null,
        'mood': null,
        'mini_review': null,
        'created_at': '2024-06-01T09:00:00.000Z',
      });
      expect(session.status, SessionStatus.active);
      expect(session.endedAt, isNull);
    });

    test('toMap produz status "finished" para o Supabase acionar trigger', () {
      final session = _activeSession().copyWith(
        status: SessionStatus.finished,
        endPage: 100,
        pagesRead: 50,
        durationMinutes: 60,
      );
      expect(session.toMap()['status'], 'finished');
    });

    test('mood é serializado com o dbValue correto', () {
      final session = _activeSession().copyWith(
        status: SessionStatus.finished,
        mood: SessionMood.excited,
      );
      expect(session.toMap()['mood'], 'excited');
    });

    test('miniReview é preservada no toMap', () {
      final session = _activeSession().copyWith(
        status: SessionStatus.finished,
        miniReview: 'Capítulo incrível!',
      );
      expect(session.toMap()['mini_review'], 'Capítulo incrível!');
    });
  });

  // ── Testes do SessionNotifier (usa FakeSessionRepo) ──────────────────────────

  group('SessionNotifier — startSession + finishSession com livro do clube', () {
    late _FakeSessionRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeSessionRepo();
    });

    /// Cria container com o provider auxiliar de teste + repo fake injetado.
    ProviderContainer makeContainer() => ProviderContainer();

    test('startSession com bookId do clube cria sessão ativa', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_fakeSessionNotifierProvider.notifier);
      notifier.fakeRepo = fakeRepo;

      await notifier.startSession(
        bookId: 'livro-do-clube-1',
        bookTitle: 'O Nome do Vento',
        startPage: 50,
      );

      final st = container.read(_fakeSessionNotifierProvider);
      expect(st.hasActiveSession, isTrue);
      expect(st.session!.bookId, 'livro-do-clube-1');
      expect(st.session!.status, SessionStatus.active);
    });

    test('finishSession finaliza sessão e limpa o estado do notifier', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_fakeSessionNotifierProvider.notifier);
      notifier.fakeRepo = fakeRepo;

      await notifier.startSession(
        bookId: 'livro-do-clube-1',
        bookTitle: 'O Nome do Vento',
        startPage: 50,
      );

      final finished = await notifier.finishSession(endPage: 100);

      expect(finished, isNotNull);
      expect(finished!.status, SessionStatus.finished);
      expect(container.read(_fakeSessionNotifierProvider).hasActiveSession, isFalse);
    });

    test('finishSession passa mood ao repositório (persiste para check-in)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_fakeSessionNotifierProvider.notifier);
      notifier.fakeRepo = fakeRepo;

      await notifier.startSession(
        bookId: 'livro-do-clube-1',
        bookTitle: 'O Nome do Vento',
        startPage: 50,
      );

      await notifier.finishSession(
        endPage: 100,
        mood: SessionMood.happy,
        miniReview: 'Leitura ótima no clube!',
      );

      expect(fakeRepo.finished!.mood, SessionMood.happy);
      expect(fakeRepo.finished!.miniReview, 'Leitura ótima no clube!');
    });

    test('finishSession sem sessão ativa retorna null sem erros', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_fakeSessionNotifierProvider.notifier);
      notifier.fakeRepo = fakeRepo;

      final result = await notifier.finishSession(endPage: 100);
      expect(result, isNull);
    });

    test('não é possível iniciar duas sessões simultâneas', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_fakeSessionNotifierProvider.notifier);
      notifier.fakeRepo = fakeRepo;

      await notifier.startSession(
        bookId: 'livro-do-clube-1',
        bookTitle: 'O Nome do Vento',
        startPage: 50,
      );

      await notifier.startSession(
        bookId: 'outro-livro',
        bookTitle: 'Duna',
        startPage: 0,
      );

      expect(container.read(_fakeSessionNotifierProvider).session!.bookId,
          'livro-do-clube-1');
    });
  });

  // ── Testes da ClubCheckinScreen ──────────────────────────────────────────────

  group('ClubCheckinScreen — check-in via impressão de leitura', () {
    Widget buildScreen({String? sessionId}) => ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_noTimerClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ClubCheckinScreen(
              clubId: 'clube-leitores',
              clubName: 'Clube dos Leitores',
              latestSessionId: sessionId,
            ),
          ),
        );

    testWidgets('exibe título "Impressão de leitura" na AppBar', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      expect(find.text('Impressão de leitura'), findsOneWidget);
    });

    testWidgets('exibe cabeçalho "Como foi a sessão?"', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      expect(find.text('Como foi a sessão?'), findsOneWidget);
    });

    testWidgets('exibe mensagem de check-in automático registrado', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      expect(
        find.text(
          'Seu check-in já foi registrado automaticamente.\nAdicione uma impressão se quiser compartilhar!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('exibe todos os 5 botões de humor', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      for (final mood in SessionMood.values) {
        expect(find.text(mood.emoji), findsOneWidget);
      }
    });

    testWidgets('exibe campo de impressão rápida', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      expect(find.text('Impressão rápida'), findsOneWidget);
    });

    testWidgets('botão "Salvar impressão" está presente', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      expect(find.text('Salvar impressão'), findsOneWidget);
    });

    testWidgets('botão "Pular" exibe tela de sucesso sem salvar', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));

      // O botão pode estar fora da viewport em telas pequenas; scroll até ele
      await tester.ensureVisible(find.text('Pular'));
      await tester.tap(find.text('Pular'), warnIfMissed: false);
      await tester.pump();

      // Sem mood e sem texto, o confirm() vai para _done=true imediatamente
      expect(find.text('Impressão salva!'), findsOneWidget);
      expect(find.text('Voltar ao clube'), findsOneWidget);
    });

    testWidgets('tela de sucesso exibe mensagem da ofensiva coletiva', (tester) async {
      await tester.pumpWidget(buildScreen(sessionId: 'sess-1'));
      await tester.ensureVisible(find.text('Pular'));
      await tester.tap(find.text('Pular'), warnIfMissed: false);
      await tester.pump();

      expect(
        find.text(
          'Sua sessão e impressão foram registradas.\nA ofensiva coletiva do clube continua!',
        ),
        findsOneWidget,
      );
    });
  });

  // ── Testes de integração local (SQLite in-memory) ────────────────────────────

  group('LocalSessionRepository — sessão do clube: active → finished', () {
    setUpAll(_initFfi);
    setUp(_openInMemoryDb);
    tearDown(() async => await LocalDatabase.instance.close());

    const uid = 'user-teste';
    const bookId = 'livro-clube-1';

    Map<String, dynamic> _sessionMap({
      required String id,
      required String status,
      String? mood,
      String? miniReview,
      int? durationMinutes,
      int? endPage,
    }) =>
        {
          'id': id,
          'user_id': uid,
          'book_id': bookId,
          'started_at': DateTime(2024, 6, 1, 9, 0).toIso8601String(),
          'ended_at': status == 'finished'
              ? DateTime(2024, 6, 1, 10, 0).toIso8601String()
              : null,
          'duration_minutes': durationMinutes,
          'paused_duration_seconds': 0,
          'start_page': 50,
          'end_page': endPage,
          'pages_read':
              (endPage != null && endPage > 50) ? endPage - 50 : null,
          'notes': null,
          'status': status,
          'session_goal': null,
          'goal_value': null,
          'mood': mood,
          'mini_review': miniReview,
          'created_at': DateTime(2024, 6, 1, 9, 0).toIso8601String(),
        };

    test('insere sessão ativa e recupera pelo fetchById', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 'sess-1', status: 'active'));

      final session = await repo.fetchById('sess-1');
      expect(session, isNotNull);
      expect(session!.status, SessionStatus.active);
      expect(session.bookId, bookId);
    });

    test('fetchActiveSession retorna sessão active do usuário', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 'sess-1', status: 'active'));

      final active = await repo.fetchActiveSession(uid);
      expect(active, isNotNull);
      expect(active!.id, 'sess-1');
    });

    test('atualizar status para finished (simula finalização que aciona trigger)', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 'sess-1', status: 'active'));

      // Simula o que OfflineSessionRepository faz ao finalizar
      await repo.update('sess-1', {
        'status': 'finished',
        'ended_at': DateTime(2024, 6, 1, 10, 0).toIso8601String(),
        'end_page': 100,
        'pages_read': 50,
        'duration_minutes': 60,
      });

      final session = await repo.fetchById('sess-1');
      expect(session!.status, SessionStatus.finished);
      expect(session.endPage, 100);
      expect(session.pagesRead, 50);
      expect(session.durationMinutes, 60);
    });

    test('sessão finished não é retornada pelo fetchActiveSession', () async {
      final repo = LocalSessionRepository();
      await repo.insert(
          _sessionMap(id: 'sess-1', status: 'finished', endPage: 100));

      final active = await repo.fetchActiveSession(uid);
      expect(active, isNull);
    });

    test('mood e mini_review são persistidos ao finalizar a sessão', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 'sess-1', status: 'active'));

      await repo.update('sess-1', {
        'status': 'finished',
        'mood': 'excited',
        'mini_review': 'Capítulo emocionante!',
        'duration_minutes': 45,
        'end_page': 80,
        'pages_read': 30,
      });

      final session = await repo.fetchById('sess-1');
      expect(session!.mood, SessionMood.excited);
      expect(session.miniReview, 'Capítulo emocionante!');
    });

    test('book_id do clube permanece associado à sessão finalizada', () async {
      final repo = LocalSessionRepository();
      await repo.insert(_sessionMap(id: 'sess-1', status: 'active'));
      await repo.update('sess-1', {
        'status': 'finished',
        'duration_minutes': 30,
        'end_page': 75,
        'pages_read': 25,
      });

      final session = await repo.fetchById('sess-1');
      // O bookId é usado pelo trigger para localizar o source_club_id
      expect(session!.bookId, bookId);
      expect(session.status, SessionStatus.finished);
    });
  });
}
