import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estatísticas', style: ReadLogType.bookTitle(size: 16)),
            Text(clubName,
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 12)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_mostReadBooksProvider(clubId));
          ref.invalidate(_mostConsistentProvider(clubId));
          ref.invalidate(_productiveMonthsProvider(clubId));
          ref.invalidate(_controversialBooksProvider(clubId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatsBlock(
              title: 'Livros mais lidos',
              provider: ref.watch(_mostReadBooksProvider(clubId)),
              builder: (item) => _DataRow(
                primary: item['book_title'] as String? ?? '—',
                secondary: item['book_author'] as String?,
                value: NumberFormat.compactCurrency(
                        locale: 'pt_BR', symbol: '')
                    .format(item['total_pages'] ?? 0),
                detail:
                    '${item['readers'] ?? 0} ${(item['readers'] ?? 0) == 1 ? 'leitor' : 'leitores'}',
              ),
            ),
            const SizedBox(height: 28),

            _StatsBlock(
              title: 'Membros mais consistentes',
              provider: ref.watch(_mostConsistentProvider(clubId)),
              builder: (item) => _DataRow(
                primary: item['user_name'] as String? ?? 'Membro',
                value: '${item['days_read'] ?? 0} dias',
                detail: NumberFormat.compactCurrency(
                        locale: 'pt_BR', symbol: '')
                    .format(item['total_pages'] ?? 0),
              ),
            ),
            const SizedBox(height: 28),

            _StatsBlock(
              title: 'Meses mais produtivos',
              provider: ref.watch(_productiveMonthsProvider(clubId)),
              builder: (item) => _DataRow(
                primary: item['month_label'] as String? ?? '—',
                value: NumberFormat.compactCurrency(
                        locale: 'pt_BR', symbol: '')
                    .format(item['total_pages'] ?? 0),
                detail: '${item['total_sessions'] ?? 0} sessões',
              ),
            ),
            const SizedBox(height: 28),

            _StatsBlock(
              title: 'Livros mais polêmicos',
              provider: ref.watch(_controversialBooksProvider(clubId)),
              emptyMessage: 'Sem dados ainda. Adicione impressões nas sessões.',
              builder: (item) => _DataRow(
                primary: item['book_title'] as String? ?? '—',
                secondary: item['book_author'] as String?,
                value: '${item['distinct_moods'] ?? 0} humores',
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
  final AsyncValue<List<Map<String, dynamic>>> provider;
  final Widget Function(Map<String, dynamic>) builder;
  final String? emptyMessage;

  const _StatsBlock({
    required this.title,
    required this.provider,
    required this.builder,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: ReadLogType.kicker(color: ReadLogColors.inkMuted, size: 11),
        ),
        const SizedBox(height: 8),
        provider.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Erro ao carregar',
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 13)),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                emptyMessage ?? 'Sem dados suficientes ainda.',
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 13),
              );
            }
            return Column(
              children: items.asMap().entries.map((e) {
                return Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: builder(e.value),
                    ),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Linha de dado ─────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  final String primary;
  final String? secondary;
  final String value;
  final String? detail;

  const _DataRow({
    required this.primary,
    this.secondary,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(primary,
                  style: ReadLogType.authorName(size: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (secondary != null)
                Text(secondary!,
                    style: ReadLogType.authorName(
                        color: ReadLogColors.inkMuted, size: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: ReadLogType.mono(
                    size: 12, color: ReadLogColors.ink)),
            if (detail != null)
              Text(detail!,
                  style: ReadLogType.mono(
                      size: 10, color: ReadLogColors.inkGhost)),
          ],
        ),
      ],
    );
  }
}
