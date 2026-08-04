import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_presence_stats.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/skel_shimmer.dart';
import '../../../../core/widgets/widget_manager.dart';
import '../../../../core/shell/main_shell.dart' show openAppDrawer;
import '../../../session/presentation/notifiers/session_notifier.dart';

// ── Provider principal da home ────────────────────────────────────────────────

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
  final streak  = (results[1] as num?)?.toInt() ?? 0;
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

// ── Presença de amigos ────────────────────────────────────────────────────────

class _ClubPresence {
  final BookClub club;
  final List<ClubPresenceMember> members;
  const _ClubPresence({required this.club, required this.members});
}

final _homeFriendsPresenceProvider =
    FutureProvider<List<_ClubPresence>>((ref) async {
  final repo  = ref.watch(bookClubRepositoryProvider);
  final clubs = await repo.listMyClubs();
  final active = clubs.where((c) => c.status == ClubStatus.active).toList();

  final results = await Future.wait(
    active.map((c) async {
      try {
        final members = await repo.fetchPresence(c.id);
        return _ClubPresence(club: c, members: members);
      } catch (_) {
        return _ClubPresence(club: c, members: []);
      }
    }),
  );

  return results.where((cp) => cp.members.isNotEmpty).toList();
});

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshTriggerProvider);
    final data = ref.watch(_homeDataProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';

    final now  = DateTime.now();
    final weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final months   = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    final dateLabel = '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';

    final currentUser = ref.watch(currentUserProvider);
    final fullName    = currentUser?.userMetadata?['full_name'] as String?;
    final userName    = (fullName?.trim().split(' ').first) ??
        currentUser?.email?.split('@').first ??
        'Leitor';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvas   : ReadLogColors.surface;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Scaffold(
      backgroundColor: bg,
      body: data.when(
        loading: () => const SkelScreenList(count: 4),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Erro ao carregar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: fgMut,
              ),
            ),
          ),
        ),
        data: (d) {
          final daily      = d['daily'] as Map<String, dynamic>;
          final streak     = d['streak'] as int;
          final reading    = d['reading'] as List<Book>;
          final goals      = d['goals'] as List<Goal>;

          final todayMinutes = (daily['total_minutes'] as num?)?.toInt() ?? 0;
          final todayPages   = (daily['total_pages']   as num?)?.toInt() ?? 0;

          final dailyGoals = goals
              .where((g) =>
                  g.type == GoalType.dailyMinutes ||
                  g.type == GoalType.dailyPages)
              .toList();

          final dailyMission = dailyGoals.cast<Goal?>().firstWhere(
                (g) => g!.type == GoalType.dailyMinutes,
                orElse: () => dailyGoals.cast<Goal?>().firstWhere(
                      (g) => g!.type == GoalType.dailyPages,
                      orElse: () => null,
                    ),
              );

          return RefreshIndicator(
            color: isDark ? ReadLogColors.progressLight : ReadLogColors.progress,
            backgroundColor: bg,
            onRefresh: () async {
              ref.invalidate(_homeDataProvider);
              ref.invalidate(_homeFriendsPresenceProvider);
              await ref.read(_homeDataProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: _HomeHeader(
                      dateLabel: dateLabel,
                      greeting: greeting,
                      userName: userName,
                    ),
                  ),
                ),

                // ── Sessão ativa ───────────────────────────────────────
                const SliverToBoxAdapter(child: _ActiveSessionBanner()),

                // ── Progresso do dia ───────────────────────────────────
                if (streak > 0 || todayMinutes > 0 || todayPages > 0)
                  SliverToBoxAdapter(
                    child: _DailyProgress(
                      streak: streak,
                      todayMinutes: todayMinutes,
                      todayPages: todayPages,
                      mission: dailyMission,
                    ),
                  ),

                // ── Amigos lendo agora ─────────────────────────────────
                SliverToBoxAdapter(child: _HomeFriendsPresence()),

                // ── Lendo agora ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                    child: _SectionLabel(
                      label: reading.isEmpty ? 'BIBLIOTECA' : 'LENDO AGORA',
                    ),
                  ),
                ),

                if (reading.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: _EmptyState(),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ReadLogCatalogCard(
                          title: reading[i].title,
                          author: reading[i].author ?? '',
                          progress: _progress(reading[i]),
                          currentPage: reading[i].currentPage,
                          totalPages: reading[i].totalPages,
                          coverUrl: reading[i].coverUrl,
                          onTap: () =>
                              context.push('/library/book/${reading[i].id}'),
                        ),
                      ),
                      childCount: reading.length > 3 ? 3 : reading.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _progress(Book b) {
    if (b.totalPages == null || b.totalPages == 0) return 0;
    return ((b.currentPage ?? 0) / b.totalPages!).clamp(0.0, 1.0);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HomeHeader extends ConsumerWidget {
  final String dateLabel;
  final String greeting;
  final String userName;

  const _HomeHeader({
    required this.dateLabel,
    required this.greeting,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.canvas      : ReadLogColors.surface;
    final fg     = isDark ? ReadLogColors.inkInverse  : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final fgSec  = isDark ? ReadLogColors.inkSecondaryInverse : ReadLogColors.inkSecondary;
    final divColor = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de topo: menu / data / notificações / avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: openAppDrawer,
                child: Icon(Icons.menu, size: 22, color: fgSec),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: fgMut,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    size: 20, color: fgSec),
                onPressed: () => context.push('/notifications'),
                tooltip: 'Notificações',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              _UserAvatar(ref: ref),
            ],
          ),

          const SizedBox(height: 28),

          // Saudação — tipografia protagonista
          Text(
            greeting,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: fgMut,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            userName,
            style: ReadLogType.bookTitle(size: 32, color: fg, weight: FontWeight.w500),
          ),

          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: divColor),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final WidgetRef ref;
  const _UserAvatar({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgBg = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final fgBorder = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;
    final fg = isDark ? ReadLogColors.ink : ReadLogColors.inkInverse;

    final user     = ref.watch(currentUserProvider);
    final fullName = user?.userMetadata?['full_name'] as String?;
    final email    = user?.email ?? '';
    final name     = fullName ?? email;
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fgBg,
          shape: BoxShape.circle,
          border: Border.all(color: fgBorder, width: 1),
        ),
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Progresso diário ──────────────────────────────────────────────────────────

class _DailyProgress extends StatelessWidget {
  final int streak;
  final int todayMinutes;
  final int todayPages;
  final Goal? mission;

  const _DailyProgress({
    required this.streak,
    required this.todayMinutes,
    required this.todayPages,
    required this.mission,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final bgProgress = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final divColor = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;

    // Métricas do dia
    final hours = todayMinutes ~/ 60;
    final mins  = todayMinutes % 60;
    final timeLabel = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

    // Progresso da meta (se tiver)
    double? missionProgress;
    bool missionDone = false;
    if (mission != null) {
      final current = mission!.type == GoalType.dailyMinutes
          ? todayMinutes
          : todayPages;
      missionProgress = (current / mission!.targetValue).clamp(0.0, 1.0);
      missionDone = current >= mission!.targetValue;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de métricas
          Row(
            children: [
              _MetricItem(
                value: streak > 0 ? '$streak' : '–',
                unit: streak == 1 ? 'dia' : 'dias',
                label: 'Sequência',
                accent: streak > 0
                    ? (isDark ? ReadLogColors.progressLight : ReadLogColors.progress)
                    : null,
              ),
              const SizedBox(width: 32),
              _MetricItem(
                value: timeLabel,
                unit: '',
                label: 'Hoje',
              ),
              const SizedBox(width: 32),
              _MetricItem(
                value: '$todayPages',
                unit: 'pág.',
                label: 'Páginas',
              ),
            ],
          ),

          // Meta do dia
          if (missionProgress != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: missionProgress,
                      minHeight: 2,
                      backgroundColor: bgProgress,
                      color: missionDone
                          ? ReadLogColors.success
                          : (isDark ? ReadLogColors.progressLight : ReadLogColors.progress),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  missionDone ? 'Meta atingida' : '${(missionProgress * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: missionDone
                        ? ReadLogColors.success
                        : fgMut,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: divColor),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color? accent;

  const _MetricItem({
    required this.value,
    required this.unit,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? ReadLogColors.inkInverse  : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final valueColor = accent ?? fg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: ReadLogType.mono(
                size: 20,
                weight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: fgMut,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: fgMut,
          ),
        ),
      ],
    );
  }
}

// ── Presença de amigos ────────────────────────────────────────────────────────

class _HomeFriendsPresence extends ConsumerWidget {
  const _HomeFriendsPresence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(_homeFriendsPresenceProvider);

    return presenceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clubPresences) {
        final seen = <String>{};
        final all  = <({ClubPresenceMember member, String clubName})>[];
        for (final cp in clubPresences) {
          for (final m in cp.members) {
            if (seen.add(m.userId)) {
              all.add((member: m, clubName: cp.club.name));
            }
          }
        }
        if (all.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final divColor = isDark ? ReadLogColors.hairlineDark : ReadLogColors.hairline;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label: 'LENDO AGORA'),
              const SizedBox(height: 16),
              ...all.take(4).map((e) => _FriendRow(
                    member: e.member,
                    clubName: e.clubName,
                  )),
              Divider(height: 1, thickness: 1, color: divColor),
            ],
          ),
        );
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  final ClubPresenceMember member;
  final String clubName;

  const _FriendRow({required this.member, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final bgAvatar = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final fgAvatar = isDark ? ReadLogColors.inkSecondaryInverse : ReadLogColors.inkSecondary;
    final dotColor = member.isActive
        ? ReadLogColors.progress
        : ReadLogColors.idle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Indicador de presença
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),

          // Avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bgAvatar,
              shape: BoxShape.circle,
            ),
            child: member.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      member.avatarUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      (member.userName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fgAvatar,
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              member.userName ?? 'Leitor',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: fg,
              ),
            ),
          ),

          Text(
            member.isActive ? 'lendo agora' : member.presenceLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: member.isActive
                  ? (isDark ? ReadLogColors.progressLight : ReadLogColors.progress)
                  : fgMut,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rótulo de seção ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Text(
      label,
      style: ReadLogType.kicker(size: 10, color: fgMut),
    );
  }
}

