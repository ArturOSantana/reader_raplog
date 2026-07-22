import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/book_detail_screen.dart';
import '../../features/library/presentation/screens/add_book_screen.dart';
import '../../features/library/presentation/screens/edit_book_screen.dart';
import '../../features/session/presentation/screens/session_screen.dart';
import '../../features/session/presentation/screens/session_history_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';
import '../../features/highlights/presentation/screens/highlights_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/friends/presentation/screens/public_profile_screen.dart';
import '../../features/friends/presentation/screens/friend_profile_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/social/presentation/screens/social_screen.dart';
import '../../features/clubs/presentation/screens/book_clubs_screen.dart';
import '../../features/clubs/presentation/screens/book_club_detail_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/reading_schedule_screen.dart';
import '../../features/notifications/data/notification_models.dart';
import '../shell/main_shell.dart';
import 'route_persistence.dart';

/// Última rota salva, injetada via override no main.dart antes do runApp.
final initialRouteProvider = Provider<String?>((ref) => null);

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  bool get isLoggedIn =>
      _ref.read(authStateProvider).valueOrNull?.session != null;
}

/// Provider que carrega (e cacheia) se o usuário já completou o onboarding.
/// Lê via repositório offline-first para refletir o estado mesmo sem rede.
/// Exposto fora do router para que o SplashScreen possa invalidar após login.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return true; // não logado → não bloqueia
  final profile = await ref.read(profileRepositoryProvider).fetch();
  return profile?.onboardingCompleted ?? false;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  final initialRoute = ref.watch(initialRouteProvider) ?? '/';

  final router = GoRouter(
    initialLocation: initialRoute,
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final onAuth = state.matchedLocation.startsWith('/auth');
      final onSplash = state.matchedLocation == '/';
      final onOnboarding = state.matchedLocation == '/onboarding';

      if (onSplash) return null;
      if (!isLoggedIn && !onAuth) return '/auth/login';
      if (isLoggedIn && onAuth) return '/home';
      // Permite que o SplashScreen gerencie o redirect para /onboarding
      if (onOnboarding) return null;
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/library',
            builder: (_, __) => const LibraryScreen(),
            routes: [
              GoRoute(
                path: 'book/:id',
                builder: (_, state) =>
                    BookDetailScreen(bookId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => EditBookScreen(
                      book: state.extra as dynamic,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddBookScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/session',
            builder: (_, state) =>
                SessionScreen(bookId: state.uri.queryParameters['bookId']),
          ),
          GoRoute(
            path: '/session-history/:bookId',
            builder: (_, state) => SessionHistoryScreen(
              bookId: state.pathParameters['bookId']!,
              bookTitle: state.extra as String? ?? 'Sessões',
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/achievements',
            builder: (_, __) => const AchievementsScreen(),
          ),
          GoRoute(
            path: '/notes/:bookId',
            builder: (_, state) =>
                NotesScreen(bookId: state.pathParameters['bookId']!),
          ),
          GoRoute(
            path: '/highlights/:bookId',
            builder: (_, state) => HighlightsScreen(
              bookId: state.pathParameters['bookId']!,
              bookTitle: state.extra as String? ?? 'Favoritos',
            ),
          ),
          GoRoute(
            path: '/goals',
            builder: (_, __) => const GoalsScreen(),
          ),
          GoRoute(
            path: '/wishlist',
            builder: (_, __) => const WishlistScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/friends',
            builder: (_, __) => const FriendsScreen(),
            routes: [
              GoRoute(
                path: 'profile/:userId',
                builder: (_, state) => PublicProfileScreen(
                  userId: state.pathParameters['userId']!,
                ),
              ),
              GoRoute(
                path: 'view/:userId',
                builder: (_, state) => FriendProfileScreen(
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ],
          ),
          // ── Novas rotas ────────────────────────────────────────────────
          GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (_, __) => const SocialScreen(),
          ),
          GoRoute(
            path: '/clubs',
            builder: (_, __) => const BookClubsScreen(),
            routes: [
              GoRoute(
                path: ':clubId',
                builder: (_, state) => BookClubDetailScreen(
                  clubId: state.pathParameters['clubId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/notifications/settings',
            builder: (_, __) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/notifications/schedule',
            builder: (_, state) => ReadingScheduleScreen(
              existing: state.extra as ReadingSchedule?,
            ),
          ),
        ],
      ),
    ],
  );

  // Persiste a rota sempre que o GoRouter mudar de localização.
  router.routerDelegate.addListener(() {
    final location =
        router.routerDelegate.currentConfiguration.uri.toString();
    saveLastRoute(location);
  });

  ref.onDispose(router.dispose);

  return router;
});
