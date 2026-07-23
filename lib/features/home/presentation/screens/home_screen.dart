import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/readlog_theme.dart';
import '../../../../theme/readlog_components.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../../core/widgets/widget_manager.dart';
import '../../../../core/shell/main_shell.dart';

final _homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo    = ref.watch(bookRepositoryProvider);
  final goalRepo    = ref.watch(goalRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchDailyStats(),
    sessionRepo.fetchStreak(),
    bookRepo.fetchAll(status: BookStatus.reading),
    goalRepo.fetchAll(),
  ]);

  final daily   = results[0] as Map<String, dynamic>;
  final streak  = results[1] as int;
  final reading = results[2] as List<Book>;
  final goals   = results[3] as List<Goal>;

  final currentBook = reading.isNotEmpty ? reading.first : null;
  final dailyGoalObj = goals.cast<Goal?>().firstWhere(
    (g) => g!.type == GoalType.dailyPages || g.type == GoalType.dailyMinutes,
    orElse: () => null,
  );
  final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;

  unawaited(WidgetManager.updateAll(
    bookTitle: currentBook?.title,
    bookAuthor: currentBook?.author,
    currentPage: currentBook?.currentPage ?? 0,
    totalPages: currentBook?.totalPages ?? 0,
    streak: streak,
    streakRecord: streak,
    dailyGoal: todayPages,
    dailyGoalTarget: dailyGoalObj?.targetValue,
  ));

  return {
    'daily': daily,
    'streak': streak,
    'reading': reading,
    'goals': goals,
  };
});

final homeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Agrega os stories de todos os clubes do usuário em uma única lista
/// para popular o ReadLogStoryStrip da home.
final _homeStoriesProvider =
    FutureProvider<List<_ClubStoryCount>>((ref) async {
  final repo = ref.watch(bookClubRepositoryProvider);
  final clubs = await repo.listMyClubs();

  // Filtra apenas clubes ativos
  final activeClubs =
      clubs.where((c) => c.status == ClubStatus.active).toList();

  final counts = await Future.wait(
    activeClubs.map((c) async {
      try {
        final stories = await repo.listStories(c.id);
        return _ClubStoryCount(club: c, count: stories.length);
      } catch (_) {
        return _ClubStoryCount(club: c, count: 0);
      }
    }),
  );

  return counts;
});

class _ClubStoryCount {
  final BookClub club;
  final int count;
  const _ClubStoryCount({required this.club, required this.count});
}

/// Strip de stories da home: item "VOCÊ" (criar story) + um item por clube ativo.
class _HomeStoryStrip extends ConsumerWidget {
  const _HomeStoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(_homeStoriesProvider);

