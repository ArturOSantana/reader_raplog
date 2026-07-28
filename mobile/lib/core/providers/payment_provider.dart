/// Interface de pagamento da plataforma Lumen.
///
/// Desacopla o app do Stripe, Apple IAP, Google Play Billing ou qualquer
/// outro gateway. O app nunca deve importar stripe_sdk diretamente.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

enum SubscriptionStatus { active, canceled, pastDue, trialing, incomplete }

class SubscriptionInfo {
  final String id;
  final String userId;
  final String planId;
  final SubscriptionStatus status;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String? paymentProvider;

  const SubscriptionInfo({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    this.paymentProvider,
  });

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;
}

class PaymentMethod {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class PaymentProvider {
  /// Retorna a assinatura ativa do usuário, ou `null` se não tiver.
  Future<SubscriptionInfo?> fetchSubscription(String userId);

  /// Cria ou troca de plano. Retorna URL de checkout ou `null` se nativo.
  Future<String?> createCheckoutSession({
    required String userId,
    required String planId,
    String? successUrl,
    String? cancelUrl,
  });

  /// Cancela a assinatura ao final do período atual.
  Future<void> cancelSubscription(String subscriptionId);

  /// Lista os métodos de pagamento cadastrados.
  Future<List<PaymentMethod>> fetchPaymentMethods(String userId);

  /// Identificador do provider para auditoria.
  String get providerName;
}
