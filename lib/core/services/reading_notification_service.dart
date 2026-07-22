import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gerencia a notificação persistente exibida na barra de status
/// enquanto uma sessão de leitura está em andamento.
class ReadingNotificationService {
  ReadingNotificationService._();
  static final ReadingNotificationService instance =
      ReadingNotificationService._();

  static const int _notificationId = 1;
  static const String _channelId = 'reading_session';
  static const String _channelName = 'Sessão de leitura';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('ic_reading_notification');

    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    _initialized = true;
  }

  /// Exibe a notificação persistente com o título do livro e o tempo decorrido.
  Future<void> show({required String bookTitle, required String elapsed}) async {
    await init();

    // Solicita permissão em Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

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

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notificationId,
      '📖 Lendo: $bookTitle',
      elapsed,
      details,
    );
  }

  /// Remove a notificação persistente.
  Future<void> dismiss() async {
    await _plugin.cancel(_notificationId);
  }
}
