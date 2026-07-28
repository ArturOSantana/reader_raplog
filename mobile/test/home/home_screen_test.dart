import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/features/goals/data/goal_repository.dart';
import 'package:readlog/features/library/data/offline_book_repository.dart';
import 'package:readlog/features/session/data/offline_session_repository.dart';
import 'package:readlog/features/home/presentation/screens/home_screen.dart';
import 'package:readlog/shared/models/book.dart';
import 'package:readlog/shared/models/goal.dart';
import 'package:readlog/shared/providers/providers.dart';
import 'package:readlog/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── SupabaseClient sem auto-refresh (sem timers) ──────────────────────────

/// Cria um SupabaseClient com todas as funcionalidades de auto-refresh
/// desabilitadas, para que nenhum timer seja criado durante os testes.
SupabaseClient _noTimerClient() => SupabaseClient(
      'https://fake.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoxNjAwMDAwMDAwfQ.fake',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );

// ─── Fakes ─────────────────────────────────────────────────────────────────

/// Repositório fake de sessões: retorna dados fixos sem tocar no banco.
class _FakeSessionRepository extends OfflineSessionRepository {
  final Map<String, dynamic> _dailyStats;
  final int _streak;

  _FakeSessionRepository({
    Map<String, dynamic>? dailyStats,
    int streak = 0,
  })  : _dailyStats = dailyStats ?? {'total_minutes': 0, 'total_pages': 0},
        _streak = streak,
        super(_noTimerClient(), () => false);

  @override
  Future<Map<String, dynamic>> fetchDailyStats() async => _dailyStats;

  @override
  Future<int> fetchStreak() async => _streak;
}

/// Repositório fake de livros: retorna lista controlada pelo teste.
class _FakeBookRepository extends OfflineBookRepository {
  final List<Book> _books;

  _FakeBookRepository(this._books)
      : super(_noTimerClient(), () => false);

  @override
  Future<List<Book>> fetchAll({BookStatus? status}) async => _books;
}

/// Repositório fake de metas: retorna lista controlada pelo teste.
class _FakeGoalRepository extends GoalRepository {
  final List<Goal> _goals;

  _FakeGoalRepository(this._goals) : super(_noTimerClient());

  @override
  Future<List<Goal>> fetchAll() async => _goals;
}

// ─── Helpers ──────────────────────────────────────────────────────────────

Book _makeBook({
  String id = 'book-1',
  String title = 'Dom Casmurro',
  String author = 'Machado de Assis',
  int? totalPages = 200,
  int? currentPage = 50,
}) =>
    Book(
      id: id,
      userId: 'user-1',
      title: title,
      author: author,
      totalPages: totalPages,
      currentPage: currentPage,
      status: BookStatus.reading,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

Goal _makeGoal({
  GoalType type = GoalType.dailyPages,
  int targetValue = 30,
}) =>
    Goal(
      id: 'goal-1',
      userId: 'user-1',
      type: type,
      period: GoalPeriod.daily,
      targetValue: targetValue,
      createdAt: DateTime(2024),
    );

/// Empacota a HomeScreen com providers mockados — sem dependência do Supabase.
Widget _buildHome({
  _FakeSessionRepository? sessionRepo,
  _FakeBookRepository? bookRepo,
  _FakeGoalRepository? goalRepo,
}) {
  return ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(
        sessionRepo ?? _FakeSessionRepository(),
      ),
      bookRepositoryProvider.overrideWithValue(
        bookRepo ?? _FakeBookRepository([]),
      ),
      goalRepositoryProvider.overrideWithValue(
        goalRepo ?? _FakeGoalRepository([]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const HomeScreen(),
    ),
  );
}

// ─── Testes ───────────────────────────────────────────────────────────────

void main() {
  group('HomeScreen — estado de carregamento', () {
    testWidgets('exibe CircularProgressIndicator enquanto carrega', (tester) async {
      await tester.pumpWidget(_buildHome());
      // Antes de resolver o future, o indicador deve aparecer
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('HomeScreen — lista de leitura vazia', () {
    testWidgets('exibe "Nenhum livro em leitura" quando não há livros', (tester) async {
      await tester.pumpWidget(
        _buildHome(bookRepo: _FakeBookRepository([])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum livro em leitura'), findsOneWidget);
    });

    testWidgets('exibe botão "Adicionar livro" quando lista está vazia', (tester) async {
      await tester.pumpWidget(_buildHome(bookRepo: _FakeBookRepository([])));
      await tester.pumpAndSettle();

      expect(find.text('Adicionar livro'), findsOneWidget);
    });

    testWidgets('exibe botão "Iniciar leitura"', (tester) async {
      await tester.pumpWidget(_buildHome());
      await tester.pumpAndSettle();

      expect(find.text('Iniciar leitura'), findsOneWidget);
    });
  });

  group('HomeScreen — com livros em leitura', () {
    testWidgets('exibe o título do livro em leitura', (tester) async {
      final book = _makeBook(title: 'O Senhor dos Anéis');
      await tester.pumpWidget(
        _buildHome(bookRepo: _FakeBookRepository([book])),
      );
      await tester.pumpAndSettle();

      expect(find.text('O Senhor dos Anéis'), findsOneWidget);
    });

    testWidgets('exibe o autor do livro', (tester) async {
      final book = _makeBook(title: 'Fundação', author: 'Isaac Asimov');
      await tester.pumpWidget(
        _buildHome(bookRepo: _FakeBookRepository([book])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Isaac Asimov'), findsOneWidget);
    });

    testWidgets('não exibe "Nenhum livro em leitura" quando há livros', (tester) async {
      final book = _makeBook();
      await tester.pumpWidget(
        _buildHome(bookRepo: _FakeBookRepository([book])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum livro em leitura'), findsNothing);
    });
  });

  group('HomeScreen — streak e stats', () {
    testWidgets('exibe o streak atual', (tester) async {
      await tester.pumpWidget(
        _buildHome(
          sessionRepo: _FakeSessionRepository(
            dailyStats: {'total_minutes': 45, 'total_pages': 20},
            streak: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('exibe as páginas lidas hoje', (tester) async {
      await tester.pumpWidget(
        _buildHome(
          sessionRepo: _FakeSessionRepository(
            dailyStats: {'total_minutes': 0, 'total_pages': 42},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });
  });

  group('HomeScreen — metas diárias', () {
    testWidgets('exibe barra de progresso quando há meta configurada', (tester) async {
      final goal = _makeGoal(type: GoalType.dailyPages, targetValue: 30);
      await tester.pumpWidget(
        _buildHome(
          sessionRepo: _FakeSessionRepository(
            dailyStats: {'total_minutes': 0, 'total_pages': 15},
          ),
          goalRepo: _FakeGoalRepository([goal]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('exibe "Meta: Páginas por dia" quando tipo é dailyPages', (tester) async {
      final goal = _makeGoal(type: GoalType.dailyPages, targetValue: 30);
      await tester.pumpWidget(
        _buildHome(goalRepo: _FakeGoalRepository([goal])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Páginas por dia'), findsOneWidget);
    });
  });
}
