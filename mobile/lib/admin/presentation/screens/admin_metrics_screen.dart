import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../admin_providers.dart';

class AdminMetricsScreen extends ConsumerWidget {
  const AdminMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: LumenColors.surface,
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar métricas',
            style: LumenType.mono(size: 13, color: LumenColors.danger),
          ),
        ),
        data: (ov) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Métricas',
                style: LumenType.display(size: 26, color: LumenColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Indicadores de crescimento e uso',
                style: LumenType.mono(size: 13, color: LumenColors.inkMuted),
              ),
              const SizedBox(height: 32),
              _MetricSection(
                title: 'USUÁRIOS',
                rows: [
                  _MetricRow('Total de usuários', ov.totalUsers.toString()),
                  _MetricRow('Ativos (30d)', ov.activeUsersLast30d.toString()),
                ],
              ),
              const SizedBox(height: 24),
              _MetricSection(
                title: 'CONTEÚDO',
                rows: [
                  _MetricRow('Clubes', ov.totalClubs.toString()),
                  _MetricRow('Livros cadastrados', ov.totalBooks.toString()),
                  _MetricRow('Sessões de leitura', ov.totalSessions.toString()),
                ],
              ),
              const SizedBox(height: 24),
              _MetricSection(
                title: 'SAÚDE',
                rows: [
                  _MetricRow('Denúncias abertas', ov.openReports.toString(),
                      warning: ov.openReports > 0),
                  _MetricRow(
                      'Assinaturas ativas', ov.activeSubscriptions.toString()),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LumenColors.surfaceVariant,
                  border: Border.all(color: LumenColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: LumenColors.inkMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Métricas de retenção, DAU/MAU e funil de conversão '
                        'serão exibidas aqui conforme as tabelas de analytics '
                        'forem configuradas no Supabase.',
                        style: LumenType.mono(
                            size: 11, color: LumenColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  final String title;
  final List<_MetricRow> rows;

  const _MetricSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: LumenType.mono(
            size: 10,
            color: LumenColors.progress,
          ).copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: LumenColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(
                        color: LumenColors.hairline,
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _MetricRow(this.label, this.value, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: LumenType.mono(size: 14, color: LumenColors.ink),
          ),
          Text(
            value,
            style: LumenType.mono(
              size: 16,
              weight: FontWeight.w600,
              color: warning ? LumenColors.danger : LumenColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
