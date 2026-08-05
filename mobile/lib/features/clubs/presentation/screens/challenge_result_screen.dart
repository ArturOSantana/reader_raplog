import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _challengeResultProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchChallengeResult(challengeId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengeResultScreen extends ConsumerWidget {
  final ClubChallenge challenge;
  final String? coverUrl;

  const ChallengeResultScreen({
    super.key,
    required this.challenge,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(_challengeResultProvider(challenge.id));

    return LumenClubTintBackground(
      coverUrl: coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Text(
          'Resultado',
          style: ReadLogType.display(
            size: 15,
            color: ReadLogColors.ink,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: resultAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ReadLogColors.progress),
        ),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (result) => _ResultBody(
          challenge: challenge,
          result: result,
        ),
      ),
    ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ResultBody extends StatelessWidget {
  final ClubChallenge challenge;
  final Map<String, dynamic>? result;

  const _ResultBody({required this.challenge, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final fmt = DateFormat("d 'de' MMM 'de' yyyy", 'pt_BR');
    final fmtNum = NumberFormat.decimalPattern('pt_BR');

    final totalValue = (r?['total_value'] as num?)?.toInt() ?? 0;
    final targetValue = (r?['target_value'] as num?)?.toInt() ?? 0;
    final activeMembers = (r?['active_members'] as num?)?.toInt() ?? 0;
    final totalMembers = (r?['total_members'] as num?)?.toInt() ?? 0;
    final goalReached = totalValue >= targetValue && targetValue > 0;
    final wasCancelled = challenge.status == ChallengeStatus.cancelled;

    // Frase de encerramento — mesmo tom nos dois casos, sem sugerir derrota
    final String closingHeadline;
    if (wasCancelled) {
      closingHeadline = 'Desafio interrompido.';
    } else if (goalReached) {
      closingHeadline = 'Desafio concluído.';
    } else {
      closingHeadline = 'O desafio terminou.';
    }

    final String closingBody;
    if (wasCancelled) {
      closingBody = 'O desafio foi encerrado antes do prazo.';
    } else if (goalReached) {
      closingBody =
          'Vocês leram ${fmtNum.format(totalValue)} ${challenge.goalType.unit} juntos.';
    } else {
      closingBody =
          'Vocês leram ${fmtNum.format(totalValue)} de ${fmtNum.format(targetValue)} '
          '${challenge.goalType.unit} propostos.';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Frase de encerramento ─────────────────────────────────────────
        Text(
          closingHeadline,
          style: ReadLogType.display(
            size: 28,
            color: ReadLogColors.ink,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          closingBody,
          style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
        ),
        const SizedBox(height: 4),
        Text(
          '${fmt.format(challenge.startsAt)} – ${fmt.format(challenge.endsAt)}',
          style: ReadLogType.mono(size: 11, color: ReadLogColors.inkGhost),
        ),
        const SizedBox(height: 40),

        // ── Estatísticas em formato editorial ─────────────────────────────
        if (totalValue > 0) ...[
          _StatLine(
            value: fmtNum.format(totalValue),
            label: '${challenge.goalType.unit} lidos no total',
          ),
          const Divider(height: 32, color: ReadLogColors.hairline),
        ],
        // Contagem de participação — nunca lista ordenada por volume
        _StatLine(
          value: '$activeMembers de $totalMembers',
          label: 'membros contribuíram',
        ),
      ],
    );
  }
}

// ── Linha de estatística ──────────────────────────────────────────────────────

class _StatLine extends StatelessWidget {
  final String value;
  final String label;

  const _StatLine({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: ReadLogType.display(
            size: 42,
            color: ReadLogColors.ink,
            weight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: ReadLogType.mono(
            size: 11,
            color: ReadLogColors.inkMuted,
          ).copyWith(letterSpacing: 0.8),
        ),
      ],
    );
  }
}
