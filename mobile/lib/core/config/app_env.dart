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

  /// Pode ser vazio — Google Sign-In é opcional quando não configurado.
  static String get googleWebClientId => _getOptional(
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
        'GOOGLE_WEB_CLIENT_ID',
      );

  /// Retorna [defineValue] se foi injetado via --dart-define,
  /// ou faz fallback para dotenv (mobile/desktop/dev local).
  ///
  /// Lança [AppEnvException] (não [StateError]) para que o caller possa
  /// capturar de forma específica sem derrubar o isolate.
  static String _get(String defineValue, String key) {
    if (defineValue.isNotEmpty) return defineValue;
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    throw AppEnvException(
      'Variável "$key" não encontrada. '
      'Web: passe --dart-define=$key=... no build. '
      'Mobile: verifique o arquivo .env na raiz do projeto.',
    );
  }

  /// Igual a [_get] mas retorna string vazia em vez de lançar exceção.
  static String _getOptional(String defineValue, String key) {
    if (defineValue.isNotEmpty) return defineValue;
    return dotenv.maybeGet(key) ?? '';
  }
}

/// Exceção lançada quando uma variável de ambiente obrigatória está ausente.
///
/// Mais específica que [StateError], permite captura direcionada no boot.
class AppEnvException implements Exception {
  const AppEnvException(this.message);
  final String message;

  @override
  String toString() => '[AppEnv] $message';
}
