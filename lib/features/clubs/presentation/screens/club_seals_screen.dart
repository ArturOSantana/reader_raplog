import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_seals.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clubSealsProvider =
    FutureProvider.family<List<ClubSeal>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listSeals(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela de Selos do Clube — lista os selos distribuídos automaticamente.
/// Managers podem atribuir selos manualmente enquanto a lógica automática
/// não estiver totalmente implementada.
class ClubSealsScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final bool isManager;

  /// Lista de membros disponíveis para receber selos (id → nome + avatar).
  final List<ClubMemberSummary> members;

  const ClubSealsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.isManager,
    required this.members,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final sealsAsync = ref.watch(_clubSealsProvider(clubId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        centerTitle: false,
        actions: [
          if (isManager)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Atribuir selo',
              onPressed: () => _showAwardSheet(context, ref),
            ),
        ],
      ),
      body: sealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar os selos.\n$e',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
        ),
        data: (seals) {
          if (seals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_outlined,
                        size: 48, color: AppColors.warmGold),
                    const SizedBox(height: 12),
                    Text('Nenhum selo ainda.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    if (isManager)
                      Text('Toque em + para atribuir o primeiro selo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.45)))
                    else
                      Text('Os selos são distribuídos automaticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_clubSealsProvider(clubId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: seals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _SealCard(
                seal: seals[i],
                canRevoke: isManager,
                onRevoke: () async {
                  await ref
                      .read(bookClubRepositoryProvider)
                      .revokeSeal(seals[i].id);
                  ref.invalidate(_clubSealsProvider(clubId));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAwardSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AwardSealSheet(
        clubId: clubId,
        members: members,
        onAwarded: () => ref.invalidate(_clubSealsProvider(clubId)),
      ),
    );
  }
}

// ── Card de Selo ───────────────────────────────────────────────────────────────

class _SealCard extends StatelessWidget {
  final ClubSeal seal;
  final bool canRevoke;
  final VoidCallback onRevoke;

  const _SealCard({
    required this.seal,
    required this.canRevoke,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone do selo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warmGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(seal.sealType.icon,
                  size: 22, color: AppColors.warmGold),
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        seal.displayTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: cs.onSurface),
                      ),
                    ),
                    if (canRevoke)
                      GestureDetector(
                        onTap: () => _confirmRevoke(context),
                        child: Icon(Icons.close_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    MiniAvatar(
                      url: seal.awardedToAvatar,
                      name: seal.awardedToName ?? '?',
                      radius: 10,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      seal.awardedToName ?? 'Membro',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'por ${seal.awardedByName ?? 'admin'} · ${_fmtDate(seal.awardedAt)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revogar selo?'),
        content: Text(
            'Remover "${seal.displayTitle}" de ${seal.awardedToName ?? "membro"}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRevoke();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      DateFormat("d 'de' MMM", 'pt_BR').format(dt.toLocal());
}

// ── Sheet para atribuir um novo selo ──────────────────────────────────────────

class _AwardSealSheet extends ConsumerStatefulWidget {
  final String clubId;
  final List<ClubMemberSummary> members;
  final VoidCallback onAwarded;

  const _AwardSealSheet({
    required this.clubId,
    required this.members,
    required this.onAwarded,
  });

  @override
  ConsumerState<_AwardSealSheet> createState() => _AwardSealSheetState();
}

class _AwardSealSheetState extends ConsumerState<_AwardSealSheet> {
  ClubMemberSummary? _selectedMember;
  SealType _selectedType = SealType.bestReader;
  bool _saving = false;

  Future<void> _award() async {
    if (_selectedMember == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(bookClubRepositoryProvider).awardSeal(
            clubId: widget.clubId,
            awardedTo: _selectedMember!.id,
            sealType: _selectedType,
          );
      widget.onAwarded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atribuir selo: $e')),
        );
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Título ──────────────────────────────────────────────────────
            Text('Atribuir Selo',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: cs.onSurface)),
            const SizedBox(height: 16),

            // ── Para quem? ──────────────────────────────────────────────────
            _sectionLabel(context, 'Para quem?'),
            const SizedBox(height: 8),
            DropdownButtonFormField<ClubMemberSummary>(
              hint: const Text('Selecionar membro'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.members
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Row(
                          children: [
                            MiniAvatar(
                                url: m.avatarUrl, name: m.name, radius: 12),
                            const SizedBox(width: 8),
                            Text(m.name),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMember = v),
            ),
            const SizedBox(height: 16),

            // ── Tipo base ───────────────────────────────────────────────────
            _sectionLabel(context, 'Tipo de selo'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: SealType.values
                  .map((t) => GestureDetector(
                        onTap: () => setState(() => _selectedType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedType == t
                                ? AppColors.warmGold.withValues(alpha: 0.2)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedType == t
                                  ? AppColors.warmGold
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon,
                                  size: 14,
                                  color: _selectedType == t
                                      ? AppColors.warmGold
                                      : cs.onSurface.withValues(alpha: 0.7)),
                              const SizedBox(width: 5),
                              Text(t.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // ── Botões ──────────────────────────────────────────────────────
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
                    onPressed: (_selectedMember == null || _saving)
                        ? null
                        : _award,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Atribuir Selo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)));
  }
}
