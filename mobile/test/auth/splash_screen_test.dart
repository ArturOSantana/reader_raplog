import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lumen/features/splash/presentation/screens/splash_screen.dart';
import 'package:lumen/shared/providers/providers.dart';
import 'package:lumen/core/theme/app_theme.dart';
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
    /// Cria o widget com o stream de auth mockado e um router mínimo.
    Widget buildSplash() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const SplashScreen(),
          ),
          GoRoute(
            path: '/auth/login',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => const Stream.empty()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      );
    }

    testWidgets('exibe o nome "Lumen"', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump(); // processa o primeiro frame

      expect(find.text('Lumen'), findsOneWidget);
    });

    testWidgets('exibe o subtítulo "Seu companheiro de leitura"', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.text('Seu companheiro de leitura'), findsOneWidget);
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
