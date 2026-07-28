/// Implementação do [AnalyticsProvider] que descarta todos os eventos.
///
/// Usada em desenvolvimento, testes ou quando nenhum provider real
/// está configurado. Nunca lança exceções.
library;

import '../analytics_provider.dart';

class NoopAnalyticsImpl implements AnalyticsProvider {
  const NoopAnalyticsImpl();

  @override
  Future<void> track(String name, {Map<String, Object?> properties = const {}}) async {}

  @override
  Future<void> identify(String userId, {Map<String, Object?> traits = const {}}) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> flush() async {}
}
