import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/readlog_theme.dart';
import '../../admin_providers.dart';
import '../../data/admin_repository.dart';

class AdminSubscriptionsScreen extends ConsumerWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(adminSubscriptionsProvider);

    return Scaffold(
      backgroundColor: ReadLogColors.surface,
      body: subsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar assinaturas',
            style: ReadLogType.mono(size: 13, color: ReadLogColors.danger),
          ),
        ),
        data: (subs) {
          final active = subs.where((s) => s.status == 'active').length;
          final canceled = subs.where((s) => s.status == 'canceled').length;
          final pastDue = subs.where((s) => s.status == 'past_due').length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assinaturas',
                      style: ReadLogType.display(
                          size: 26, color: ReadLogColors.ink),
                    ),
                    const SizedBox(height: 12),
                    // Resumo
                    Row(
                      children: [
                        _Badge(
                            label: '$active ativas',
                            color: ReadLogColors.progress),
                        const SizedBox(width: 8),
                        _Badge(
                            label: '$canceled canceladas',
                            color: ReadLogColors.inkMuted),
                        const SizedBox(width: 8),
                        _Badge(
                            label: '$pastDue em atraso',
                            color: ReadLogColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: ReadLogColors.divider, height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: subs.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: ReadLogColors.hairline, height: 1),
                  itemBuilder: (context, i) =>
                      _SubscriptionRow(sub: subs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: ReadLogType.mono(size: 11, color: color)),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  final AdminSubscription sub;
  const _SubscriptionRow({required this.sub});

  Color _statusColor() => switch (sub.status) {
        'active' => ReadLogColors.progress,
        'past_due' => ReadLogColors.warning,
        _ => ReadLogColors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy', 'pt_BR');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.plan.toUpperCase(),
                  style: ReadLogType.mono(
                    size: 13,
                    weight: FontWeight.w600,
                    color: ReadLogColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'user: ${sub.userId.substring(0, 8)}… · desde ${fmt.format(sub.startedAt)}',
                  style: ReadLogType.mono(
                      size: 11, color: ReadLogColors.inkMuted),
                ),
                if (sub.expiresAt != null)
                  Text(
                    'expira em ${fmt.format(sub.expiresAt!)}',
                    style: ReadLogType.mono(
                        size: 11, color: ReadLogColors.inkMuted),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sub.status,
              style: ReadLogType.mono(size: 10, color: _statusColor()),
            ),
          ),
        ],
      ),
    );
  }
}
