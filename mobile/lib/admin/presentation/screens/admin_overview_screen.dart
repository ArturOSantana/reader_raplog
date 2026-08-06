import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../admin_providers.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: LumenColors.surface,
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar dados',
            style: LumenType.mono(size: 13, color: LumenColors.danger),
          ),
        ),
        data: (overview) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: LumenType.display(size: 26, color: LumenColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Visão geral da plataforma',
                style: LumenType.mono(size: 13, color: LumenColors.inkMuted),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.people_outline,
                    label: 'Usuários',
                    value: overview.totalUsers.toString(),
                    color: LumenColors.progress,
                  ),
                  _StatCard(
                    icon: Icons.groups_2_outlined,
                    label: 'Clubes',
                    value: overview.totalClubs.toString(),
                    color: LumenColors.ink,
                  ),
                  _StatCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Livros',
                    value: overview.totalBooks.toString(),
                    color: LumenColors.ink,
                  ),
                  _StatCard(
                    icon: Icons.play_circle_outline,
                    label: 'Sessões',
                    value: overview.totalSessions.toString(),
                    color: LumenColors.ink,
                  ),
                  _StatCard(
                    icon: Icons.flag_outlined,
                    label: 'Denúncias Abertas',
                    value: overview.openReports.toString(),
                    color: overview.openReports > 0
                        ? LumenColors.danger
                        : LumenColors.ink,
                  ),
                  _StatCard(
                    icon: Icons.card_membership_outlined,
                    label: 'Assinaturas Ativas',
                    value: overview.activeSubscriptions.toString(),
                    color: LumenColors.progress,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LumenColors.surfaceVariant,
        border: Border.all(color: LumenColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: LumenType.mono(
              size: 28,
              weight: FontWeight.w700,
              color: LumenColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: LumenType.mono(
              size: 11,
              color: LumenColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
