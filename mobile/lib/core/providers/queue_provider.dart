/// Interface da Queue Platform da plataforma Lumen.
///
/// Toda operação assíncrona pesada (email, push, IA, mídia, LGPD) deve entrar
/// em fila — nunca bloquear a request principal.
///
/// Implementações futuras: BullMQ, Inngest, QStash, Cloud Tasks.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Filas canônicas da plataforma
// ─────────────────────────────────────────────────────────────────────────────

abstract final class QueueNames {
  QueueNames._();

  static const String email           = 'queue:email';
  static const String push            = 'queue:push';
  static const String googleBooks     = 'queue:google_books';
  static const String analytics       = 'queue:analytics';
  static const String reviews         = 'queue:reviews';
  static const String billing         = 'queue:billing';
  static const String lgpd            = 'queue:lgpd';
  static const String recommendations = 'queue:recommendations';
  static const String mediaProcessing = 'queue:media';
  static const String ai              = 'queue:ai';
}

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

class QueueJob {
  final String queue;
  final Map<String, dynamic> payload;
  final int maxRetries;
  final Duration? delay;

  const QueueJob({
    required this.queue,
    required this.payload,
    this.maxRetries = 3,
    this.delay,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class QueueProvider {
  /// Enfileira um job. Retorna o ID gerado pelo sistema de filas.
  Future<String> enqueue(QueueJob job);

  /// Enfileira múltiplos jobs em lote.
  Future<List<String>> enqueueBatch(List<QueueJob> jobs);

  /// Retorna o tamanho atual de uma fila.
  Future<int> size(String queue);

  /// Identificador da implementação para auditoria.
  String get providerName;
}
