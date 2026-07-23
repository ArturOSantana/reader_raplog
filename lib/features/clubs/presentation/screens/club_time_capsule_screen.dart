import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_stories_and_capsule.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _timeCapsuleProvider =
    FutureProvider.family<List<ClubTimeCapsuleEntry>, String>(
        (ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listTimeCapsule(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubTimeCapsuleScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubTimeCapsuleScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final capsuleAsync = ref.watch(_timeCapsuleProvider(clubId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cápsula do Tempo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Depositar mensagem',
            onPressed: () => _showDepositSheet(context, ref),
          ),
        ],
      ),
      body: capsuleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar a cápsula.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ),
        ),
        data: (entries) {
          final revealed =
              entries.where((e) => e.isRevealed).toList();
          final pending =
              entries.where((e) => e.isPending).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_timeCapsuleProvider(clubId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                _InfoBanner(),
                const SizedBox(height: 20),

                // Mensagens reveladas
                if (revealed.isNotEmpty) ...[
                  _SectionHeader(
                      title: 'Reveladas (${revealed.length})',
                      icon: Icons.lock_open_outlined,
                      color: AppColors.forestGreen),
                  const SizedBox(height: 10),
                  ...revealed.map((e) => _CapsuleCard(entry: e, revealed: true)),
                  const SizedBox(height: 20),
                ],

                // Mensagens pendentes
                _SectionHeader(
                    title: pending.isEmpty
                        ? 'Nenhuma mensagem pendente'
                        : 'Aguardando revelação (${pending.length})',
                    icon: Icons.lock_outlined,
                    color: AppColors.warmGold),
                const SizedBox(height: 10),
                if (pending.isEmpty)
                  _EmptyPendingCard()
                else
                  ...pending.map((e) => _CapsuleCard(
                        entry: e,
                        revealed: false,
                        onDelete: () async {
                          await ref
                              .read(bookClubRepositoryProvider)
                              .deleteTimeCapsuleMessage(e.id);
                          ref.invalidate(_timeCapsuleProvider(clubId));
                        },
                      )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDepositSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DepositSheet(
        clubId: clubId,
        onDeposited: () => ref.invalidate(_timeCapsuleProvider(clubId)),
      ),
    );
  }
}

// ── Banner informativo ────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.warmGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_outlined, size: 22, color: AppColors.warmGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Deposite uma mensagem hoje — ela será revelada para o clube daqui 1 ano.',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.onSurface)),
      ],
    );
  }
}

class _EmptyPendingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.mail_outline_rounded, size: 32, color: AppColors.warmGold),
          const SizedBox(height: 8),
          Text('Nenhuma mensagem depositada ainda.',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Toque em + para depositar a sua.',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

// ── Card da cápsula ───────────────────────────────────────────────────────────

class _CapsuleCard extends StatelessWidget {
  final ClubTimeCapsuleEntry entry;
  final bool revealed;
  final VoidCallback? onDelete;

  const _CapsuleCard({
    required this.entry,
    required this.revealed,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat("d 'de' MMM 'de' yyyy", 'pt_BR');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: revealed
              ? AppColors.forestGreen.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                revealed ? Icons.move_to_inbox_outlined : Icons.mail_outline_rounded,
                size: 18,
                color: revealed ? AppColors.forestGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.authorName ?? 'Membro',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      revealed
                          ? 'Revelada em ${fmt.format(entry.revealedAt!.toLocal())}'
                          : entry.revealLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: revealed
                              ? AppColors.forestGreen
                              : cs.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              if (!revealed && onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                ),
            ],
          ),
          if (revealed) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${entry.message}"',
                style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5),
              ),
            ),
            if (entry.bookTitle != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(entry.bookTitle!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Depositada em ${fmt.format(entry.createdAt.toLocal())}',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sheet de depósito ─────────────────────────────────────────────────────────

class _DepositSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onDeposited;

  const _DepositSheet(
      {required this.clubId, required this.onDeposited});

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(bookClubRepositoryProvider).addTimeCapsuleMessage(
            clubId: widget.clubId,
            message: text,
          );
      widget.onDeposited();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Depositar na Cápsula',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Sua mensagem será revelada para o clube daqui 1 ano.',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 6,
              minLines: 3,
              maxLength: 1000,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'O que você quer dizer para o grupo daqui um ano?',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Depositar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
