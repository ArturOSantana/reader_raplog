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
import '../../features/clubs/presentation/screens/club_reading_room_screen.dart';
import '../../features/clubs/presentation/screens/club_checkin_screen.dart';
import '../../features/clubs/presentation/screens/club_calendar_screen.dart';
import '../../features/clubs/presentation/screens/challenge_detail_screen.dart';
import '../../features/clubs/presentation/screens/challenge_heatmap_screen.dart';
import '../../features/clubs/presentation/screens/challenge_result_screen.dart';
import '../../features/clubs/presentation/screens/club_feed_screen.dart';
import '../../features/clubs/presentation/screens/member_profile_screen.dart';
import '../../features/clubs/presentation/screens/milestone_discussion_screen.dart';
import '../../features/clubs/presentation/screens/club_seals_screen.dart';
import '../../shared/models/club_seals.dart';
import '../../features/clubs/presentation/screens/club_timeline_screen.dart';
import '../../features/clubs/presentation/screens/book_diary_screen.dart';
import '../../features/clubs/presentation/screens/club_advanced_stats_screen.dart';
import '../../features/clubs/presentation/screens/club_open_polls_screen.dart';
import '../../features/clubs/presentation/screens/club_review_screen.dart';
import '../../features/clubs/presentation/screens/club_book_reviews_screen.dart';
import '../../features/clubs/presentation/screens/club_social_heatmap_screen.dart';
import '../../shared/models/club_reviews.dart';

import '../../shared/models/club_schedule_milestones_challenges.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/reading_schedule_screen.dart';
import '../../features/notifications/data/notification_models.dart';
import '../shell/main_shell.dart';
import 'route_persistence.dart';
import '../../admin/admin_router.dart' show adminRoutes;

/// Última rota salva, injetada via override no main.dart antes do runApp.
final initialRouteProvider = Provider<String?>((ref) => null);

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _removeListeners = [
      _ref.listen(authStateProvider, (_, __) => _notify()),
      _ref.listen(onboardingStatusProvider, (_, __) => _notify()),
      _ref.listen(currentPrincipalProvider, (_, __) => _notify()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription<dynamic>> _removeListeners;

  void _notify() {
    if (!hasListeners) return;
    notifyListeners();
  }

  bool get isLoggedIn =>
      _ref.read(authStateProvider).valueOrNull?.session != null;

  bool? get onboardingDone => _ref.read(onboardingStatusProvider);

  bool get canAccessAdmin {
    final principal =
        _ref.read(currentPrincipalProvider).valueOrNull ?? LumenPrincipal.anonymous;
    return const LumenRbacService().canAccessAdmin(principal);
  }

  @override
  void dispose() {
    for (final sub in _removeListeners) {
      sub.close();
    }
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();

  final notifier = _AuthNotifier(ref);
  final initialRoute = ref.read(initialRouteProvider) ?? '/';

  final router = GoRouter(
    initialLocation: initialRoute,
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final loc = state.matchedLocation;
      final onAuth = loc.startsWith('/auth');
      final onSplash = loc == '/';
      final onOnboarding = loc == '/onboarding';
      final onAdmin = loc.startsWith('/admin');

      if (onSplash) return null;
      if (!isLoggedIn && !onAuth) return '/auth/login';
      if (isLoggedIn && onAuth) return '/home';

      // Guard do admin: usa RBAC — bloqueia se o principal não tiver acesso
      if (onAdmin && !notifier.canAccessAdmin) return '/home';

      // Enquanto o status ainda não foi carregado, deixa o splash decidir.
      if (onOnboarding) return null;

      // Bloqueia acesso às rotas internas enquanto onboarding não for concluído.
      final done = notifier.onboardingDone;
      if (isLoggedIn && done == false && !onOnboarding && !onAdmin) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      // ── Admin (completamente separado do ShellRoute do app) ───────────────
      adminRoutes,
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
                  GoRoute(
                    path: 'diary',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return BookDiaryScreen(
                        bookId: state.pathParameters['id']!,
                        bookTitle: extra['bookTitle'] as String? ?? 'Livro',
                        bookAuthor: extra['bookAuthor'] as String?,
                      );
                    },
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
                routes: [
                  GoRoute(
                    path: 'reading-room',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubReadingRoomScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'checkin',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ClubCheckinScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] as String? ?? 'Clube',
                        latestSessionId:
                            extra['latestSessionId'] as String?,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'calendar',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubCalendarScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'challenges/:challengeId',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      final challenge = extra['challenge'] as ClubChallenge?;
                      return ChallengeDetailScreen(
                        clubId: state.pathParameters['clubId']!,
                        challengeId: state.pathParameters['challengeId']!,
                        challengeTitle: challenge?.title ??
                            extra['challengeTitle'] as String? ?? 'Desafio',
                        challenge: challenge,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'feed',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubFeedScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'challenges/:challengeId/heatmap',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ChallengeHeatmapScreen(
                        challenge: extra['challenge'] as ClubChallenge,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'challenges/:challengeId/result',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ChallengeResultScreen(
                        challenge: extra['challenge'] as ClubChallenge,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'stats',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubAdvancedStatsScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'timeline',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubTimelineScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'seals',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ClubSealsScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] as String? ?? 'Clube',
                        isManager: extra['isManager'] as bool? ?? false,
                        members: (extra['members'] as List<ClubMemberSummary>?) ?? const [],
                      );
                    },
                  ),
                  GoRoute(
                    path: 'milestones/:milestoneId/discussion',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return MilestoneDiscussionScreen(
                        milestone: extra['milestone'] as ClubMilestone,
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] as String? ?? 'Clube',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'polls',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ClubOpenPollsScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] as String? ?? 'Clube',
                        canManage: extra['canManage'] as bool? ?? false,
                      );
                    },
                  ),
                  // ── Resenhas ───────────────────────────────────────────
                  GoRoute(
                    path: 'reviews',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ClubBookReviewsScreen(
                        clubId: state.pathParameters['clubId']!,
                        bookHistoryId:
                            extra['bookHistoryId'] as String? ?? '',
                        bookTitle:
                            extra['bookTitle'] as String? ?? 'Livro',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'reviews/new',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return ClubReviewScreen(
                        clubId: extra['clubId'] as String? ??
                            state.pathParameters['clubId']!,
                        bookHistoryId:
                            extra['bookHistoryId'] as String? ?? '',
                        bookTitle:
                            extra['bookTitle'] as String? ?? 'Livro',
                        existing: extra['existing'] as ClubReview?,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'members/:userId/profile',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return MemberProfileScreen(
                        clubId: state.pathParameters['clubId']!,
                        userId: state.pathParameters['userId']!,
                        userName:
                            extra['userName'] as String? ?? 'Membro',
                        avatarUrl: extra['avatarUrl'] as String?,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'social-heatmap',
                    builder: (_, state) {
                      final extra =
                          state.extra as Map<String, String>? ?? {};
                      return ClubSocialHeatmapScreen(
                        clubId: state.pathParameters['clubId']!,
                        clubName: extra['clubName'] ?? 'Clube',
                      );
                    },
                  ),
                ],
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

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
