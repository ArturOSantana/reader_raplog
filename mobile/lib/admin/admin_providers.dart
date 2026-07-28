import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/providers/providers.dart';
import 'data/admin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repositório
// ─────────────────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────────────────────

final adminOverviewProvider = FutureProvider<AdminOverview>((ref) {
  return ref.watch(adminRepositoryProvider).fetchOverview();
});

// ─────────────────────────────────────────────────────────────────────────────
// Usuários
// ─────────────────────────────────────────────────────────────────────────────

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

// ─────────────────────────────────────────────────────────────────────────────
// Clubes
// ─────────────────────────────────────────────────────────────────────────────

final adminClubsProvider = FutureProvider<List<AdminClub>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchClubs();
});

// ─────────────────────────────────────────────────────────────────────────────
// Denúncias
// ─────────────────────────────────────────────────────────────────────────────

final adminReportsFilterProvider = StateProvider<String?>((ref) => 'open');

final adminReportsProvider = FutureProvider<List<AdminReport>>((ref) {
  final filter = ref.watch(adminReportsFilterProvider);
  return ref.watch(adminRepositoryProvider).fetchReports(status: filter);
});

// ─────────────────────────────────────────────────────────────────────────────
// Assinaturas
// ─────────────────────────────────────────────────────────────────────────────

final adminSubscriptionsProvider = FutureProvider<List<AdminSubscription>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchSubscriptions();
});
