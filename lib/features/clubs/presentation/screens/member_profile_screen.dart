import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_seals.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

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

  const MemberProfileScreen({
    super.key,
    required this.clubId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final statsAsync =
        ref.watch(_allTimeStatsProvider(_StatsKey(clubId, userId)));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          userName,
          style: AppTextStyles.titleMedium
              .copyWith(color: cs.onSurface, fontSize: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final sealsAsync =
        ref.watch(_memberSealsProvider(_StatsKey(clubId, userId)));

    // Campos reais retornados pela RPC member_club_profile
    final totalChallenges =
        (stats['challenges_completed'] as num?)?.toInt() ?? 0;
    final totalPages = (stats['total_pages_alltime'] as num?)?.toInt() ?? 0;
    final totalSessions = (stats['total_sessions'] as num?)?.toInt() ?? 0;
    final totalDaysRead = (stats['total_days_read'] as num?)?.toInt() ?? 0;
    final avgPagesPerDay = (stats['avg_pages_per_day'] as num?)?.toDouble() ?? 0;
    final joinedAt = stats['joined_at'] != null
        ? DateTime.parse(stats['joined_at'] as String)
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Avatar e nome ─────────────────────────────────────────────────
        _AvatarHeader(
          userName: userName,
          avatarUrl: avatarUrl,
          joinedAt: joinedAt,
        ),
        const SizedBox(height: 24),

        // ── Estatísticas all-time ─────────────────────────────────────────
        _SectionTitle(
            title: 'Estatísticas no clube', icon: Icons.bar_chart_outlined),
        const SizedBox(height: 12),
        _StatsCard(
          surface: surface,
          border: border,
          items: [
            _StatRow(
              icon: Icons.flag_outlined,
              label: 'Desafios concluídos',
              value: '$totalChallenges',
              color: AppColors.forestGreen,
            ),
            _StatRow(
              icon: Icons.menu_book_outlined,
              label: 'Total de páginas',
              value: NumberFormat.decimalPattern('pt_BR').format(totalPages),
              color: AppColors.forestGreen,
            ),
            _StatRow(
              icon: Icons.timer_outlined,
              label: 'Total de sessões',
              value: NumberFormat.decimalPattern('pt_BR').format(totalSessions),
              color: AppColors.warmGold,
            ),
            _StatRow(
              icon: Icons.calendar_today_outlined,
              label: 'Dias de leitura',
              value: '$totalDaysRead dias',
              color: AppColors.warmGold,
            ),
            _StatRow(
              icon: Icons.trending_up_outlined,
              label: 'Média pág./dia',
              value: NumberFormat.decimalPattern('pt_BR').format(avgPagesPerDay),
              color: AppColors.forestGreen,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Selos conquistados ────────────────────────────────────────────
        sealsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (seals) {
            if (seals.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                    title: 'Selos conquistados',
                    icon: Icons.verified_outlined),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: seals
                      .map((s) => _SealBadge(seal: s))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Avatar + cabeçalho ────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final DateTime? joinedAt;

  const _AvatarHeader({
    required this.userName,
    required this.avatarUrl,
    required this.joinedAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM yyyy', 'pt_BR');

    return Column(
      children: [
        MiniAvatar(url: avatarUrl, name: userName, radius: 38),
        const SizedBox(height: 12),
        Text(
          userName,
          style: AppTextStyles.headlineMedium.copyWith(
            color: cs.onSurface,
            fontSize: 20,
          ),
        ),
        if (joinedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Membro desde ${fmt.format(joinedAt!)}',
            style: AppTextStyles.labelMedium,
          ),
        ],
      ],
    );
  }
}

// ── Card de estatísticas ──────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final List<_StatRow> items;

  const _StatsCard({
    required this.surface,
    required this.border,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                Divider(height: 1, indent: 52, endIndent: 16, color: border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: cs.onSurface,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Selo badge ────────────────────────────────────────────────────────────────

class _SealBadge extends StatelessWidget {
  final ClubSeal seal;

  const _SealBadge({required this.seal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: seal.displayTitle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.warmGold.withValues(alpha: 0.15)
              : AppColors.warmGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.warmGold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(seal.sealType.icon, size: 16, color: AppColors.warmGold),
            const SizedBox(width: 6),
            Text(
              seal.displayTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.warmGold
                    : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
