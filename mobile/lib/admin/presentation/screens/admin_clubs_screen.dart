import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/readlog_theme.dart';
import '../../admin_providers.dart';
import '../../data/admin_repository.dart';

class AdminClubsScreen extends ConsumerWidget {
  const AdminClubsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(adminClubsProvider);

    return Scaffold(
      backgroundColor: ReadLogColors.surface,
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar clubes',
            style: ReadLogType.mono(size: 13, color: ReadLogColors.danger),
          ),
        ),
        data: (clubs) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clubes',
                    style: ReadLogType.display(
                        size: 26, color: ReadLogColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${clubs.length} clubes',
                    style: ReadLogType.mono(
                        size: 12, color: ReadLogColors.inkMuted),
                  ),
                ],
              ),
            ),
            Divider(color: ReadLogColors.divider, height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: clubs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: ReadLogColors.hairline, height: 1),
                itemBuilder: (context, index) =>
                    _ClubRow(club: clubs[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  final AdminClub club;
  const _ClubRow({required this.club});

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
                  club.name,
                  style: ReadLogType.mono(size: 14, color: ReadLogColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${club.memberCount} membros · criado em ${fmt.format(club.createdAt)}',
                  style: ReadLogType.mono(
                      size: 11, color: ReadLogColors.inkMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: club.isActive
                  ? ReadLogColors.progressSubtle
                  : ReadLogColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              club.isActive ? 'Ativo' : 'Inativo',
              style: ReadLogType.mono(
                size: 10,
                color: club.isActive
                    ? ReadLogColors.progress
                    : ReadLogColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
