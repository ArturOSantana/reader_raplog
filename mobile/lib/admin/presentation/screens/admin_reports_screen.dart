import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../admin_providers.dart';
import '../../data/admin_repository.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminReportsFilterProvider);
    final reportsAsync = ref.watch(adminReportsProvider);

    const filters = [
      (label: 'Abertas', value: 'open'),
      (label: 'Resolvidas', value: 'resolved'),
      (label: 'Ignoradas', value: 'dismissed'),
      (label: 'Todas', value: null),
    ];

    return Scaffold(
      backgroundColor: LumenColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Denúncias',
                  style:
                      LumenType.display(size: 26, color: LumenColors.ink),
                ),
                const SizedBox(height: 12),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((f) {
                      final active = filter == f.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => ref
                              .read(adminReportsFilterProvider.notifier)
                              .state = f.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? LumenColors.ink
                                  : LumenColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: active
                                    ? LumenColors.ink
                                    : LumenColors.divider,
                              ),
                            ),
                            child: Text(
                              f.label,
                              style: LumenType.mono(
                                size: 11,
                                color: active
                                    ? LumenColors.inkInverse
                                    : LumenColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: LumenColors.divider, height: 1),
          Expanded(
            child: reportsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Erro ao carregar denúncias',
                  style: LumenType.mono(size: 13, color: LumenColors.danger),
                ),
              ),
              data: (reports) => reports.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma denúncia encontrada',
                        style: LumenType.mono(
                            size: 13, color: LumenColors.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: LumenColors.hairline, height: 1),
                      itemBuilder: (context, i) => _ReportRow(
                        report: reports[i],
                        onResolve: () async {
                          await ref
                              .read(adminRepositoryProvider)
                              .updateReportStatus(reports[i].id, 'resolved');
                          ref.invalidate(adminReportsProvider);
                        },
                        onDismiss: () async {
                          await ref
                              .read(adminRepositoryProvider)
                              .updateReportStatus(reports[i].id, 'dismissed');
                          ref.invalidate(adminReportsProvider);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final AdminReport report;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  const _ReportRow({
    required this.report,
    required this.onResolve,
    required this.onDismiss,
  });

  Color _statusColor() {
    return switch (report.status) {
      'open' => LumenColors.danger,
      'resolved' => LumenColors.progress,
      _ => LumenColors.inkMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm', 'pt_BR');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.reason.isEmpty ? '(sem motivo)' : report.reason,
                  style: LumenType.mono(size: 14, color: LumenColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report.status,
                  style: LumenType.mono(
                      size: 10, color: _statusColor()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${report.targetType} · ${fmt.format(report.createdAt)}',
            style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
          ),
          if (report.status == 'open') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionButton(
                  label: 'Resolver',
                  color: LumenColors.progress,
                  onTap: onResolve,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Ignorar',
                  color: LumenColors.inkMuted,
                  onTap: onDismiss,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: LumenType.mono(size: 11, color: color),
        ),
      ),
    );
  }
}
