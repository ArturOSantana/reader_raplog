import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/local/connectivity_provider.dart';
import '../../core/local/sync_service.dart';
import '../../features/library/data/offline_book_repository.dart';
import '../../features/session/data/offline_session_repository.dart';
import '../../features/achievements/data/achievement_repository.dart';
import '../../features/notes/data/offline_note_repository.dart';
import '../../features/profile/data/offline_profile_repository.dart';
import '../../features/goals/data/goal_repository.dart';
import '../../features/wishlist/data/wishlist_repository.dart';
import '../../features/highlights/data/highlight_repository.dart';
import '../../features/friends/data/friends_repository.dart';
import '../../features/clubs/data/book_club_repository.dart';
import '../../features/social/data/social_feed_repository.dart';
import '../../features/notifications/data/notification_models.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/presentation/notification_notifier.dart';
import '../../features/inspiration/data/inspiration_service.dart';

export '../../core/local/connectivity_provider.dart';

// ── Supabase ──────────────────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── Auth ──────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>(
  (ref) => Supabase.instance.client.auth.currentUser,
);

// ── Connectivity ──────────────────────────────────────────────────────────

/// `true` quando há rede disponível.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});

// ── Sync ──────────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(supabaseClientProvider)),
);

// ── Repositories (offline-first) ─────────────────────────────────────────

final bookRepositoryProvider = Provider<OfflineBookRepository>(
  (ref) => OfflineBookRepository(
    ref.watch(supabaseClientProvider),
    () => ref.read(isOnlineProvider),
  ),
);

final sessionRepositoryProvider = Provider<OfflineSessionRepository>(
  (ref) => OfflineSessionRepository(
    ref.watch(supabaseClientProvider),
    () => ref.read(isOnlineProvider),
  ),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(supabaseClientProvider)),
);

final noteRepositoryProvider = Provider<OfflineNoteRepository>(
  (ref) => OfflineNoteRepository(
    ref.watch(supabaseClientProvider),
    () => ref.read(isOnlineProvider),
  ),
);

final profileRepositoryProvider = Provider<OfflineProfileRepository>(
  (ref) => OfflineProfileRepository(
    ref.watch(supabaseClientProvider),
    () => ref.read(isOnlineProvider),
  ),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(supabaseClientProvider)),
);

final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(ref.watch(supabaseClientProvider)),
);

final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => HighlightRepository(ref.watch(supabaseClientProvider)),
);

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(supabaseClientProvider)),
);

final bookClubRepositoryProvider = Provider<BookClubRepository>(
  (ref) => BookClubRepository(ref.watch(supabaseClientProvider)),
);

final socialFeedRepositoryProvider = Provider<SocialFeedRepository>(
  (ref) => SocialFeedRepository(ref.watch(supabaseClientProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
  (ref) => NotificationInboxNotifier(ref.watch(notificationRepositoryProvider)),
);

final notificationPrefsProvider = StateNotifierProvider<
    NotificationPrefsNotifier, AsyncValue<NotificationPrefs>>(
  (ref) =>
      NotificationPrefsNotifier(ref.watch(notificationRepositoryProvider)),
);

// ── Inspiração do Dia ─────────────────────────────────────────────────────

final dailyInspirationServiceProvider = Provider<DailyInspirationService>(
  (_) => DailyInspirationService(),
);

// ── Tema ──────────────────────────────────────────────────────────────────

/// Persiste o ThemeMode escolhido pelo usuário em SharedPreferences.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
);
