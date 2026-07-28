/// Barrel file — re-exporta todas as interfaces de provider da plataforma.
///
/// Todo código do app que precisar de um provider de plataforma deve importar
/// apenas este arquivo, nunca os arquivos de interface diretamente.
///
/// ```dart
/// import 'package:lumen/core/providers/platform_providers.dart';
/// ```
library;

export 'analytics_provider.dart';
export 'book_metadata_provider.dart';
export 'cache_provider.dart';
export 'notification_provider.dart';
export 'payment_provider.dart';
export 'queue_provider.dart';
export 'search_provider.dart';
export 'storage_provider.dart';
