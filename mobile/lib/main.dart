import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_env.dart';
import 'core/local/local_database.dart';
import 'core/observability/observability_service.dart';
import 'core/router/app_router.dart';
import 'core/router/route_persistence.dart';
import 'core/widgets/widget_manager.dart';
import 'theme/readlog_theme.dart';

// O app segue sempre o tema do sistema operacional (ThemeMode.system).
// Para alterar os tokens de cor ou tipografia, edite lib/theme/readlog_theme.dart.

Future<void> main() async {
  // runZonedGuarded captura qualquer exceção não tratada no boot (antes do
  // runApp) e durante a vida do app, garantindo que erros de inicialização
  // sejam reportados ao ObservabilityService em vez de causar crash silencioso.
  await runZonedGuarded(_boot, (error, stack) {
    ObservabilityService.instance.captureFatal(
      error,
      stack,
      context: 'uncaught_zone_error',
    );
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura hooks de erro do Flutter → ObservabilityService.
  // Em Fase 3, este serviço encaminhará para Sentry.
  setupObservabilityHooks();

  // Bloqueia orientação em portrait (padrão para apps de leitura)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // No Web com --dart-define, as variáveis chegam em tempo de compilação —
  // não há arquivo .env bundled (evita exposição via HTTP em assets/).
  // No mobile/desktop carrega normalmente via flutter_dotenv.
  if (!kIsWeb) {
    await dotenv.load(fileName: '.env');
  }

  // Inicializa Supabase com timeout de 10s para não travar o splash em redes lentas.
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppEnv.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    // Continua sem conexão — o app mostrará banner offline.
    ObservabilityService.instance.log(
      ObsLevel.warning,
      'supabase.initialize.timeout',
    );
  }

  await initializeDateFormatting('pt_BR');

  // Inicializa banco SQLite antes do runApp.
  // Se o banco falhar (ex: migração corrompida), recria do zero para não
  // bloquear o usuário indefinidamente.
  try {
    await LocalDatabase.instance.db;
  } catch (e, s) {
    ObservabilityService.instance.captureError(
      e,
      s,
      context: 'local_database.open',
    );
    // Tenta recriar o banco zerado como último recurso.
    await LocalDatabase.instance.deleteAndRecreate();
  }

  // Inicializa plugin de widgets nativos (Android / iOS).
  // Falha silenciosa: widgets nativos são opcionais e não devem impedir o boot.
  try {
    await WidgetManager.init();
  } catch (e, s) {
    ObservabilityService.instance.captureError(
      e,
      s,
      context: 'widget_manager.init',
    );
  }

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
      title: 'Lumen',
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
