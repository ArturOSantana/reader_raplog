import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _mostReadBooksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, clubId) =>
            ref.read(bookClubRepositoryProvider).fetchMostReadBooks(clubId));

final _mostConsistentProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, clubId) => ref
            .read(bookClubRepositoryProvider)
            .fetchMostConsistentMembers(clubId));

final _productiveMonthsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, clubId) => ref
            .read(bookClubRepositoryProvider)
            .fetchMostProductiveMonths(clubId));

final _controversialBooksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, clubId) => ref
            .read(bookClubRepositoryProvider)
            .fetchMostControversialBooks(clubId));

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubAdvancedStatsScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubAdvancedStatsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estatísticas Avançadas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_mostReadBooksProvider(clubId));
          ref.invalidate(_mostConsistentProvider(clubId));
          ref.invalidate(_productiveMonthsProvider(clubId));
          ref.invalidate(_controversialBooksProvider(clubId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsBlock(
              title: 'Livros mais lidos',
              icon: Icons.menu_book_outlined,
              color: AppColors.forestGreen,
              provider: ref.watch(_mostReadBooksProvider(clubId)),
              builder: (item) => _BookStatRow(
                title: item['book_title'] as String? ?? '—',
                subtitle: item['book_author'] as String?,
                value:
                    '${NumberFormat.compactCurrency(locale: "pt_BR", symbol: "").format(item['total_pages'] ?? 0)} pág.',
                detail:
                    '${item['readers'] ?? 0} ${(item['readers'] ?? 0) == 1 ? 'leitor' : 'leitores'}',
              ),
            ),
            const SizedBox(height: 20),

            _StatsBlock(
              title: 'Membros mais consistentes',
              icon: Icons.local_fire_department_outlined,
              color: AppColors.warmGold,
              provider: ref.watch(_mostConsistentProvider(clubId)),
              builder: (item) => _MemberStatRow(
                name: item['user_name'] as String? ?? 'Membro',
                avatarUrl: item['avatar_url'] as String?,
                value: '${item['days_read'] ?? 0} dias',
                detail:
                    '${NumberFormat.compactCurrency(locale: "pt_BR", symbol: "").format(item['total_pages'] ?? 0)} pág.',
              ),
            ),
            const SizedBox(height: 20),

            _StatsBlock(
              title: 'Meses mais produtivos',
              icon: Icons.bar_chart_outlined,
              color: AppColors.forestGreenLight,
              provider: ref.watch(_productiveMonthsProvider(clubId)),
              builder: (item) => _SimpleStatRow(
                label: item['month_label'] as String? ?? '—',
                value:
                    '${NumberFormat.compactCurrency(locale: "pt_BR", symbol: "").format(item['total_pages'] ?? 0)} pág.',
                detail: '${item['total_sessions'] ?? 0} sessões',
              ),
            ),
            const SizedBox(height: 20),

            _StatsBlock(
              title: 'Livros mais polêmicos',
              icon: Icons.whatshot_outlined,
              color: AppColors.error,
              provider: ref.watch(_controversialBooksProvider(clubId)),
              emptyMessage:
                  'Ainda sem dados. Adicione impressões nas sessões!',
              builder: (item) => _BookStatRow(
                title: item['book_title'] as String? ?? '—',
                subtitle: item['book_author'] as String?,
                value:
                    '${item['distinct_moods'] ?? 0} humores diferentes',
                detail: '${item['total_sessions'] ?? 0} sessões',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Bloco genérico ────────────────────────────────────────────────────────────

class _StatsBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<Map<String, dynamic>>> provider;
  final Widget Function(Map<String, dynamic>) builder;
  final String? emptyMessage;

  const _StatsBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.provider,
    required this.builder,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: provider.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    emptyMessage ?? 'Sem dados suficientes ainda.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic),
                  ),
                );
              }
              return Column(
                children: items.asMap().entries.map((e) {
                  final isLast = e.key == items.length - 1;
                  final isDarkInner =
                      Theme.of(context).brightness == Brightness.dark;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: builder(e.value),
                      ),
                      if (!isLast)
                        Divider(
                            height: 1,
                            indent: 14,
                            endIndent: 14,
                            color: isDarkInner
                                ? AppColors.darkBorder
                                : AppColors.border),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Rows de estatísticas ──────────────────────────────────────────────────────

class _BookStatRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final String? detail;

  const _BookStatRow({
    required this.title,
    this.subtitle,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.warmGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.menu_book_outlined,
                color: AppColors.warmGold, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.forestGreen)),
            if (detail != null)
              Text(detail!,
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ],
    );
  }
}

class _MemberStatRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String value;
  final String? detail;

  const _MemberStatRow({
    required this.name,
    this.avatarUrl,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        MiniAvatar(url: avatarUrl, name: name, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.warmGold)),
            if (detail != null)
              Text(detail!,
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ],
    );
  }
}

class _SimpleStatRow extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;

  const _SimpleStatRow({
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.forestGreenLight)),
            if (detail != null)
              Text(detail!,
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ],
    );
  }
}
