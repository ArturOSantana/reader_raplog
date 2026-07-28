import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

class InviteFriendSheet extends ConsumerWidget {
  const InviteFriendSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // O "username" público é o nome do perfil; fallback para o e-mail
    final displayName = user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        'readlog-user';

    // Link de convite — em produção substituir pelo deep link real
    final inviteLink = 'https://readlog.app/invite?ref=${user?.id ?? ""}';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('Convidar amigos', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Compartilhe seu link ou diga o seu nome de usuário para que amigos te encontrem.',
            style: AppTextStyles.bodyMedium,
          ),

          const SizedBox(height: 24),

          // Nome de usuário
          _InfoTile(
            label: 'Meu nome no Readlog',
            value: displayName,
            onCopy: () => _copy(context, displayName, 'Nome copiado!'),
          ),

          const SizedBox(height: 12),

          // Link de convite
          _InfoTile(
            label: 'Link de convite',
            value: inviteLink,
            onCopy: () => _copy(context, inviteLink, 'Link copiado!'),
          ),

          const SizedBox(height: 28),

          FilledButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartilhar link'),
            onPressed: () => _share(context, inviteLink, displayName),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _share(BuildContext context, String link, String name) {
    // Share via sistema — usa clipboard como fallback
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Link copiado! Cole em qualquer app para compartilhar.'),
      ));
    Navigator.pop(context);
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_outlined, size: 18),
            color: AppColors.forestGreen,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
