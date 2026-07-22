import 'package:flutter_riverpod/flutter_riverpod.dart';
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
