import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lê variáveis de ambiente de forma segura por plataforma.
///
/// - **Web (build --release):** usa `--dart-define=KEY=value` injetado em CI.
///   O arquivo `.env` *não* é bundled no Web para evitar exposição via HTTP.
/// - **Mobile / Desktop:** continua usando `flutter_dotenv` (arquivo `.env`
///   bundled no APK/IPA, que é opaco ao usuário final).
abstract final class AppEnv {
  static String get supabaseUrl => _get(
        const String.fromEnvironment('SUPABASE_URL'),
        'SUPABASE_URL',
      );

  static String get supabaseAnonKey => _get(
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
        'SUPABASE_ANON_KEY',
      );

  static String get googleWebClientId => _get(
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
        'GOOGLE_WEB_CLIENT_ID',
      );

  /// Retorna [defineValue] se foi injetado via --dart-define,
  /// ou faz fallback para dotenv (mobile/desktop/dev local).
  static String _get(String defineValue, String key) {
    if (defineValue.isNotEmpty) return defineValue;
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    throw StateError(
      '[AppEnv] Variável "$key" não encontrada. '
      'Web: passe --dart-define=$key=... no build. '
      'Mobile: verifique o arquivo .env.',
    );
  }
}
