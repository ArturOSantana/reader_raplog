/// Implementação in-process da Queue Platform (Fase 2A).
///
/// Ideal para desenvolvimento e testes.
/// Em produção, substituir por BullMQImpl / InngestImpl / QStashImpl
/// sem alterar nenhum consumidor (Provider Pattern).
///
/// Cada fila é processada por um único worker isolado com:
/// - Retry automático com back-off exponencial
/// - Dead-letter após maxRetries falhas
/// - Métricas por fila (tamanho, erros, processados, tempo médio)
library;

import 'dart:async';
import 'dart:math' as math;
import '../queue_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelos internos
// ─────────────────────────────────────────────────────────────────────────────

enum _JobStatus { pending, running, failed, deadLetter }

class _JobEntry {
  _JobEntry({required this.id, required this.job})
      : enqueuedAt = DateTime.now();

  final String id;
  final QueueJob job;
  int attempts = 0;
  _JobStatus status = _JobStatus.pending;
  String? lastError;
  final DateTime enqueuedAt;
  DateTime? completedAt;
}

// ─────────────────────────────────────────────────────────────────────────────
// Métricas por fila
// ─────────────────────────────────────────────────────────────────────────────

class QueueMetrics {
  QueueMetrics(this.queueName);

  final String queueName;
  int pending = 0;
  int processed = 0;
  int failed = 0;
  int deadLettered = 0;
  final List<int> _processingTimesMs = [];

  double get avgProcessingTimeMs {
    if (_processingTimesMs.isEmpty) return 0;
    return _processingTimesMs.reduce((a, b) => a + b) /
        _processingTimesMs.length;
  }

  void recordProcessingTime(int ms) {
    _processingTimesMs.add(ms);
    if (_processingTimesMs.length > 100) _processingTimesMs.removeAt(0);
  }

  Map<String, dynamic> toJson() => {
        'queue': queueName,
        'pending': pending,
        'processed': processed,
        'failed': failed,
        'dead_lettered': deadLettered,
        'avg_processing_ms': avgProcessingTimeMs.round(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// InMemoryQueueImpl
// ─────────────────────────────────────────────────────────────────────────────

/// Implementação in-process com workers por fila.
///
/// Uso:
/// ```dart
/// final queue = InMemoryQueueImpl();
///
/// // Registrar handler para cada fila
/// queue.registerHandler(QueueNames.email, (job) async {
///   // enviar email
/// });
///
/// await queue.enqueue(QueueJob(
///   queue: QueueNames.email,
///   payload: {'to': 'user@example.com', 'template': 'welcome'},
/// ));
/// ```
class InMemoryQueueImpl implements QueueProvider {
  InMemoryQueueImpl({this.workerConcurrency = 2});

  /// Número máximo de jobs sendo processados simultaneamente por fila.
  final int workerConcurrency;

  final Map<String, List<_JobEntry>> _queues = {};
  final Map<String, QueueMetrics> _metrics = {};
  final Map<String, Future<void> Function(QueueJob)> _handlers = {};
  final Map<String, int> _activeWorkers = {};
  final _random = math.Random();

  // ── QueueProvider ────────────────────────────────────────────────────────

  @override
  String get providerName => 'InMemoryQueueImpl';

  @override
  Future<String> enqueue(QueueJob job) async {
    final id = _generateId();
    final entry = _JobEntry(id: id, job: job);

    _ensureQueue(job.queue);
    _queues[job.queue]!.add(entry);
    _metrics[job.queue]!.pending++;

    if (job.delay != null && job.delay! > Duration.zero) {
      Timer(job.delay!, () => _triggerWorker(job.queue));
    } else {
      _triggerWorker(job.queue);
    }
    return id;
  }

  @override
  Future<List<String>> enqueueBatch(List<QueueJob> jobs) async {
    return Future.wait(jobs.map(enqueue));
  }

  @override
  Future<int> size(String queue) async {
    return _queues[queue]
            ?.where((e) => e.status == _JobStatus.pending)
            .length ??
        0;
  }

  // ── Handler registration ─────────────────────────────────────────────────

  /// Registra o handler para processar jobs de uma fila.
  /// Sem handler, jobs ficam em `pending` até serem processados.
  void registerHandler(
    String queue,
    Future<void> Function(QueueJob job) handler,
  ) {
    _handlers[queue] = handler;
    _ensureQueue(queue);
    // Processa jobs pendentes acumulados antes do handler ser registrado
    _triggerWorker(queue);
  }

  // ── Métricas ─────────────────────────────────────────────────────────────

  /// Snapshot de métricas de todas as filas.
  List<QueueMetrics> get allMetrics => _metrics.values.toList();

  /// Snapshot de métricas de uma fila específica.
  QueueMetrics? metricsFor(String queue) => _metrics[queue];

  // ── Internals ─────────────────────────────────────────────────────────────

  void _ensureQueue(String queue) {
    _queues.putIfAbsent(queue, () => []);
    _metrics.putIfAbsent(queue, () => QueueMetrics(queue));
    _activeWorkers.putIfAbsent(queue, () => 0);
  }

  void _triggerWorker(String queue) {
    _ensureQueue(queue);
    final active = _activeWorkers[queue]!;
    if (active >= workerConcurrency) return;
    _activeWorkers[queue] = active + 1;
    unawaited(_runWorker(queue));
  }

  Future<void> _runWorker(String queue) async {
    final handler = _handlers[queue];
    if (handler == null) {
      _activeWorkers[queue] = math.max(0, (_activeWorkers[queue] ?? 1) - 1);
      return;
    }

    while (true) {
      final entry = _queues[queue]
          ?.where((e) => e.status == _JobStatus.pending)
          .firstOrNull;

      if (entry == null) break;

      entry.status = _JobStatus.running;
      final startMs = DateTime.now().millisecondsSinceEpoch;

      try {
        await handler(entry.job);
        entry.status = _JobStatus.failed; // marcado como processado (remove)
        entry.completedAt = DateTime.now();
        _metrics[queue]!.pending =
            math.max(0, _metrics[queue]!.pending - 1);
        _metrics[queue]!.processed++;
        _metrics[queue]!.recordProcessingTime(
          DateTime.now().millisecondsSinceEpoch - startMs,
        );
        _queues[queue]!.remove(entry);
      } catch (e) {
        entry.attempts++;
        entry.lastError = e.toString();

        if (entry.attempts >= entry.job.maxRetries) {
          entry.status = _JobStatus.deadLetter;
          _metrics[queue]!.pending =
              math.max(0, _metrics[queue]!.pending - 1);
          _metrics[queue]!.deadLettered++;
          // Mantém na dead-letter por 24h para inspeção
          Timer(const Duration(hours: 24), () {
            _queues[queue]?.remove(entry);
          });
        } else {
          entry.status = _JobStatus.pending;
          _metrics[queue]!.failed++;
          // Back-off exponencial: 1s, 2s, 4s, 8s…
          final backoff = Duration(
            milliseconds: (1000 * math.pow(2, entry.attempts - 1)).round() +
                _random.nextInt(200),
          );
          await Future.delayed(backoff);
        }
      }
    }

    _activeWorkers[queue] = math.max(0, (_activeWorkers[queue] ?? 1) - 1);
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'job_${now.toRadixString(16)}_$rnd';
  }
}
