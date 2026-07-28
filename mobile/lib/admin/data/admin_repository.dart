import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class AdminOverview {
  final int totalUsers;
  final int activeUsersLast30d;
  final int totalClubs;
  final int totalBooks;
  final int totalSessions;
  final int openReports;
  final int activeSubscriptions;

  const AdminOverview({
    required this.totalUsers,
    required this.activeUsersLast30d,
    required this.totalClubs,
    required this.totalBooks,
    required this.totalSessions,
    required this.openReports,
    required this.activeSubscriptions,
  });
}

class AdminUser {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool onboardingCompleted;

  const AdminUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.createdAt,
    required this.onboardingCompleted,
  });

  factory AdminUser.fromMap(Map<String, dynamic> m) => AdminUser(
        id: m['id'] as String,
        email: m['email'] as String? ?? '',
        name: m['full_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
        onboardingCompleted: m['onboarding_completed'] as bool? ?? false,
      );
}

class AdminClub {
  final String id;
  final String name;
  final int memberCount;
  final DateTime createdAt;
  final bool isActive;

  const AdminClub({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.createdAt,
    required this.isActive,
  });

  factory AdminClub.fromMap(Map<String, dynamic> m) => AdminClub(
        id: m['id'] as String,
        name: m['name'] as String? ?? '—',
        memberCount: (m['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
        isActive: m['is_active'] as bool? ?? true,
      );
}

class AdminReport {
  final String id;
  final String reportedBy;
  final String targetType; // 'user' | 'club' | 'post'
  final String targetId;
  final String reason;
  final String status; // 'open' | 'resolved' | 'dismissed'
  final DateTime createdAt;

  const AdminReport({
    required this.id,
    required this.reportedBy,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory AdminReport.fromMap(Map<String, dynamic> m) => AdminReport(
        id: m['id'] as String,
        reportedBy: m['reported_by'] as String? ?? '',
        targetType: m['target_type'] as String? ?? 'unknown',
        targetId: m['target_id'] as String? ?? '',
        reason: m['reason'] as String? ?? '',
        status: m['status'] as String? ?? 'open',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AdminSubscription {
  final String id;
  final String userId;
  final String plan;
  final String status; // 'active' | 'canceled' | 'past_due'
  final DateTime startedAt;
  final DateTime? expiresAt;

  const AdminSubscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.startedAt,
    this.expiresAt,
  });

  factory AdminSubscription.fromMap(Map<String, dynamic> m) =>
      AdminSubscription(
        id: m['id'] as String,
        userId: m['user_id'] as String? ?? '',
        plan: m['plan'] as String? ?? 'free',
        status: m['status'] as String? ?? 'active',
        startedAt: DateTime.tryParse(m['started_at'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: m['expires_at'] != null
            ? DateTime.tryParse(m['expires_at'] as String)
            : null,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class AdminRepository {
  final SupabaseClient _client;

  const AdminRepository(this._client);

  Future<AdminOverview> fetchOverview() async {
    final results = await Future.wait([
      _client.from('profiles').select('id'),
      _client.from('book_clubs').select('id'),
      _client.from('books').select('id'),
      _client.from('reading_sessions').select('id'),
    ]);

    final totalUsers = (results[0] as List).length;
    final totalClubs = (results[1] as List).length;
    final totalBooks = (results[2] as List).length;
    final totalSessions = (results[3] as List).length;

    return AdminOverview(
      totalUsers: totalUsers,
      activeUsersLast30d: 0,
      totalClubs: totalClubs,
      totalBooks: totalBooks,
      totalSessions: totalSessions,
      openReports: 0,
      activeSubscriptions: 0,
    );
  }

  Future<List<AdminUser>> fetchUsers({int limit = 50, int offset = 0}) async {
    final rows = await _client
        .from('profiles')
        .select('id, email, full_name, avatar_url, created_at, onboarding_completed')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List).map((r) => AdminUser.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<AdminClub>> fetchClubs({int limit = 50, int offset = 0}) async {
    final rows = await _client
        .from('book_clubs')
        .select('id, name, is_active, created_at, member_count:club_members(count)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final countRaw = m['member_count'];
      final count = countRaw is List
          ? (countRaw.first as Map<String, dynamic>)['count'] as int? ?? 0
          : 0;
      return AdminClub.fromMap({...m, 'member_count': count});
    }).toList();
  }

  Future<List<AdminReport>> fetchReports({String? status}) async {
    var query = _client
        .from('reports')
        .select('id, reported_by, target_type, target_id, reason, status, created_at')
        .order('created_at', ascending: false);
    if (status != null) {
      final rows = await _client
          .from('reports')
          .select('id, reported_by, target_type, target_id, reason, status, created_at')
          .eq('status', status)
          .order('created_at', ascending: false);
      return (rows as List).map((r) => AdminReport.fromMap(r as Map<String, dynamic>)).toList();
    }
    final rows = await query;
    return (rows as List)
        .map((r) => AdminReport.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _client.from('reports').update({'status': status}).eq('id', reportId);
  }

  Future<List<AdminSubscription>> fetchSubscriptions() async {
    final rows = await _client
        .from('subscriptions')
        .select('id, user_id, plan, status, started_at, expires_at')
        .order('started_at', ascending: false);
    return (rows as List).map((r) => AdminSubscription.fromMap(r as Map<String, dynamic>)).toList();
  }
}
