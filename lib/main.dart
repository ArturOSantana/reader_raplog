import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/local/local_database.dart';
import 'core/router/app_router.dart';
import 'core/router/route_persistence.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await initializeDateFormatting('pt_BR');

  // Inicializa banco SQLite antes do runApp
  await LocalDatabase.instance.db;

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

    return MaterialApp.router(
      title: 'Readlog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
