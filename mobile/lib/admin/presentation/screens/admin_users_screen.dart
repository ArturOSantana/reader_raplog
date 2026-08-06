import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../admin_providers.dart';
import '../../data/admin_repository.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: LumenColors.surface,
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar usuários',
            style: LumenType.mono(size: 13, color: LumenColors.danger),
          ),
        ),
        data: (users) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuários',
                          style: LumenType.display(
                              size: 26, color: LumenColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${users.length} registros',
                          style: LumenType.mono(
                              size: 12, color: LumenColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: LumenColors.divider, height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    Divider(color: LumenColors.hairline, height: 1),
                itemBuilder: (context, index) =>
                    _UserRow(user: users[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy', 'pt_BR');
    final initials = (user.name ?? user.email)
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LumenColors.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: LumenColors.divider),
            ),
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: LumenType.mono(
                size: 12,
                weight: FontWeight.w700,
                color: LumenColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Dados
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? user.email,
                  style: LumenType.mono(
                    size: 14,
                    color: LumenColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.name != null)
                  Text(
                    user.email,
                    style: LumenType.mono(
                        size: 11, color: LumenColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status onboarding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: user.onboardingCompleted
                  ? LumenColors.progressSubtle
                  : LumenColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.onboardingCompleted ? 'Ativo' : 'Incompleto',
              style: LumenType.mono(
                size: 10,
                color: user.onboardingCompleted
                    ? LumenColors.progress
                    : LumenColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Data
          Text(
            fmt.format(user.createdAt),
            style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
