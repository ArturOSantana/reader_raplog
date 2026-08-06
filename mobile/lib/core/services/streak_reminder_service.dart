import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerencia notificações locais para:
///  - Ofensiva em risco  → se o usuário não abrir/ler no dia corrente
///  - Inatividade geral  → mais de 2 dias sem leitura
///  - Atividade de clube → lembrete genérico para não perder a participação
///
/// As notificações são agendadas cada vez que [schedule] é chamado
/// (tipicamente ao abrir o app ou ao fechar sessão).  A lógica é simples:
/// agendamos notificações para daqui a N horas caso o usuário não volte;
/// ao voltar, chamamos [cancel] antes de reagendar.
class StreakReminderService {
  StreakReminderService._();
  static final StreakReminderService instance = StreakReminderService._();

  // IDs de notificação
  static const int _streakAtRiskId   = 10;
  static const int _inactivityId     = 11;
  static const int _clubReminderId   = 12;

  // Canais Android
  static const String _streakChannelId   = 'streak_reminder';
  static const String _streakChannelName = 'Ofensiva de leitura';
  static const String _clubChannelId     = 'club_reminder';
  static const String _clubChannelName   = 'Clube de leitura';

  // Chave de SharedPreferences para registrar última vez que leu
  static const _lastReadKey = 'streak_last_read_date';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('ic_reading_notification');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // pedido feito explicitamente pelo app
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: Platform.isIOS ? darwinSettings : null,
      macOS: Platform.isMacOS ? darwinSettings : null,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  // ── Permissão ─────────────────────────────────────────────────────────────

  /// Solicita permissão de notificação (Android 13+ e iOS).
  /// Retorna `true` se a permissão foi concedida.
  Future<bool> requestPermission() async {
    await init();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      return granted;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }

    return true; // macOS / desktop — permissão não aplicável
  }

  /// Verifica se as notificações estão habilitadas (Android 13+ / iOS).
  Future<bool> areNotificationsEnabled() async {
    await init();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    // iOS: não há API síncrona — assume habilitado se já passamos da permissão
    return true;
  }

  // ── API principal ─────────────────────────────────────────────────────────

  /// Registra que o usuário leu hoje.  Cancela lembretes pendentes e reagenda
  /// para o dia seguinte (caso o usuário não abra o app novamente).
  Future<void> onUserRead({int currentStreak = 0}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    await prefs.setString(_lastReadKey, today);

    // Cancela alertas do dia atual (usuário já leu)
    await cancel();

    // Agenda alerta para ~21h do mesmo dia se streak > 0 (para proteger ofensiva)
    // e para 36h depois (inatividade) para todos os casos
    if (currentStreak > 0) {
      await _scheduleStreakAtRisk(currentStreak);
    }
    await _scheduleInactivity();
  }

  /// Verifica o estado ao abrir o app e agenda/cancela lembretes conforme necessário.
  Future<void> onAppOpen({int currentStreak = 0}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final lastRead = prefs.getString(_lastReadKey);
    final today = _dateKey(DateTime.now());

    // Se já leu hoje, cancela alertas
    if (lastRead == today) {
      await cancel();
      return;
    }

    // Se streak > 0, agenda alerta de ofensiva em risco para daqui a 3h
    // (ou para as 21h de hoje, o que vier primeiro)
    if (currentStreak > 0) {
      await _scheduleStreakAtRisk(currentStreak);
    }
    await _scheduleInactivity();
  }

  /// Agenda lembrete de atividade de clube.
  Future<void> scheduleClubReminder({
    required String clubName,
    String? message,
  }) async {
    await init();

    final body = message ?? 'Não perca as novidades do clube "$clubName"!';

    final androidDetails = AndroidNotificationDetails(
      _clubChannelId,
      _clubChannelName,
      channelDescription: 'Lembretes de atividade nos clubes de leitura',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_reading_notification',
    );

    await _plugin.show(
      _clubReminderId,
      '📚 $clubName',
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Cancela todos os lembretes gerenciados por este serviço.
  Future<void> cancel() async {
    await _plugin.cancel(_streakAtRiskId);
    await _plugin.cancel(_inactivityId);
    await _plugin.cancel(_clubReminderId);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _scheduleStreakAtRisk(int streak) async {
    final days = streak == 1 ? '1 dia' : '$streak dias';

    final androidDetails = AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: 'Alerta para não perder a ofensiva de leitura',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_reading_notification',
    );

    // Mostra agora como notificação diferida (sem API de agendamento exato
    // para manter compatibilidade com Android 12+ sem permissão SCHEDULE_EXACT_ALARM)
    await _plugin.show(
      _streakAtRiskId,
      '🔥 Sua ofensiva está em risco!',
      'Você tem $days de sequência. Leia algo hoje para não perder!',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _scheduleInactivity() async {
    const androidDetails = AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: 'Alerta para não perder a ofensiva de leitura',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_reading_notification',
    );

    await _plugin.show(
      _inactivityId,
      '📖 Saudades de você!',
      'Faz um tempinho que você não lê. Que tal retomar agora?',
      NotificationDetails(android: androidDetails),
    );
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
