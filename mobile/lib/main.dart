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
import 'core/services/reading_notification_service.dart';
import 'core/services/streak_reminder_service.dart';
import 'core/widgets/widget_manager.dart';
import 'theme/lumen_theme.dart';

// O app segue sempre o tema do sistema operacional (ThemeMode.system).
// Para alterar os tokens de cor ou tipografia, edite lib/theme/lumen_theme.dart.

Future<void> main() async {
  // Configura hooks de erro do Flutter → ObservabilityService.
  // Em Fase 3, este serviço encaminhará para Sentry.
  setupObservabilityHooks();

  // runZonedGuarded captura qualquer exceção não tratada durante a vida do app.
  // O boot já usa try/catch em cada etapa, portanto este handler cobre apenas
  // erros verdadeiramente inesperados após o runApp.
  runZonedGuarded(_bootAndRun, (error, stack) {
    ObservabilityService.instance.captureFatal(
      error,
      stack,
      context: 'uncaught_zone_error',
    );
  });
}

Future<void> _bootAndRun() async {
  // Inicializa bindings na mesma zona onde runApp será chamado
  WidgetsFlutterBinding.ensureInitialized();

  // Bloqueia orientação em portrait (padrão para apps de leitura)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // No Web com --dart-define, as variáveis chegam em tempo de compilação —
  // não há arquivo .env bundled (evita exposição via HTTP em assets/).
  // No mobile/desktop carrega normalmente via flutter_dotenv.
  if (!kIsWeb) {
    // Falha silenciosa se .env não existir — AppEnv.supabaseUrl lançará
    // AppEnvException abaixo com mensagem clara para o desenvolvedor.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Arquivo ausente em produção é esperado quando variáveis chegam
      // via --dart-define. Em mobile, o AppEnv lançará AppEnvException
      // com diagnóstico claro se as variáveis não estiverem disponíveis.
    }
  }

  // Inicializa Supabase com timeout de 10s para não travar o splash em redes lentas.
  // Todos os erros são capturados: o runApp sempre será chamado, garantindo que
  // o app nunca fique em tela preta por falha no boot.
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppEnv.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
  } on AppEnvException catch (e, s) {
    // .env ausente ou mal configurado: o Supabase não foi inicializado.
    // O app mostrará uma tela de erro de configuração no lugar do splash.
    ObservabilityService.instance.captureError(
      e,
      s,
      context: 'supabase.initialize.env_missing',
    );
    runApp(_ConfigErrorApp(message: e.message));
    return;
  } on TimeoutException {
    // Continua sem conexão — o app mostrará banner offline.
    ObservabilityService.instance.log(
      ObsLevel.warning,
      'supabase.initialize.timeout',
    );
  } catch (e, s) {
    // Qualquer outro erro de inicialização do Supabase não deve impedir o boot.
    ObservabilityService.instance.captureError(
      e,
      s,
      context: 'supabase.initialize.error',
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

  // Inicializa o plugin de notificações locais para que o pedido de permissão
  // iOS aconteça no launch e o canal Android seja registrado antes do primeiro uso.
  // Falha silenciosa: não impede o boot.
  if (!kIsWeb) {
    try {
      await ReadingNotificationService.instance.init();
    } catch (e, s) {
      ObservabilityService.instance.captureError(
        e,
        s,
        context: 'reading_notification_service.init',
      );
    }

    try {
      await StreakReminderService.instance.init();
    } catch (e, s) {
      ObservabilityService.instance.captureError(
        e,
        s,
        context: 'streak_reminder_service.init',
      );
    }
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
      theme: LumenTheme.light(),
      darkTheme: LumenTheme.dark(),
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

/// Exibido quando o Supabase não pôde ser inicializado por falta de
/// variáveis de ambiente (.env ausente ou chaves inválidas).
///
/// Evita tela preta — mostra uma mensagem clara ao usuário/desenvolvedor.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B4332),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Erro de configuração',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
