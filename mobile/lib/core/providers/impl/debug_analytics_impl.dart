/// Implementação de analytics para desenvolvimento.
///
/// Loga todos os eventos no console com formatação estruturada (JSON).
/// Útil para verificar que os eventos corretos estão sendo disparados
/// antes de conectar um provider real como PostHog ou GA4.
///
/// ⚠ NUNCA usar em produção — troca por [NoopAnalyticsImpl] ou
/// [PostHogAnalyticsImpl] no build de release.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../analytics_provider.dart';

class DebugAnalyticsImpl implements AnalyticsProvider {
  const DebugAnalyticsImpl();

  @override
  Future<void> track(
    String name, {
    Map<String, Object?> properties = const {},
  }) async {
    if (!kDebugMode) return;
    final payload = jsonEncode({
      'event': name,
      'ts': DateTime.now().toIso8601String(),
      if (properties.isNotEmpty) 'props': properties,
    });
    // ignore: avoid_print
    debugPrint('[Analytics] $payload');
  }

  @override
  Future<void> identify(
    String userId, {
    Map<String, Object?> traits = const {},
  }) async {
    if (!kDebugMode) return;
    // ignore: avoid_print
    debugPrint('[Analytics] identify: userId=${userId.substring(0, 8)}…');
  }

  @override
  Future<void> reset() async {
    if (!kDebugMode) return;
    // ignore: avoid_print
    debugPrint('[Analytics] reset');
  }

  @override
  Future<void> flush() async {}
}
