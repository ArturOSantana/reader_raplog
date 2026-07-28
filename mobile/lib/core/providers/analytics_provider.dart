/// Interface de Analytics da plataforma Lumen.
///
/// Todos os eventos da plataforma passam por esta interface.
/// Nunca chamar PostHog, GA4 ou BigQuery diretamente no código do app.
///
/// Futuro: PostHog, BigQuery, GA4.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Eventos canônicos da plataforma
// ─────────────────────────────────────────────────────────────────────────────

/// Nomes de evento padronizados — usar sempre estas constantes,
/// nunca strings literais espalhadas pelo código.
abstract final class AnalyticsEvents {
  AnalyticsEvents._();

  // Livros
  static const String bookViewed       = 'book_viewed';
  static const String bookStarted      = 'book_started';
  static const String bookFinished     = 'book_finished';

  // Leitura
  static const String readingStarted   = 'reading_started';
  static const String readingFinished  = 'reading_finished';
  static const String readingPaused    = 'reading_paused';

  // Social
  static const String reviewCreated    = 'review_created';
  static const String reviewLiked      = 'review_liked';
  static const String bookShared       = 'book_shared';

  // Clubs
  static const String clubJoined       = 'club_joined';
  static const String clubLeft         = 'club_left';

  // Busca
  static const String searchPerformed  = 'search_performed';

  // Assinatura
  static const String subscriptionStarted   = 'subscription_started';
  static const String subscriptionCancelled = 'subscription_cancelled';

  // Onboarding
  static const String onboardingCompleted = 'onboarding_completed';
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class AnalyticsProvider {
  /// Registra um evento nomeado com propriedades opcionais.
  ///
  /// [name] deve ser uma das constantes de [AnalyticsEvents].
  /// [properties] são pares chave-valor simples (String, num, bool).
  ///
  /// ⚠ Nunca passar dados pessoais (email, nome, CPF) em [properties].
  Future<void> track(
    String name, {
    Map<String, Object?> properties = const {},
  });

  /// Associa o usuário autenticado ao contexto de analytics.
  /// Nunca passar email ou nome — apenas ID opaco.
  Future<void> identify(String userId, {Map<String, Object?> traits = const {}});

  /// Remove a associação do usuário (logout).
  Future<void> reset();

  /// Envia todos os eventos pendentes em buffer.
  Future<void> flush();
}
