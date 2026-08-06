import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

/// Faixa de presença "quem está lendo agora" — exibida na Home do clube.
/// Sem avatar circular com anel colorido, sem indicador de status por pessoa.
/// A presença global já fica no LumenLiveIndicator do topo — aqui é lista.
class ClubPresenceStrip extends ConsumerWidget {
  final String clubId;

  const ClubPresenceStrip({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(clubPresenceProvider(clubId));

    return presenceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();
        return _PresenceStripBody(members: members);
      },
    );
  }
}

class _PresenceStripBody extends StatelessWidget {
  final List<ClubPresenceMember> members;

  const _PresenceStripBody({required this.members});

  @override
  Widget build(BuildContext context) {
    final active = members.where((m) => m.isActive).toList();
    final recent = members.where((m) => !m.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kicker
        Text(
          'LENDO AGORA',
          style: LumenType.mono(
            size: 10,
            color: LumenColors.inkMuted,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        // Lista de membros ativos — nome + tempo, sem avatar
        ...active.map((m) => _PresenceRow(member: m)),
        if (active.isNotEmpty && recent.isNotEmpty)
          const Divider(height: 16, color: LumenColors.hairline),
        ...recent.take(3).map((m) => _PresenceRow(member: m)),
      ],
    );
  }
}

class _PresenceRow extends StatelessWidget {
  final ClubPresenceMember member;

  const _PresenceRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ponto de presença + nome
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: member.isActive
                      ? LumenColors.progress
                      : LumenColors.inkGhost,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                member.userName ?? 'Leitor',
                style: LumenType.mono(
                  size: 13,
                  color: member.isActive
                      ? LumenColors.ink
                      : LumenColors.inkMuted,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Tempo
          Text(
            member.presenceLabel,
            style: LumenType.mono(
              size: 11,
              color: LumenColors.inkGhost,
            ),
          ),
        ],
      ),
    );
  }
}