// ── Banner de sessão ativa ────────────────────────────────────────────────────

/// Aparece na home SOMENTE quando há uma sessão de leitura em andamento.
/// Pulsa enquanto a sessão está rodando; exibe "pausada" quando pausada.
class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider);
    if (!session.hasActiveSession) return const SizedBox.shrink();

    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bg          = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final dotColor    = session.isPaused ? ReadLogColors.idle : ReadLogColors.read;
    final dotColorLight = session.isPaused ? ReadLogColors.idle : ReadLogColors.readLight;

    final elapsed     = session.elapsedSeconds;
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;
    final s = elapsed % 60;
    final timeStr = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final statusLabel = session.isPaused ? 'pausada' : 'em leitura';
    final fg     = isDark ? ReadLogColors.inkInverse  : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: () {
          final bookId = session.session?.bookId;
          if (bookId != null) {
            context.push('/session?bookId=$bookId');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: session.isPaused
                  ? ReadLogColors.idle
                  : ReadLogColors.read,
            ),
          ),
          child: Row(
            children: [
              // Dot pulsante (usa AnimatedContainer para brilhar)
              _PresenceDot(isActive: !session.isPaused, color: dotColor, activeColor: dotColorLight),

              const SizedBox(width: 12),

              // Título e status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.bookTitle.isNotEmpty ? session.bookTitle : 'Leitura',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: session.isPaused ? ReadLogColors.idle : (isDark ? ReadLogColors.readLight : ReadLogColors.read),
                      ),
                    ),
                  ],
                ),
              ),

              // Timer
              Text(
                timeStr,
                style: ReadLogType.mono(
                  size: 15,
                  weight: FontWeight.w500,
                  color: session.isPaused ? fgMut : (isDark ? ReadLogColors.readLight : ReadLogColors.read),
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: fgMut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ponto de presença: pulsa quando ativo (simula um LED aceso).
class _PresenceDot extends StatefulWidget {
  final bool isActive;
  final Color color;
  final Color activeColor;
  const _PresenceDot({required this.isActive, required this.color, required this.activeColor});

  @override
  State<_PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<_PresenceDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PresenceDot old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0.5;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isActive
              ? Color.lerp(widget.color, widget.activeColor, _anim.value)
              : widget.color,
        ),
      ),
    );
  }
}

// ── Estado vazio ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? ReadLogColors.inkInverse  : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nenhum livro\nem leitura.',
            style: ReadLogType.bookTitle(size: 24, color: fg),
          ),
          const SizedBox(height: 12),
          Text(
            'Adicione um livro para começar\na registrar sua leitura.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.6,
              color: fgMut,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => GoRouter.of(context).go('/library/add'),
            child: Text(
              'Adicionar livro →',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? ReadLogColors.progressLight : ReadLogColors.progress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
