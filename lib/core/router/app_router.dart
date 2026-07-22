import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/book_detail_screen.dart';
import '../../features/library/presentation/screens/add_book_screen.dart';
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
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/social/presentation/screens/social_screen.dart';
import '../../features/clubs/presentation/screens/book_clubs_screen.dart';
import '../../features/clubs/presentation/screens/book_club_detail_screen.dart';
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

      if (onSplash) return null;
      if (!isLoggedIn && !onAuth) return '/auth/login';
      if (isLoggedIn && onAuth) return '/home';
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
