/// Implementação da Notification Platform via Supabase + Queue (Fase 2A).
///
/// Canais:
///   inbox → salva diretamente na tabela `notifications` do Supabase
///   push, email, web → enfileira via QueueProvider (nunca bloqueia o app)
///
/// Preferências do usuário são respeitadas: se desativado, não envia.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../notification_provider.dart';
import '../queue_provider.dart';

class SupabaseNotificationImpl implements NotificationProvider {
  const SupabaseNotificationImpl({
    required SupabaseClient supabase,
    required QueueProvider queue,
  })  : _supabase = supabase,
        _queue = queue;

  final SupabaseClient _supabase;
  final QueueProvider _queue;

  // ── NotificationProvider ─────────────────────────────────────────────────

  @override
  Future<void> send(NotificationPayload payload) async {
    final prefs = await fetchPreferences(payload.recipientUserId);

    for (final channel in payload.channels) {
      // Verificar preferência do usuário
      final pref = prefs.firstWhere(
        (p) => p.event == payload.event && p.channel == channel,
        orElse: () => NotificationPreference(
          event: payload.event,
          channel: channel,
          enabled: true, // padrão: habilitado
        ),
      );
      if (!pref.enabled) continue;

      switch (channel) {
        case NotificationChannel.inbox:
          await _sendInbox(payload);
        case NotificationChannel.push:
          await _enqueuePush(payload);
        case NotificationChannel.email:
          await _enqueueEmail(payload);
        case NotificationChannel.web:
          await _enqueueWeb(payload);
      }
    }
  }

  @override
  Future<List<NotificationPreference>> fetchPreferences(
    String userId,
  ) async {
    final rows = await _supabase
        .from('notification_preferences')
        .select('event, channel, enabled')
        .eq('user_id', userId);

    return (rows as List<dynamic>).map((row) {
      return NotificationPreference(
        event: _parseEvent(row['event'] as String),
        channel: _parseChannel(row['channel'] as String),
        enabled: row['enabled'] as bool? ?? true,
      );
    }).toList();
  }

  @override
  Future<void> savePreference(
    String userId,
    NotificationPreference pref,
  ) async {
    await _supabase.from('notification_preferences').upsert({
      'user_id': userId,
      'event': pref.event.name,
      'channel': pref.channel.name,
      'enabled': pref.enabled,
    }, onConflict: 'user_id,event,channel');
  }

  // ── Canais internos ───────────────────────────────────────────────────────

  Future<void> _sendInbox(NotificationPayload payload) async {
    await _supabase.from('notifications').insert({
      'user_id': payload.recipientUserId,
      'event': payload.event.name,
      'title': payload.title,
      'body': payload.body,
      'data': payload.data,
      'read': false,
    });
  }

  Future<void> _enqueuePush(NotificationPayload payload) async {
    await _queue.enqueue(QueueJob(
      queue: QueueNames.push,
      payload: {
        'user_id': payload.recipientUserId,
        'event': payload.event.name,
        'title': payload.title,
        'body': payload.body,
        'data': payload.data,
      },
    ));
  }

  Future<void> _enqueueEmail(NotificationPayload payload) async {
    await _queue.enqueue(QueueJob(
      queue: QueueNames.email,
      payload: {
        'user_id': payload.recipientUserId,
        'event': payload.event.name,
        'subject': payload.title,
        'body': payload.body,
        'data': payload.data,
      },
    ));
  }

  Future<void> _enqueueWeb(NotificationPayload payload) async {
    await _queue.enqueue(QueueJob(
      queue: QueueNames.push, // Web compartilha fila de push por ora
      payload: {
        'channel': 'web',
        'user_id': payload.recipientUserId,
        'event': payload.event.name,
        'title': payload.title,
        'body': payload.body,
      },
    ));
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  static NotificationEvent _parseEvent(String raw) {
    return NotificationEvent.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NotificationEvent.system,
    );
  }

  static NotificationChannel _parseChannel(String raw) {
    return NotificationChannel.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => NotificationChannel.inbox,
    );
  }
}
