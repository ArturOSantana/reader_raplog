import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/book_detail_screen.dart';
import '../../features/library/presentation/screens/add_book_screen.dart';
import '../../features/session/presentation/screens/session_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final onAuth = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !onAuth) return '/auth/login';
      if (isLoggedIn && onAuth) return '/home';
      return null;
    },
    routes: [
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
        ],
      ),
    ],
  );
});
