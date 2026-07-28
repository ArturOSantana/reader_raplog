/// Interface da Notification Platform da plataforma Lumen.
///
/// Unifica Push, Email, Inbox e Web Notification em um único contrato.
/// Nenhuma parte do app deve enviar notificação sem passar por esta interface.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationChannel { push, email, inbox, web }

/// Eventos que podem disparar notificações — enum canônico da plataforma.
enum NotificationEvent {
  newFollower,
  newComment,
  clubInvite,
  checkIn,
  challenge,
  newBook,
  clubUpdate,
  billing,
  system,
}

class NotificationPayload {
  final NotificationEvent event;
  final String recipientUserId;
  final String title;
  final String body;
  final Map<String, String> data;
  final List<NotificationChannel> channels;

  const NotificationPayload({
    required this.event,
    required this.recipientUserId,
    required this.title,
    required this.body,
    this.data = const {},
    this.channels = const [NotificationChannel.inbox],
  });
}

class NotificationPreference {
  final NotificationEvent event;
  final NotificationChannel channel;
  final bool enabled;

  const NotificationPreference({
    required this.event,
    required this.channel,
    required this.enabled,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class NotificationProvider {
  /// Envia uma notificação de acordo com os canais especificados no payload.
  Future<void> send(NotificationPayload payload);

  /// Retorna as preferências de notificação de um usuário.
  Future<List<NotificationPreference>> fetchPreferences(String userId);

  /// Salva as preferências de notificação de um usuário.
  Future<void> savePreference(String userId, NotificationPreference pref);
}
