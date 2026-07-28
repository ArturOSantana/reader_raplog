import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import './presentation/admin_shell.dart';
import './presentation/screens/admin_overview_screen.dart';
import './presentation/screens/admin_users_screen.dart';
import './presentation/screens/admin_clubs_screen.dart';
import './presentation/screens/admin_reports_screen.dart';
import './presentation/screens/admin_subscriptions_screen.dart';
import './presentation/screens/admin_metrics_screen.dart';

/// Rotas do painel admin. Montadas FORA do ShellRoute do app —
/// nunca compartilham o [MainShell] nem a BottomNavigationBar do usuário.
///
/// Acesso: /admin  (apenas em debug ou usuários com flag admin no Supabase)
final adminRoutes = ShellRoute(
  builder: (_, __, child) => AdminShell(child: child),
  routes: [
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminOverviewScreen(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (_, __) => const AdminUsersScreen(),
    ),
    GoRoute(
      path: '/admin/clubs',
      builder: (_, __) => const AdminClubsScreen(),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (_, __) => const AdminReportsScreen(),
    ),
    GoRoute(
      path: '/admin/subscriptions',
      builder: (_, __) => const AdminSubscriptionsScreen(),
    ),
    GoRoute(
      path: '/admin/metrics',
      builder: (_, __) => const AdminMetricsScreen(),
    ),
  ],
);

/// Guard: bloqueia /admin em produção se o usuário não tiver acesso.
/// O [app_router.dart] adiciona este check no redirect.
bool adminAccessAllowed(bool isAdmin) {
  // Em debug, sempre permite para facilitar o desenvolvimento.
  if (kDebugMode) return true;
  return isAdmin;
}
