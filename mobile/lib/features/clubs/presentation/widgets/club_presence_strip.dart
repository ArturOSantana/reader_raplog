import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../theme/readlog_theme.dart';

/// Faixa horizontal "quem está lendo agora" — exibida no detalhe do clube.
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
          style: ReadLogType.mono(
            size: 10,
            color: ReadLogColors.cream.withValues(alpha: 0.5),
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        // Lista de membros
        ...active.map((m) => _PresenceRow(member: m)),
        if (active.isNotEmpty && recent.isNotEmpty)
          Divider(
            height: 16,
            color: ReadLogColors.inkLine,
          ),
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
    final dotColor =
        member.isActive ? ReadLogColors.online : ReadLogColors.idle;
    final nameStyle = ReadLogType.mono(
      size: 13,
      color: ReadLogColors.cream,
      weight: FontWeight.w500,
    );
    final subStyle = ReadLogType.mono(
      size: 11,
      color: ReadLogColors.cream.withValues(alpha: 0.5),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Avatar com dot de presença
          Stack(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    ReadLogColors.brass.withValues(alpha: 0.25),
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? Text(
                        (member.userName ?? '?')[0].toUpperCase(),
                        style: ReadLogType.mono(
                          size: 12,
                          color: ReadLogColors.brass,
                          weight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ReadLogColors.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Nome e label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.userName ?? 'Leitor', style: nameStyle),
                Text(member.presenceLabel, style: subStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
