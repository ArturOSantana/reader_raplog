import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_seals.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clubSealsProvider =
    FutureProvider.family<List<ClubSeal>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listSeals(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Selos do clube — lista os reconhecimentos concedidos.
/// Managers podem atribuir selos manualmente via sheet.
class ClubSealsScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final bool isManager;
  final String? coverUrl;

  /// Lista de membros disponíveis para receber selos.
  final List<ClubMemberSummary> members;

  const ClubSealsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.isManager,
    required this.members,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sealsAsync = ref.watch(_clubSealsProvider(clubId));

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reconhecimentos',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              clubName,
              style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
            ),
          ],
        ),
        actions: [
          if (isManager)
            IconButton(
              icon: LumenIcon('add', size: 20, color: ReadLogColors.ink),
              tooltip: 'Atribuir reconhecimento',
              onPressed: () => _showAwardSheet(context, ref),
            ),
        ],
      ),
      body: sealsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.progress),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar os reconhecimentos.',
              style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (seals) {
          if (seals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  isManager
                      ? 'Nenhum reconhecimento ainda.\nToque em + para conceder o primeiro.'
                      : 'Nenhum reconhecimento ainda.\nOs selos são concedidos pelo admin do clube.',
                  style: ReadLogType.mono(
                    size: 13,
                    color: ReadLogColors.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_clubSealsProvider(clubId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: seals.expand((s) => [
                    _SealRow(
                      seal: s,
                      canRevoke: isManager,
                      onRevoke: () async {
                        await ref
                            .read(bookClubRepositoryProvider)
                            .revokeSeal(s.id);
                        ref.invalidate(_clubSealsProvider(clubId));
                      },
                    ),
                    const Divider(height: 1, color: ReadLogColors.hairline),
                  ]).toList(),
            ),
          );
        },
      ),
    ),
    );
  }

  void _showAwardSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ReadLogColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _AwardSealSheet(
        clubId: clubId,
        members: members,
        onAwarded: () => ref.invalidate(_clubSealsProvider(clubId)),
      ),
    );
  }
}

// ── Linha de Selo ─────────────────────────────────────────────────────────────

class _SealRow extends StatelessWidget {
  final ClubSeal seal;
  final bool canRevoke;
  final VoidCallback onRevoke;

  const _SealRow({
    required this.seal,
    required this.canRevoke,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMM yyyy", 'pt_BR');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seal.displayTitle,
                  style: ReadLogType.display(
                    size: 14,
                    color: ReadLogColors.ink,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${seal.awardedToName ?? 'Membro'} · concedido por ${seal.awardedByName ?? 'admin'}',
                  style: ReadLogType.mono(
                    size: 11,
                    color: ReadLogColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  fmt.format(seal.awardedAt.toLocal()),
                  style: ReadLogType.mono(
                    size: 10,
                    color: ReadLogColors.inkGhost,
                  ),
                ),
              ],
            ),
          ),
          if (canRevoke)
            GestureDetector(
              onTap: () => _confirmRevoke(context),
              child: const Padding(
                padding: EdgeInsets.only(left: 12, top: 2),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ReadLogColors.inkGhost,
                ),
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
        title: const Text('Revogar reconhecimento?'),
        content: Text(
          'Remover "${seal.displayTitle}" de ${seal.awardedToName ?? "membro"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: ReadLogColors.danger,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onRevoke();
            },
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
  }
}

// ── Sheet para atribuir um novo reconhecimento ────────────────────────────────

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
          SnackBar(content: Text('Erro ao atribuir reconhecimento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Atribuir reconhecimento',
              style: ReadLogType.display(
                size: 18,
                color: ReadLogColors.ink,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Para quem?
            Text(
              'MEMBRO',
              style: ReadLogType.mono(
                size: 10,
                color: ReadLogColors.inkGhost,
              ).copyWith(letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ClubMemberSummary>(
              hint: Text(
                'Selecionar membro',
                style: ReadLogType.mono(
                  size: 13,
                  color: ReadLogColors.inkMuted,
                ),
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: ReadLogColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: ReadLogColors.divider),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.members
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.name,
                          style: ReadLogType.mono(
                            size: 13,
                            color: ReadLogColors.ink,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMember = v),
            ),
            const SizedBox(height: 20),

            // Tipo
            Text(
              'TIPO',
              style: ReadLogType.mono(
                size: 10,
                color: ReadLogColors.inkGhost,
              ).copyWith(letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            ...SealType.values.map(
              (t) => GestureDetector(
                onTap: () => setState(() => _selectedType = t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.label,
                          style: ReadLogType.mono(
                            size: 13,
                            color: _selectedType == t
                                ? ReadLogColors.ink
                                : ReadLogColors.inkMuted,
                            weight: _selectedType == t
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (_selectedType == t)
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: ReadLogColors.ink,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedMember == null || _saving) ? null : _award,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Atribuir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
