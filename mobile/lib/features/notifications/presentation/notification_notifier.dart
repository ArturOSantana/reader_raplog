import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

// ── Estado da inbox ───────────────────────────────────────────────────────────

class NotificationInboxState {
  final List<NotificationItem> items;
  final bool loading;
  final String? error;

  const NotificationInboxState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  NotificationInboxState copyWith({
    List<NotificationItem>? items,
    bool? loading,
    String? error,
  }) =>
      NotificationInboxState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );

  int get unreadCount => items.where((i) => !i.isRead).length;
}

// ── Notifier da inbox ─────────────────────────────────────────────────────────

class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  final NotificationRepository _repo;

  NotificationInboxNotifier(this._repo) : super(const NotificationInboxState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.fetchInbox();
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(isRead: true) : i)
          .toList(),
    );
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    state = state.copyWith(
      items: state.items.map((i) => i.copyWith(isRead: true)).toList(),
    );
  }
}

// ── Estado das preferências ───────────────────────────────────────────────────

class NotificationPrefsNotifier extends StateNotifier<AsyncValue<NotificationPrefs>> {
  final NotificationRepository _repo;

  NotificationPrefsNotifier(this._repo)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await _repo.fetchPrefs();
      state = AsyncValue.data(prefs);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> toggleCategory(NotificationCategory cat, bool value) async {
    final current = state.valueOrNull ?? NotificationPrefs.defaults();
    final updated = current.copyWithCategory(cat, value);
    state = AsyncValue.data(updated);
    await _repo.savePrefs(updated);
  }

  Future<void> addSchedule(ReadingSchedule schedule) async {
    final current = state.valueOrNull ?? NotificationPrefs.defaults();
    final updated = current.copyWithSchedules([...current.schedules, schedule]);
    state = AsyncValue.data(updated);
    await _repo.savePrefs(updated);
  }

  Future<void> removeSchedule(String scheduleId) async {
    final current = state.valueOrNull ?? NotificationPrefs.defaults();
    final updated = current.copyWithSchedules(
      current.schedules.where((s) => s.id != scheduleId).toList(),
    );
    state = AsyncValue.data(updated);
    await _repo.savePrefs(updated);
  }

  Future<void> updateSchedule(ReadingSchedule schedule) async {
    final current = state.valueOrNull ?? NotificationPrefs.defaults();
    final updated = current.copyWithSchedules(
      current.schedules.map((s) => s.id == schedule.id ? schedule : s).toList(),
    );
    state = AsyncValue.data(updated);
    await _repo.savePrefs(updated);
  }
}
