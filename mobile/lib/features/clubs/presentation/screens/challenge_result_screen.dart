import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

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

  const ChallengeResultScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final resultAsync = ref.watch(_challengeResultProvider(challenge.id));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Resultado do desafio',
          style: AppTextStyles.titleMedium
              .copyWith(color: cs.onSurface, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar',
            onPressed: () {
              final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Acabei o desafio "${challenge.title}" no ReadLog! '
                      '(${fmt.format(challenge.startsAt)} – '
                      '${fmt.format(challenge.endsAt)})',
                ),
              );
            },
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (result) => _ResultBody(
          challenge: challenge,
          result: result,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    // Campos do snapshot challenge_results (tabela real do banco)
    final r = result;
    final podium = <Map<String, dynamic>>[];
    if (r != null) {
      if (r['first_user_id'] != null) {
        podium.add({
          'user_name': r['first_user_name'],
          'avatar_url': null,
          'current_value': r['first_value'],
          'rank': 1,
        });
      }
      if (r['second_user_id'] != null) {
        podium.add({
          'user_name': r['second_user_name'],
          'avatar_url': null,
          'current_value': r['second_value'],
          'rank': 2,
        });
      }
      if (r['third_user_id'] != null) {
        podium.add({
          'user_name': r['third_user_name'],
          'avatar_url': null,
          'current_value': r['third_value'],
          'rank': 3,
        });
      }
    }
    final stats = <String, dynamic>{
      'participants':    r?['total_participants'],
      'completed':       r?['total_goal_completions'],
      'best_streak':     r?['longest_streak_days'],
      'total_value':     r?['total_pages'],
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Cabeçalho de celebração ───────────────────────────────────────
        _CelebrationHeader(challenge: challenge),
        const SizedBox(height: 24),

        // ── Pódio ─────────────────────────────────────────────────────────
        if (podium.isNotEmpty) ...[
          _SectionTitle(
              title: 'Pódio',
              icon: Icons.emoji_events_outlined),
          const SizedBox(height: 12),
          _PodiumRow(podium: podium, surface: surface, border: border),
          const SizedBox(height: 24),
        ],

        // ── Estatísticas resumidas ─────────────────────────────────────────
        _SectionTitle(
            title: 'Estatísticas do desafio',
            icon: Icons.bar_chart_outlined),
        const SizedBox(height: 12),
        _StatsGrid(stats: stats, surface: surface, border: border),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Cabeçalho de celebração ───────────────────────────────────────────────────

class _CelebrationHeader extends StatelessWidget {
  final ClubChallenge challenge;

  const _CelebrationHeader({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 52, color: AppColors.warmGold),
          const SizedBox(height: 12),
          Text(
            challenge.title,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.onSurface,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${fmt.format(challenge.startsAt)} – ${fmt.format(challenge.endsAt)}',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Desafio encerrado',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pódio ─────────────────────────────────────────────────────────────────────

class _PodiumRow extends StatelessWidget {
  final List<dynamic> podium;
  final Color surface;
  final Color border;

  const _PodiumRow(
      {required this.podium, required this.surface, required this.border});

  @override
  Widget build(BuildContext context) {
    // Reordena para mostrar 2o, 1o, 3o (visual clássico de pódio)
    final top3 = podium.take(3).toList();
    final ordered = <Map<String, dynamic>>[];
    if (top3.length >= 2) ordered.add(top3[1] as Map<String, dynamic>);
    if (top3.isNotEmpty) ordered.add(top3[0] as Map<String, dynamic>);
    if (top3.length >= 3) ordered.add(top3[2] as Map<String, dynamic>);

    final medals = [Icons.looks_two_outlined, Icons.looks_one_outlined, Icons.looks_3_outlined];
    final heights = [80.0, 100.0, 60.0];
    final colors = [
      AppColors.textMuted,
      AppColors.warmGold,
      AppColors.warmGoldLight,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: ordered.asMap().entries.map((e) {
        final idx = e.key;
        final entry = e.value;
        final name = entry['user_name'] as String? ?? 'Anônimo';
        final avatarUrl = entry['avatar_url'] as String?;
        final val = (entry['current_value'] as num?)?.toInt() ?? 0;

        return Expanded(
          child: Column(
            children: [
              MiniAvatar(url: avatarUrl, name: name, radius: 22),
              const SizedBox(height: 6),
              Text(
                name,
                style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                height: heights[idx],
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors[idx].withValues(alpha: 0.15),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: colors[idx].withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(medals[idx], color: colors[idx], size: 20),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.compact(locale: 'pt_BR').format(val),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors[idx],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Grid de estatísticas ──────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Color surface;
  final Color border;

  const _StatsGrid(
      {required this.stats, required this.surface, required this.border});

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem(
        icon: Icons.person_outline,
        label: 'Participantes',
        value: '${stats['participants'] ?? '-'}',
        color: AppColors.warmGold,
      ),
      _StatItem(
        icon: Icons.check_circle_outline,
        label: 'Completaram',
        value: '${stats['completed'] ?? '-'}',
        color: AppColors.forestGreen,
      ),
      _StatItem(
        icon: Icons.auto_graph_outlined,
        label: 'Melhor streak',
        value: '${stats['best_streak'] ?? '-'} dias',
        color: AppColors.warmGold,
      ),
      _StatItem(
        icon: Icons.menu_book_outlined,
        label: 'Total lido',
        value: NumberFormat.compact(locale: 'pt_BR')
            .format(stats['total_value'] ?? 0),
        color: AppColors.forestGreen,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width: (MediaQuery.of(context).size.width - 50) / 2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: item.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: item.color,
                              )),
                          Text(item.label,
                              style: AppTextStyles.labelMedium
                                  .copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: cs.onSurface,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
