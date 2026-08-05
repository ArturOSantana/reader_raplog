import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_seals.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _allTimeStatsProvider =
    FutureProvider.family<Map<String, dynamic>?, _StatsKey>((ref, key) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchMemberAllTimeStats(key.clubId, key.userId);
});

final _memberSealsProvider =
    FutureProvider.family<List<ClubSeal>, _StatsKey>((ref, key) {
  return ref
      .read(bookClubRepositoryProvider)
      .listSealsByMember(key.clubId, key.userId);
});

class _StatsKey {
  final String clubId;
  final String userId;

  const _StatsKey(this.clubId, this.userId);

  @override
  bool operator ==(Object other) =>
      other is _StatsKey && other.clubId == clubId && other.userId == userId;

  @override
  int get hashCode => Object.hash(clubId, userId);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MemberProfileScreen extends ConsumerWidget {
  final String clubId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String? coverUrl;

  const MemberProfileScreen({
    super.key,
    required this.clubId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync =
        ref.watch(_allTimeStatsProvider(_StatsKey(clubId, userId)));

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Text(
          userName,
          style: ReadLogType.display(
            size: 15,
            color: ReadLogColors.ink,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_allTimeStatsProvider(_StatsKey(clubId, userId)));
          ref.invalidate(_memberSealsProvider(_StatsKey(clubId, userId)));
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (stats) => _ProfileBody(
            clubId: clubId,
            userId: userId,
            userName: userName,
            avatarUrl: avatarUrl,
            stats: stats ?? {},
          ),
        ),
      ),
    ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final String clubId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final Map<String, dynamic> stats;

  const _ProfileBody({
    required this.clubId,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.stats,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sealsAsync =
        ref.watch(_memberSealsProvider(_StatsKey(clubId, userId)));

    // Campos reais retornados pela RPC member_club_profile
    final totalChallenges =
        (stats['challenges_completed'] as num?)?.toInt() ?? 0;
    final totalPages = (stats['total_pages_alltime'] as num?)?.toInt() ?? 0;
    final totalSessions = (stats['total_sessions'] as num?)?.toInt() ?? 0;
    final totalDaysRead = (stats['total_days_read'] as num?)?.toInt() ?? 0;
    final avgPagesPerDay =
        (stats['avg_pages_per_day'] as num?)?.toDouble() ?? 0;
    final joinedAt = stats['joined_at'] != null
        ? DateTime.parse(stats['joined_at'] as String)
        : null;
    final fmt = NumberFormat.decimalPattern('pt_BR');
    final fmtMonth = DateFormat('MMM yyyy', 'pt_BR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // Nome + data de entrada
        Text(
          userName,
          style: ReadLogType.display(
            size: 28,
            color: ReadLogColors.ink,
            weight: FontWeight.w500,
          ),
        ),
        if (joinedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Membro desde ${fmtMonth.format(joinedAt)}',
            style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
          ),
        ],
        const SizedBox(height: 36),

        // ── Estatísticas — linhas simples com Divider ─────────────────────
        _StatDataRow(
          label: 'Desafios concluídos',
          value: '$totalChallenges',
        ),
        const Divider(height: 24, color: ReadLogColors.hairline),
        _StatDataRow(
          label: 'Total de páginas',
          value: fmt.format(totalPages),
        ),
        const Divider(height: 24, color: ReadLogColors.hairline),
        _StatDataRow(
          label: 'Sessões de leitura',
          value: fmt.format(totalSessions),
        ),
        const Divider(height: 24, color: ReadLogColors.hairline),
        _StatDataRow(
          label: 'Dias de leitura',
          value: '$totalDaysRead',
        ),
        const Divider(height: 24, color: ReadLogColors.hairline),
        _StatDataRow(
          label: 'Média pág./dia',
          value: fmt.format(avgPagesPerDay),
        ),

        // ── Reconhecimentos (selos como texto) ────────────────────────────
        sealsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (seals) {
            if (seals.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 40, color: ReadLogColors.hairline),
                Text(
                  'RECONHECIMENTOS',
                  style: ReadLogType.mono(
                    size: 10,
                    color: ReadLogColors.inkGhost,
                  ).copyWith(letterSpacing: 1.4),
                ),
                const SizedBox(height: 12),
                ...seals.map((s) => _SealTextRow(seal: s)),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Linha de dado ─────────────────────────────────────────────────────────────

class _StatDataRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatDataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
        ),
        Text(
          value,
          style: ReadLogType.mono(
            size: 13,
            color: ReadLogColors.ink,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Selo como linha de texto ──────────────────────────────────────────────────

class _SealTextRow extends StatelessWidget {
  final ClubSeal seal;

  const _SealTextRow({required this.seal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '· ${seal.displayTitle}',
        style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
      ),
    );
  }
}
