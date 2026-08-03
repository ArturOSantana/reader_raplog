import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gerencia a notificação persistente exibida na barra de status
/// enquanto uma sessão de leitura está em andamento.
class ReadingNotificationService {
  ReadingNotificationService._();
  static final ReadingNotificationService instance =
      ReadingNotificationService._();

  static const int _sessionNotifId = 1;
  static const int _inactivityNotifId = 2;
  static const String _channelId = 'reading_session';
  static const String _channelName = 'Sessão de leitura';
  static const String _alertChannelId = 'reading_alert';
  static const String _alertChannelName = 'Alertas de leitura';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('ic_reading_notification');

    // iOS/macOS: solicita permissão de alerta e som na primeira inicialização.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false, // notificações de sessão não precisam de som
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: Platform.isIOS ? darwinSettings : null,
      macOS: Platform.isMacOS ? darwinSettings : null,
    );
    await _plugin.initialize(settings);

    _initialized = true;
  }

  Future<void> _ensurePermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // ── Notificação persistente (sessão ativa) ────────────────────────────────

  /// Exibe/atualiza a notificação persistente com o título do livro e tempo.
  Future<void> show({
    required String bookTitle,
    required String elapsed,
  }) async {
    await init();
    await _ensurePermission();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Indica que uma sessão de leitura está em progresso',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_reading_notification',
    );

    await _plugin.show(
      _sessionNotifId,
      'Lendo: $bookTitle',
      elapsed,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Atualiza a notificação para indicar sessão pausada.
  Future<void> showPaused({
    required String bookTitle,
    required String elapsed,
  }) async {
    await init();
    await _ensurePermission();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Indica que uma sessão de leitura está em progresso',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_reading_notification',
    );

    await _plugin.show(
      _sessionNotifId,
      '⏸ Pausado: $bookTitle',
      'Retomado em $elapsed',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Notificação de alerta: sessão parada há 30 min sem pausa.
  Future<void> showInactivityAlert({required String bookTitle}) async {
    await init();
    await _ensurePermission();

    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: 'Alerta quando a sessão parece inativa',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      icon: 'ic_reading_notification',
    );

    await _plugin.show(
      _inactivityNotifId,
      'Sua sessão continua?',
      'Você ainda está lendo "$bookTitle"?',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Remove a notificação persistente de sessão.
  Future<void> dismiss() async {
    await _plugin.cancel(_sessionNotifId);
    await _plugin.cancel(_inactivityNotifId);
  }
}
