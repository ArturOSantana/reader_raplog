import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/book_metadata_provider.dart';
import '../../core/providers/cache_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/queue_provider.dart';
import '../../core/providers/impl/cached_book_metadata_impl.dart';
import '../../core/providers/impl/debug_analytics_impl.dart';
import '../../core/providers/impl/google_books_metadata_impl.dart';
import '../../core/media/media_pipeline.dart';
import '../../core/media/supabase_media_pipeline.dart';
import '../../core/providers/storage_provider.dart';
import '../../core/providers/impl/in_memory_queue_impl.dart';
import '../../core/providers/impl/supabase_storage_impl.dart';
import '../../core/providers/impl/supabase_notification_impl.dart';
import '../../core/providers/impl/memory_cache_impl.dart';
import '../../core/providers/impl/noop_analytics_impl.dart';
import '../../core/providers/impl/shared_prefs_cache_impl.dart';
import '../../core/observability/observability_service.dart';
import '../../features/library/data/book_search_service.dart';
import '../../features/library/data/cached_book_search_service.dart';
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
export '../../core/observability/observability_service.dart';
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


// ── Queue Platform (Fase 2A) ──────────────────────────────────────────────

/// Queue in-process para desenvolvimento/debug.
/// Em produção, trocar por SupabaseQueueImpl ou BullMQImpl.
final queueProvider = Provider<QueueProvider>((ref) {
  return InMemoryQueueImpl();
}, name: 'queueProvider');

// ── Notification Platform (Fase 2A) ──────────────────────────────────────

/// Envia notificações via Supabase (inbox) + Queue (push/email).
/// Canais configuráveis por usuário via NotificationPreference.
final notificationPlatformProvider = Provider<NotificationProvider>((ref) {
  return SupabaseNotificationImpl(
    supabase: ref.watch(supabaseClientProvider),
    queue: ref.watch(queueProvider),
  );
}, name: 'notificationPlatformProvider');

// ── Media Pipeline (Fase 2A) ──────────────────────────────────────────────

/// StorageProvider via Supabase Storage.
/// Trocar por S3Impl / R2Impl sem alterar consumidores.
final storageProvider = Provider<StorageProvider>((ref) {
  return SupabaseStorageImpl(ref.watch(supabaseClientProvider));
}, name: 'storageProvider');

// ── Media Pipeline (Fase 2A) ──────────────────────────────────────────────

/// Todo upload de imagem/documento deve passar pelo mediaPipelineProvider.
/// Valida MIME, tamanho, comprime (stub) e salva no Supabase Storage.
final mediaPipelineProvider = Provider<MediaPipeline>((ref) {
  return SupabaseMediaPipeline(
    storage: ref.watch(storageProvider),
    supabase: ref.watch(supabaseClientProvider),
  );
}, name: 'mediaPipelineProvider');

// ── Platform Providers (Fase 1A / 1B) ────────────────────────────────────
//
// Implementações concretas dos providers de plataforma.
// Para trocar de implementação, altere apenas aqui.

// ── Cache ─────────────────────────────────────────────────────────────────

/// Cache persistente via SharedPreferences (Fase 1B).
/// Inicializado de forma assíncrona; fallback para memória enquanto carrega.
final sharedPrefsCacheProvider = FutureProvider<CacheProvider>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPrefsCacheImpl(prefs);
}, name: 'sharedPrefsCacheProvider');

/// Cache usado em todo o app.
/// Usa SharedPrefsCacheImpl quando disponível; fallback para MemoryCacheImpl.
final cacheProvider = Provider<CacheProvider>((ref) {
  return ref.watch(sharedPrefsCacheProvider).valueOrNull ?? MemoryCacheImpl();
}, name: 'cacheProvider');

// ── Analytics ─────────────────────────────────────────────────────────────

/// DebugAnalyticsImpl em debug (loga no console); NoopAnalyticsImpl em produção.
/// Fase 2B: trocar por PostHogAnalyticsImpl.
final analyticsProvider = Provider<AnalyticsProvider>((ref) {
  if (kDebugMode) return const DebugAnalyticsImpl();
  return const NoopAnalyticsImpl();
}, name: 'analyticsProvider');

// ── Book Metadata com cache ───────────────────────────────────────────────

/// Provider de metadados de livros com cache automático.
/// Fluxo: cache (SharedPrefs) → Google Books API → salva no cache.
final bookMetadataProvider = Provider<BookMetadataProvider>((ref) {
  final cache = ref.watch(cacheProvider);
  const apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');
  final google = GoogleBooksMetadataImpl(apiKey: apiKey);
  return CachedBookMetadataImpl(delegate: google, cache: cache);
}, name: 'bookMetadataProvider');

// ── Book Search com cache ─────────────────────────────────────────────────

/// BookSearchService com cache — substitui o uso direto de BookSearchService.
final cachedBookSearchProvider = Provider<CachedBookSearchService>((ref) {
  final cache = ref.watch(cacheProvider);
  return CachedBookSearchService(
    delegate: BookSearchService(),
    cache: cache,
  );
}, name: 'cachedBookSearchProvider');

// ── Observabilidade ───────────────────────────────────────────────────────

/// Acesso ao ObservabilityService via Riverpod (alias de obsProvider).
final observabilityProvider = Provider<ObservabilityService>(
  (_) => ObservabilityService.instance,
  name: 'observabilityProvider',
);
