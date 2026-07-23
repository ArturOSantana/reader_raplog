import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/local/local_database.dart';
import 'core/router/app_router.dart';
import 'core/router/route_persistence.dart';
import 'core/widgets/widget_manager.dart';
import 'theme/readlog_theme.dart';

// O app segue sempre o tema do sistema operacional (ThemeMode.system).
// Para alterar os tokens de cor ou tipografia, edite lib/theme/readlog_theme.dart.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloqueia orientação em portrait (padrão para apps de leitura)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await initializeDateFormatting('pt_BR');

  // Inicializa banco SQLite antes do runApp
  await LocalDatabase.instance.db;

  // Inicializa plugin de widgets nativos (Android / iOS)
  await WidgetManager.init();

  final lastRoute = await loadLastRoute();

  runApp(ProviderScope(
    overrides: [
      initialRouteProvider.overrideWithValue(lastRoute),
    ],
    child: const ReadlogApp(),
  ));
}

class ReadlogApp extends ConsumerWidget {
  const ReadlogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Adapta ícones da status bar conforme o tema do sistema.
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'Readlog',
      debugShowCheckedModeBanner: false,
      theme: ReadLogTheme.light(),
      darkTheme: ReadLogTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Bouncing scroll em todos os lists, mesmo no Android
      scrollBehavior: _ReadlogScrollBehavior(),
    );
  }
}

/// Aplica [BouncingScrollPhysics] em todas as plataformas e mantém
/// gestos de toque habilitados (padrão Material).
class _ReadlogScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
