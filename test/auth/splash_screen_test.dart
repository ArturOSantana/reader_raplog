import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/features/splash/presentation/screens/splash_screen.dart';
import 'package:readlog/shared/providers/providers.dart';
import 'package:readlog/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementação em memória de [GotrueAsyncStorage] para testes.
/// Evita que o Supabase use shared_preferences durante os testes de widget.
class _InMemoryAsyncStorage implements GotrueAsyncStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

/// Inicializa o Supabase com credenciais falsas e storage em memória,
/// evitando qualquer dependência de plugins nativos (shared_preferences).
Future<void> _initFakeSupabase() async {
  try {
    Supabase.instance; // retorna se já inicializado
  } catch (_) {
    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      // ignore: deprecated_member_use
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoxNjAwMDAwMDAwfQ.fake',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryAsyncStorage(),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _initFakeSupabase();
  });

  group('SplashScreen — estrutura visual', () {
    /// Cria o widget com o stream de auth mockado (vazio = sem navegação automática).
    Widget buildSplash() {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SplashScreen(),
        ),
      );
    }

    testWidgets('exibe o nome "ReadLog"', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump(); // processa o primeiro frame

      expect(find.text('ReadLog'), findsOneWidget);
    });

    testWidgets('exibe o subtítulo "Seu diário de leitura"', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.text('Seu diário de leitura'), findsOneWidget);
    });

    testWidgets('exibe o indicador de carregamento (CircularProgressIndicator)',
        (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe ícone de livro', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('fundo é verde (forestGreen / ink)', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.forestGreen);
    });
  });
}
