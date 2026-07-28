import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_models.dart';

/// Persiste preferências localmente (SharedPreferences) e busca a inbox
/// da tabela `notification_items` no Supabase.
class NotificationRepository {
  static const _prefsKey = 'notification_prefs_v1';
  static const _schedulesKey = 'reading_schedules_v1';

  final SupabaseClient _client;

  NotificationRepository(this._client);

  // ── Preferências ───────────────────────────────────────────────────────────

  Future<NotificationPrefs> fetchPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final schedulesRaw = prefs.getString(_schedulesKey);

    Map<NotificationCategory, bool> cats = {
      for (final c in NotificationCategory.values) c: true,
    };

    if (raw != null) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final cat = NotificationCategory.values.cast<NotificationCategory?>()
            .firstWhere((c) => c?.name == entry.key, orElse: () => null);
        if (cat != null) cats[cat] = entry.value as bool;
      }
    }

    List<ReadingSchedule> schedules = [];
    if (schedulesRaw != null) {
      final list = jsonDecode(schedulesRaw) as List;
      schedules = list
          .map((e) => ReadingSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return NotificationPrefs(categories: cats, schedules: schedules);
  }

  Future<void> savePrefs(NotificationPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    final map = {for (final e in prefs.categories.entries) e.key.name: e.value};
    await p.setString(_prefsKey, jsonEncode(map));
    await p.setString(
      _schedulesKey,
      jsonEncode(prefs.schedules.map((s) => s.toJson()).toList()),
    );
  }

  // ── Inbox (Supabase) ───────────────────────────────────────────────────────

  Future<List<NotificationItem>> fetchInbox() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('notification_items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    return (data as List)
        .map((e) => NotificationItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String notifId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notification_items')
        .update({'is_read': true})
        .eq('id', notifId)
        .eq('user_id', userId);
  }

  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notification_items')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Insere um item na inbox (usado internamente pelo app ao disparar eventos).
  Future<void> addItem({
    required String id,
    required NotificationCategory category,
    required String title,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notification_items').upsert({
      'id': id,
      'user_id': userId,
      'category': category.name,
      'title': title,
      'body': body,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> unreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from('notification_items')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (data as List).length;
  }
}
