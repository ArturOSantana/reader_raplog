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
      backgroundColor: ReadLogColors.surface,
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar usuários',
            style: ReadLogType.mono(size: 13, color: ReadLogColors.danger),
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
                          style: ReadLogType.display(
                              size: 26, color: ReadLogColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${users.length} registros',
                          style: ReadLogType.mono(
                              size: 12, color: ReadLogColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: ReadLogColors.divider, height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    Divider(color: ReadLogColors.hairline, height: 1),
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
              color: ReadLogColors.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: ReadLogColors.divider),
            ),
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: ReadLogType.mono(
                size: 12,
                weight: FontWeight.w700,
                color: ReadLogColors.inkMuted,
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
                  style: ReadLogType.mono(
                    size: 14,
                    color: ReadLogColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.name != null)
                  Text(
                    user.email,
                    style: ReadLogType.mono(
                        size: 11, color: ReadLogColors.inkMuted),
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
                  ? ReadLogColors.progressSubtle
                  : ReadLogColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.onboardingCompleted ? 'Ativo' : 'Incompleto',
              style: ReadLogType.mono(
                size: 10,
                color: user.onboardingCompleted
                    ? ReadLogColors.progress
                    : ReadLogColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Data
          Text(
            fmt.format(user.createdAt),
            style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
