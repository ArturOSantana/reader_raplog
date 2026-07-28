import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/cache_provider.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/impl/memory_cache_impl.dart';
import '../../core/providers/impl/noop_analytics_impl.dart';
import '../models/club_presence_stats.dart';
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
export '../../core/providers/platform_providers.dart';
export '../../core/rbac/rbac.dart';

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

// ── Club session refresh ──────────────────────────────────────────────────

/// Incrementado toda vez que o usuário finaliza uma sessão de leitura.
/// Providers de clube observam este valor para invalidar seu cache e
/// exibir o progresso atualizado sem precisar de pull-to-refresh manual.
final clubSessionRefreshProvider = StateProvider<int>((ref) => 0);

// ── Inspiração do Dia ─────────────────────────────────────────────────────

final dailyInspirationServiceProvider = Provider<DailyInspirationService>(
  (_) => DailyInspirationService(),
);

// ── Onboarding ────────────────────────────────────────────────────────────

/// Estado síncrono do onboarding — alimentado pelo SplashScreen após carregar
/// o perfil do repositório. Usado pelo redirect do router (síncrono).
/// - null  → ainda não sabemos (splash está carregando)
/// - false → usuário não completou o onboarding
/// - true  → onboarding concluído
final onboardingStatusProvider = StateProvider<bool?>((ref) => null);

/// Carrega o valor inicial de onboarding_completed do repositório.
/// O SplashScreen lê este FutureProvider e depois escreve o resultado em
/// [onboardingStatusProvider] para que o redirect do router possa agir.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return false;
  final profile = await ref.read(profileRepositoryProvider).fetch();
  return profile?.onboardingCompleted ?? false;
});

// ── Presença do clube ─────────────────────────────────────────────────────

final clubPresenceProvider =
    FutureProvider.family<List<ClubPresenceMember>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchPresence(clubId);
});

// ── Estatísticas coletivas do clube ──────────────────────────────────────

final clubCollectiveStatsProvider =
    FutureProvider.family<ClubCollectiveStats?, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchCollectiveStats(clubId);
});

// ── Heatmap social do clube ───────────────────────────────────────────────

final clubSocialHeatmapProvider =
    FutureProvider.family<List<ClubHeatmapDay>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchSocialHeatmap(clubId);
});


// ── Platform Providers (Fase 1A) ──────────────────────────────────────────
//
// Implementações concretas dos providers de plataforma.
// Troque a implementação aqui sem tocar em nenhuma outra parte do app.

/// Cache in-memory — padrão para Fase 1.
/// Trocar por SharedPrefsCacheImpl ou UpstashCacheImpl nas fases seguintes.
final cacheProvider = Provider<CacheProvider>(
  (_) => MemoryCacheImpl(),
  name: 'cacheProvider',
);

/// Analytics no-op — descarta eventos silenciosamente.
/// Trocar por PostHogAnalyticsImpl quando configurado.
final analyticsProvider = Provider<AnalyticsProvider>(
  (_) => const NoopAnalyticsImpl(),
  name: 'analyticsProvider',
);
