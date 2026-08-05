import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _collectiveProgressProvider =
    FutureProvider.family<ChallengeCollectiveProgress?, String>(
        (ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchCollectiveProgress(challengeId);
});

final _myContributionPctProvider =
    FutureProvider.family<double?, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchMyContributionPct(challengeId);
});

final _restDaysLeftProvider =
    FutureProvider.family<int, String>((ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchRestDaysLeft(challengeId);
});

final _todayContributorsProvider =
    FutureProvider.family<List<Map<String, String?>>, String>(
        (ref, challengeId) {
  return ref
      .read(bookClubRepositoryProvider)
      .fetchTodayContributors(challengeId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengeDetailScreen extends ConsumerWidget {
  final String clubId;
  final String challengeId;
  final String challengeTitle;

  /// Objeto completo do desafio — necessário para tela de resultado.
  final ClubChallenge? challenge;

  /// URL da capa do livro atual do clube — usado para o tint de cor do fundo.
  final String? coverUrl;

  const ChallengeDetailScreen({
    super.key,
    required this.clubId,
    required this.challengeId,
    required this.challengeTitle,
    this.challenge,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Invalida ao finalizar qualquer sessão de leitura.
    ref.listen(clubSessionRefreshProvider, (_, __) {
      ref.invalidate(_collectiveProgressProvider(challengeId));
      ref.invalidate(_myContributionPctProvider(challengeId));
    });

    final progressAsync =
        ref.watch(_collectiveProgressProvider(challengeId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challengeTitle,
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              'Desafio',
              style:
                  ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
            ),
          ],
        ),
        actions: [
          // Resultado (só se encerrado)
          if (challenge != null &&
              challenge!.status == ChallengeStatus.finished)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              tooltip: 'Ver resultado',
              color: ReadLogColors.inkMuted,
              onPressed: () => context.push(
                '/clubs/$clubId/challenges/$challengeId/result',
                extra: {'challenge': challenge},
              ),
            ),
        ],
      ),
      body: LumenClubTintBackground(
        coverUrl: coverUrl,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_collectiveProgressProvider(challengeId));
            ref.invalidate(_myContributionPctProvider(challengeId));
            ref.invalidate(_restDaysLeftProvider(challengeId));
            ref.invalidate(_todayContributorsProvider(challengeId));
          },
          child: progressAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: ReadLogColors.progress),
            ),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (collective) => _ChallengeBody(
              collective: collective,
              clubId: clubId,
              challengeId: challengeId,
              challenge: challenge,
              totalMembers: collective?.totalMembers ?? 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ChallengeBody extends ConsumerWidget {
  final ChallengeCollectiveProgress? collective;
  final String clubId;
  final String challengeId;
  final ClubChallenge? challenge;
  final int totalMembers;

  const _ChallengeBody({
    required this.collective,
    required this.clubId,
    required this.challengeId,
    this.challenge,
    this.totalMembers = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.decimalPattern('pt_BR');

    // Contribuição pessoal — carregada em paralelo, não bloqueia o corpo
    final myPctAsync = ref.watch(_myContributionPctProvider(challengeId));
    final myPct = myPctAsync.valueOrNull;

    // Rest Days — visível apenas pro próprio membro, não social
    final restDaysAsync = ref.watch(_restDaysLeftProvider(challengeId));
    final restDaysLeft = restDaysAsync.valueOrNull ?? 0;

    // "Já leram hoje" — carregado em paralelo, não bloqueia o corpo
    final todayAsync = ref.watch(_todayContributorsProvider(challengeId));
    final todayContributors = todayAsync.valueOrNull ?? [];

    if (collective == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Participação automática — contexto para quem vê pela 1ª vez
              if (totalMembers > 0) ...[
                Text(
                  'Todos os $totalMembers membros participam automaticamente',
                  style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Nenhum progresso ainda.\nComece a ler para aparecer aqui.',
                style: ReadLogType.mono(size: 13, color: ReadLogColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final c = collective!;
    final barFill = (c.pctComplete / 100).clamp(0.0, 1.0);
    final effectiveTotalMembers = totalMembers > 0 ? totalMembers : c.totalMembers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Participação automática — todos N membros ─────────────────────
        if (effectiveTotalMembers > 0) ...[
          Text(
            'Todos os $effectiveTotalMembers membros participam automaticamente',
            style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
          ),
          const SizedBox(height: 20),
        ],

        // ── Bloco coletivo — progresso do clube ───────────────────────────
        Text(
          'Meta do clube',
          style: ReadLogType.mono(
            size: 10,
            color: ReadLogColors.inkGhost,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 12),

        // Barra de progresso coletiva
        LayoutBuilder(builder: (context, constraints) {
          final filled = constraints.maxWidth * barFill;
          return SizedBox(
            height: 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: ReadLogColors.hairline,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Container(
                  height: 2,
                  width: filled,
                  decoration: BoxDecoration(
                    color: ReadLogColors.ink,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Positioned(
                  left: filled - 3,
                  top: -2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: ReadLogColors.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),

        // "62% · 6.200 de 10.000 páginas"
        Text(
          '${c.pctComplete.toStringAsFixed(0)}% · '
          '${fmt.format(c.currentValue)} de ${fmt.format(c.targetValue)}'
          '${challenge != null ? ' ${challenge!.goalType.unit}' : ''}',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
        ),
        const SizedBox(height: 4),

        // "19 dias restantes"
        Text(
          c.daysLeft < 0
              ? 'Encerrado'
              : c.daysLeft == 0
                  ? 'Último dia!'
                  : '${c.daysLeft} dias restantes',
          style: ReadLogType.mono(size: 11, color: ReadLogColors.inkGhost),
        ),

        // Contribuição pessoal — linha discreta, só para o próprio membro
        if (myPct != null) ...[
          const SizedBox(height: 8),
          Text(
            'Sua contribuição: ${myPct.toStringAsFixed(0)}% do total',
            style:
                ReadLogType.mono(size: 11, color: ReadLogColors.inkGhost),
          ),
        ],

        const Divider(height: 36, color: ReadLogColors.hairline),

        // ── Rest Days — dado pessoal, não social ─────────────────────────
        if (challenge != null && challenge!.isOngoing) ...[
          _RestDaysRow(
            challengeId: challengeId,
            daysLeft: restDaysLeft,
            ref: ref,
          ),
          const Divider(height: 28, color: ReadLogColors.hairline),
        ],

        // ── Participação ──────────────────────────────────────────────────
        Text(
          '${c.activeMembers} de $effectiveTotalMembers membros contribuíram',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
        ),

        // ── Já leram hoje — fileira de fotos, reforço social ──────────────
        if (todayContributors.isNotEmpty) ...[
          const Divider(height: 28, color: ReadLogColors.hairline),
          Text(
            'já leram hoje',
            style: ReadLogType.mono(size: 10, color: ReadLogColors.inkGhost)
                .copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          _TodayAvatarRow(contributors: todayContributors),
        ],
      ],
    );
  }
}

// ── Fileira de avatares sobrepostos — "Já leram hoje" ────────────────────────

class _TodayAvatarRow extends StatelessWidget {
  final List<Map<String, String?>> contributors;

  const _TodayAvatarRow({required this.contributors});

  @override
  Widget build(BuildContext context) {
    const double r = 14; // raio
    const double overlap = 10; // sobreposição em px
    // Limita a 12 avatares visíveis — sem número ao lado, só a fileira
    final visible = contributors.take(12).toList();

    return SizedBox(
      height: r * 2 + 2, // altura exata dos círculos
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (r * 2 - overlap),
              child: LumenAvatar(
                name: visible[i]['name'] ?? '',
                avatarUrl: visible[i]['avatar_url'],
                radius: r,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Rest Days — linha simples, dado pessoal ───────────────────────────────────

class _RestDaysRow extends StatefulWidget {
  final String challengeId;
  final int daysLeft;
  final WidgetRef ref;

  const _RestDaysRow({
    required this.challengeId,
    required this.daysLeft,
    required this.ref,
  });

  @override
  State<_RestDaysRow> createState() => _RestDaysRowState();
}

class _RestDaysRowState extends State<_RestDaysRow> {
  bool _loading = false;

  Future<void> _useRestDay() async {
    setState(() => _loading = true);
    final used = await widget.ref
        .read(bookClubRepositoryProvider)
        .useRestDay(widget.challengeId);
    if (mounted) {
      setState(() => _loading = false);
      if (used) {
        widget.ref.invalidate(_restDaysLeftProvider(widget.challengeId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dia de descanso registrado.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhum dia de descanso disponível.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.daysLeft > 0
              ? '${widget.daysLeft} ${widget.daysLeft == 1 ? 'dia' : 'dias'} de descanso disponíveis'
              : 'Nenhum dia de descanso disponível',
          style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
        ),
        if (widget.daysLeft > 0)
          _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: ReadLogColors.ink,
                  ),
                )
              : GestureDetector(
                  onTap: _useRestDay,
                  child: Text(
                    'Usar hoje',
                    style: ReadLogType.mono(
                      size: 12,
                      color: ReadLogColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
      ],
    );
  }
}