    return storiesAsync.when(
      // Mostra apenas o botão "VOCÊ" enquanto carrega
      loading: () => ReadLogStoryStrip(
        items: const [ReadLogStoryItem(label: 'VOCÊ', isSelf: true)],
      ),
      // Em caso de erro, idem (degradação graciosa)
      error: (_, __) => ReadLogStoryStrip(
        items: const [ReadLogStoryItem(label: 'VOCÊ', isSelf: true)],
      ),
      data: (clubCounts) {
        // Clubes sem stories também aparecem (count = 0), para o usuário
        // poder navegar e publicar. Ordena: com stories primeiro.
        final sorted = [...clubCounts]
          ..sort((a, b) => b.count.compareTo(a.count));

        final items = <ReadLogStoryItem>[
          const ReadLogStoryItem(label: 'VOCÊ', isSelf: true),
          ...sorted.map(
            (cs) => ReadLogStoryItem(
              label: cs.club.name,
              clubId: cs.club.id,
              storyCount: cs.count,
              // Considera "visto" quando não há stories ativos
              seen: cs.count == 0,
            ),
          ),
        ];

        return ReadLogStoryStrip(
          items: items,
          onAddStory: () {
            // "VOCÊ": se só há um clube ativo, vai direto; senão mostra picker
            if (sorted.isEmpty) return;
            if (sorted.length == 1) {
              context.push(
                '/clubs/${sorted.first.club.id}/stories',
                extra: {'clubName': sorted.first.club.name},
              );
            } else {
              _showClubPicker(context, sorted);
            }
          },
          onStoryTap: (index) {
            // index 0 = "VOCÊ" (tratado pelo onAddStory); index >= 1 = clubes
            final clubIndex = index - 1;
            if (clubIndex < 0 || clubIndex >= sorted.length) return;
            final cs = sorted[clubIndex];
            context.push(
              '/clubs/${cs.club.id}/stories',
              extra: {'clubName': cs.club.name},
            );
          },
        );
      },
    );
  }

  void _showClubPicker(
      BuildContext context, List<_ClubStoryCount> clubs) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Publicar story em qual clube?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...clubs.map(
              (cs) => ListTile(
                title: Text(cs.club.name),
                subtitle: cs.count > 0
                    ? Text('${cs.count} story(s) ativos')
                    : const Text('Nenhum story ainda'),
                leading: const Icon(Icons.groups_outlined),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push(
                    '/clubs/${cs.club.id}/stories',
                    extra: {'clubName': cs.club.name},
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshTriggerProvider);
    final data = ref.watch(_homeDataProvider);

    // Saudação por hora do dia
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';

    // Kicker: dia da semana + data
    final now = DateTime.now();
    final weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final months   = ['JAN','FEV','MAR','ABR','MAI','JUN','JUL','AGO','SET','OUT','NOV','DEZ'];
    final kicker = '${weekdays[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';

    // Nome do usuário (virá de provider quando disponível)
    const userName = 'Artur';

    return Scaffold(
      backgroundColor: ReadLogColors.ink,
      body: data.when(
        loading: () => const SkelScreenList(count: 5),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: ReadLogType.mono(color: ReadLogColors.cream)),
        ),
        data: (d) {
          final daily      = d['daily'] as Map<String, dynamic>;
          final streak     = d['streak'] as int;
          final reading    = d['reading'] as List<Book>;
          final goals      = d['goals'] as List<Goal>;

          final todayMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages   = (daily['total_pages'] as num?)?.toInt() ?? 0;

          final dailyGoals = goals
              .where((g) =>
                  g.type == GoalType.dailyMinutes ||
                  g.type == GoalType.dailyPages)
              .toList();

          return RefreshIndicator(
            color: ReadLogColors.brass,
            onRefresh: () async {
              ref.invalidate(_homeDataProvider);
              await ref.read(_homeDataProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                // ── PageHeader ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: _HomeHeader(
                      kicker: kicker,
                      greeting: '$greeting, $userName',
                    ),
                  ),
                ),

                // ── Story Strip ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'STORIES DE LEITURA',
                            style: ReadLogType.mono(
                              size: 10,
                              color: ReadLogColors.cream.withValues(alpha: 0.55),
                            ).copyWith(letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _HomeStoryStrip(),
                      ],
                    ),
                  ),
                ),

                // ── Bloco "SUA LEITURA" ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _SectionKicker(label: 'SUA LEITURA'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _ReadingStatsGrid(
                      streak: streak,
                      todayMinutes: todayMinutes,
                      todayPages: todayPages,
                      goals: dailyGoals,
                    ),
                  ),
                ),

                // ── Bloco "LENDO AGORA" ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _SectionKicker(label: 'LENDO AGORA'),
                  ),
                ),
                if (reading.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _EmptyReadingCard(),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ReadLogCatalogCard(
                          title: reading[i].title,
                          author: reading[i].author ?? '',
                          progress: _progress(reading[i]),
                          tabColor: ReadLogColors.brass,
                          currentPage: reading[i].currentPage,
                          totalPages: reading[i].totalPages,
                          onTap: () =>
                              context.push('/library/book/${reading[i].id}'),
                        ),
                      ),
                      childCount: reading.length > 3 ? 3 : reading.length,
                    ),
                  ),

                // Espaço do rodapé
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _progress(Book b) {
    if (b.totalPages == null || b.totalPages == 0) return 0;
    final current = b.currentPage ?? 0;
    return (current / b.totalPages!).clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Header dark com kicker + título Fraunces + linha pontilhada + ícones de ação.
class _HomeHeader extends StatelessWidget {
  final String kicker;
  final String greeting;

  const _HomeHeader({required this.kicker, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ReadLogColors.ink,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Botão de menu sanduíche — abre o Drawer global
              IconButton(
                icon: const Icon(Icons.menu,
                    size: 20, color: ReadLogColors.cream),
                onPressed: openAppDrawer,
                tooltip: 'Menu',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  kicker,
                  style: ReadLogType.mono(
                    size: 10,
                    color: ReadLogColors.brass,
                  ).copyWith(letterSpacing: 2),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    size: 20, color: ReadLogColors.cream),
                onPressed: () => context.push('/notifications'),
                tooltip: 'Notificações',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: ReadLogColors.brass,
                    shape: BoxShape.circle,
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(currentUserProvider);
                      final fullName =
                          user?.userMetadata?['full_name'] as String?;
                      final email = user?.email ?? '';
                      final name = fullName ?? email;
                      final initials = name.trim().split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2).join().toUpperCase();
                      return Text(
                        initials.isEmpty ? '?' : initials,
                        style: ReadLogType.mono(
                          size: 12,
                          weight: FontWeight.w600,
                          color: ReadLogColors.charcoal,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            greeting,
            style: ReadLogType.display(size: 24, color: ReadLogColors.cream),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 1,
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DottedLine(color: ReadLogColors.inkLine),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends CustomPainter {
  final Color color;
  const _DottedLine({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const w = 2.0, sp = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + w, 0), p);
      x += w + sp;
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}

/// Kicker de seção: texto uppercase mono em cream 55%.
class _SectionKicker extends StatelessWidget {
  final String label;
  const _SectionKicker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ReadLogType.mono(
            size: 10,
            color: ReadLogColors.cream.withValues(alpha: 0.55),
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 1,
            child: CustomPaint(
              painter: _DottedLine(
                  color: ReadLogColors.cream.withValues(alpha: 0.15)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid 2×2 de métricas de leitura + carimbo de streak lateral.
class _ReadingStatsGrid extends StatelessWidget {
  final int streak;
  final int todayMinutes;
  final int todayPages;
  final List<Goal> goals;

  const _ReadingStatsGrid({
    required this.streak,
    required this.todayMinutes,
    required this.todayPages,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final hours = todayMinutes ~/ 60;
    final mins  = todayMinutes % 60;
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    final dailyGoal = goals.cast<Goal?>().firstWhere(
      (g) => g!.type == GoalType.dailyMinutes || g.type == GoalType.dailyPages,
      orElse: () => null,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carimbo de streak
        ReadLogStamp(
          value: '$streak',
          label: streak == 1 ? 'dia' : 'dias',
          color: streak > 0 ? ReadLogColors.stamp : ReadLogColors.sage,
          size: 84,
        ),
        const SizedBox(width: 14),
        // Grid de stat tiles
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                        label: 'HOJE', value: timeLabel, sub: 'lidos'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                        label: 'PÁGINAS', value: '$todayPages', sub: 'hoje'),
                  ),
                ],
              ),
              if (dailyGoal != null) ...[
                const SizedBox(height: 8),
                _GoalTile(goal: dailyGoal, todayMinutes: todayMinutes, todayPages: todayPages),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _StatTile(
      {required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ReadLogColors.inkAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: ReadLogColors.inkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: ReadLogType.mono(
                  size: 9,
                  color: ReadLogColors.cream.withValues(alpha: 0.5))
                  .copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: ReadLogType.mono(
                    size: 18,
                    weight: FontWeight.w700,
                    color: ReadLogColors.brassLight),
              ),
              const SizedBox(width: 3),
              Text(sub,
                  style: ReadLogType.mono(
                      size: 9,
                      color: ReadLogColors.cream.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final int todayMinutes;
  final int todayPages;

  const _GoalTile(
      {required this.goal,
      required this.todayMinutes,
      required this.todayPages});

  int get _current =>
      goal.type == GoalType.dailyMinutes ? todayMinutes : todayPages;

  @override
  Widget build(BuildContext context) {
    final current  = _current;
    final target   = goal.targetValue;
    final progress = (current / target).clamp(0.0, 1.0);
    final done     = current >= target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ReadLogColors.inkAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: done
              ? ReadLogColors.sage.withValues(alpha: 0.4)
              : ReadLogColors.inkLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'META DIÁRIA',
                style: ReadLogType.mono(
                    size: 9,
                    color: ReadLogColors.cream.withValues(alpha: 0.5))
                    .copyWith(letterSpacing: 1),
              ),
              Text(
                done ? '✓ Atingida!' : '$current / $target ${goal.type.unit}',
                style: ReadLogType.mono(
                  size: 10,
                  color: done
                      ? ReadLogColors.sage
                      : ReadLogColors.cream.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: ReadLogColors.cream.withValues(alpha: 0.1),
              color: done ? ReadLogColors.sage : ReadLogColors.brass,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ReadLogColors.inkAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: ReadLogColors.inkLine),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 40,
              color: ReadLogColors.cream.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            'Nenhum livro em leitura',
            style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.cream.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/library/add'),
            child: Text(
              'Adicionar livro',
              style: ReadLogType.mono(size: 12, color: ReadLogColors.brassLight),
            ),
          ),
        ],
      ),
    );
  }
}
