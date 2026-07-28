/// Serviço de Observabilidade da plataforma Lumen.
///
/// Centraliza error tracking, health checks e log estruturado.
///
/// Design:
/// - Fase 1B: log estruturado local + hooks de erro do Flutter.
/// - Fase 3: Sentry SDK, OpenTelemetry, alertas.
///
/// Uso:
/// ```dart
/// final obs = ref.read(obsProvider);
///
/// // Logar evento estruturado
/// obs.log(ObsLevel.info, 'book.search', {'query': q, 'results': 5});
///
/// // Capturar erro não-fatal
/// obs.captureError(e, stack, context: 'google_books.search');
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Nível de log
// ─────────────────────────────────────────────────────────────────────────────

enum ObsLevel { debug, info, warning, error, fatal }

// ─────────────────────────────────────────────────────────────────────────────
// Health check
// ─────────────────────────────────────────────────────────────────────────────

enum HealthStatus { healthy, degraded, down }

class HealthCheckResult {
  final String service;
  final HealthStatus status;
  final String? message;
  final Duration? latency;
  final DateTime checkedAt;

  const HealthCheckResult({
    required this.service,
    required this.status,
    this.message,
    this.latency,
    required this.checkedAt,
  });

  @override
  String toString() =>
      'HealthCheckResult(service: $service, status: ${status.name}, '
      'latency: ${latency?.inMilliseconds}ms)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviço
// ─────────────────────────────────────────────────────────────────────────────

class ObservabilityService {
  ObservabilityService._();

  static final ObservabilityService instance = ObservabilityService._();

  // ── Log estruturado ───────────────────────────────────────────────────────

  /// Registra um evento com nível, nome e propriedades opcionais.
  ///
  /// Em debug: formata e imprime no console.
  /// Em produção (Fase 3): encaminhará para Sentry Breadcrumb / OTEL span.
  ///
  /// ⚠ Nunca passar dados pessoais (email, nome, token) em [properties].
  void log(
    ObsLevel level,
    String event, [
    Map<String, Object?> properties = const {},
  ]) {
    if (!kDebugMode && level == ObsLevel.debug) return;

    final ts = DateTime.now().toIso8601String();
    final lvl = level.name.toUpperCase().padRight(7);
    final props = properties.isEmpty ? '' : ' | ${_formatProps(properties)}';
    debugPrint('[$ts] $lvl $event$props');
  }

  // ── Error tracking ────────────────────────────────────────────────────────

  /// Captura um erro não-fatal.
  ///
  /// Em produção (Fase 3): chamar `Sentry.captureException()`.
  void captureError(
    Object error,
    StackTrace? stack, {
    String? context,
    Map<String, Object?> extras = const {},
  }) {
    final msg = '${error.runtimeType}: ${_sanitize(error.toString())}';
    log(ObsLevel.error, context ?? 'unhandled_error', {
      'error': msg,
      if (extras.isNotEmpty) ...extras,
    });

    if (kDebugMode && stack != null) {
      debugPrint(stack.toString().split('\n').take(8).join('\n'));
    }

    // TODO(Fase 3): Sentry.captureException(error, stackTrace: stack)
  }

  /// Captura um erro fatal — deve sempre ser reportado, mesmo em produção.
  void captureFatal(
    Object error,
    StackTrace? stack, {
    String? context,
  }) {
    captureError(error, stack, context: context ?? 'fatal');
    // TODO(Fase 3): Sentry com SentryLevel.fatal
  }

  // ── Health Checks ─────────────────────────────────────────────────────────

  /// Executa um health check em um serviço.
  /// O [check] deve retornar `true` se o serviço estiver saudável.
  Future<HealthCheckResult> checkService(
    String service,
    Future<bool> Function() check, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final healthy = await check().timeout(timeout);
      sw.stop();
      return HealthCheckResult(
        service: service,
        status: healthy ? HealthStatus.healthy : HealthStatus.degraded,
        latency: sw.elapsed,
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      sw.stop();
      return HealthCheckResult(
        service: service,
        status: HealthStatus.down,
        message: _sanitize(e.toString()),
        latency: sw.elapsed,
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Executa health checks em todos os serviços em paralelo.
  Future<List<HealthCheckResult>> checkAll(
    Map<String, Future<bool> Function()> checks,
  ) =>
      Future.wait(checks.entries.map((e) => checkService(e.key, e.value)));

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatProps(Map<String, Object?> p) =>
      p.entries.map((e) => '${e.key}=${e.value}').join(', ');

  /// Remove dados potencialmente sensíveis de mensagens.
  String _sanitize(String message) => message
      .replaceAll(
          RegExp(r'Bearer [A-Za-z0-9\-._~+\/]+=*'), 'Bearer [REDACTED]')
      .replaceAll(RegExp(r'key=[A-Za-z0-9_\-]+'), 'key=[REDACTED]')
      .replaceAll(
          RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'),
          '[EMAIL]');
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

final obsProvider = Provider<ObservabilityService>(
  (_) => ObservabilityService.instance,
  name: 'obsProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// Hooks de erro do Flutter — chamar em main()
// ─────────────────────────────────────────────────────────────────────────────

/// Configura os hooks globais do Flutter para encaminhar erros ao
/// [ObservabilityService].
///
/// Deve ser chamado uma única vez, antes de [runApp]:
///
/// ```dart
/// void main() {
///   setupObservabilityHooks();
///   runApp(const ProviderScope(child: LumenApp()));
/// }
/// ```
void setupObservabilityHooks() {
  final obs = ObservabilityService.instance;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    obs.captureError(
      details.exception,
      details.stack,
      context: 'flutter_framework',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    obs.captureFatal(error, stack, context: 'platform_dispatcher');
    return true;
  };
}
