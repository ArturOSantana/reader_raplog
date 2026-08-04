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
          final daily   = d['daily'] as Map<String, dynamic>;
          final streak  = d['streak'] as int;
          final reading = d['reading'] as List<Book>;
          final goals   = d['goals'] as List<Goal>;

          final todayPages = (daily['total_pages'] as num?)?.toInt() ?? 0;

          final dailyMission = goals.cast<Goal?>().firstWhere(
            (g) => g!.type == GoalType.dailyPages || g.type == GoalType.dailyMinutes,
            orElse: () => null,
          );

          final currentBook   = reading.isNotEmpty ? reading.first : null;
          final otherBooks    = reading.length > 1 ? reading.sublist(1, reading.length > 4 ? 4 : reading.length) : <Book>[];

          return RefreshIndicator(
            color: isDark ? ReadLogColors.readLight : ReadLogColors.read,
            backgroundColor: bg,
            onRefresh: () async {
              ref.invalidate(_homeDataProvider);
              ref.invalidate(_homeFriendsPresenceProvider);
              await ref.read(_homeDataProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                // ── Header com saudação ────────────────────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: _HomeHeader(
                      greeting: greeting,
                      userName: userName,
                      streak: streak,
                      ref: ref,
                    ),
                  ),
                ),

                // ── Banner de sessão ativa ─────────────────────────────
                const SliverToBoxAdapter(child: _ActiveSessionBanner()),

                // ── Hero: livro principal ──────────────────────────────
                if (currentBook != null)
                  SliverToBoxAdapter(
                    child: _CurrentBookHero(
                      book: currentBook,
                      todayPages: todayPages,
                      mission: dailyMission,
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: _EmptyState(),
                    ),
                  ),

                // ── Clube: presença condicional ────────────────────────
                const SliverToBoxAdapter(child: _ClubPresenceRow()),

                // ── 1 linha de atividade social ───────────────────────
                const SliverToBoxAdapter(child: _SocialActivityRow()),

                // ── Outros livros na estante ───────────────────────────
                if (otherBooks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                      child: _SectionLabel(label: 'Também na estante'),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _ShelfRow(
                          book: otherBooks[i],
                          onTap: () => context.push('/library/book/${otherBooks[i].id}'),
                        ),
                      ),
                      childCount: otherBooks.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

}

// ── Header ────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final int streak;
  final WidgetRef ref;

  const _HomeHeader({
    required this.greeting,
    required this.userName,
    required this.streak,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final fg      = isDark ? ReadLogColors.inkInverse       : ReadLogColors.ink;
    final fgMut   = isDark ? ReadLogColors.inkMutedInverse  : ReadLogColors.inkMuted;
    final fgSec   = isDark ? ReadLogColors.inkSecondaryInverse : ReadLogColors.inkSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de topo
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: openAppDrawer,
                child: Icon(Icons.menu, size: 22, color: fgSec),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.notifications_outlined, size: 20, color: fgSec),
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

          const SizedBox(height: 24),

          // Saudação compacta
          Text(
            greeting,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: fgMut,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                userName,
                style: ReadLogType.bookTitle(
                  size: 30,
                  color: fg,
                  weight: FontWeight.w500,
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 10),
                Text(
                  'Sequência de $streak ${streak == 1 ? 'dia' : 'dias'}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 11,
                    color: fgMut,
                  ),
                ),
              ],
            ],
          ),
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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final fgBg     = isDark ? ReadLogColors.canvasVariant   : ReadLogColors.surfaceVariant;
    final fgBorder = isDark ? ReadLogColors.hairlineDark    : ReadLogColors.hairline;
    final fg       = isDark ? ReadLogColors.ink             : ReadLogColors.inkInverse;

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

// ── Hero do livro atual ────────────────────────────────────────────────────────

class _CurrentBookHero extends StatelessWidget {
  final Book book;
  final int todayPages;
  final Goal? mission;

  const _CurrentBookHero({
    required this.book,
    required this.todayPages,
    required this.mission,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final fg       = isDark ? ReadLogColors.inkInverse      : ReadLogColors.ink;
    final fgMut    = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final divColor = isDark ? ReadLogColors.hairlineDark    : ReadLogColors.hairline;
    final trackBg  = isDark ? ReadLogColors.canvasVariant   : ReadLogColors.surfaceSubtle;

    final progress = (book.totalPages != null && book.totalPages! > 0)
        ? ((book.currentPage ?? 0) / book.totalPages!).clamp(0.0, 1.0)
        : 0.0;

    final pct       = (progress * 100).round();
    final pageLabel = (book.currentPage != null && book.totalPages != null)
        ? 'pág. ${book.currentPage} de ${book.totalPages}'
        : '$pct%';

    // meta de hoje
    double? missionProgress;
    String? missionLabel;
    bool missionDone = false;
    if (mission != null) {
      final target  = mission!.targetValue.toInt();
      final current = mission!.type == GoalType.dailyPages ? todayPages : 0;
      missionProgress = (current / target).clamp(0.0, 1.0);
      missionDone     = current >= target;
      missionLabel    = missionDone
          ? 'Meta atingida'
          : '$current de $target ${mission!.type == GoalType.dailyPages ? 'páginas' : 'min'}';
    }

    return GestureDetector(
      onTap: () => context.push('/library/book/${book.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa hero + info
            _BookHeroBanner(book: book),

            const SizedBox(height: 14),

            // Barra de progresso do livro (preta)
            _ProgressTrack(
              value: progress,
              color: fg,
              trackColor: trackBg,
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pageLabel,
                    style: ReadLogType.mono(size: 10.5, color: fgMut)),
                Text('$pct%',
                    style: ReadLogType.mono(size: 10.5, color: fgMut)),
              ],
            ),

            // Meta do dia (verde) — só aparece se houver meta configurada
            if (missionProgress != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meta de hoje',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: fgMut,
                    ),
                  ),
                  Text(
                    missionLabel ?? '',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: missionDone ? ReadLogColors.read : fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ProgressTrack(
                value: missionProgress,
                color: ReadLogColors.read,
                trackColor: trackBg,
              ),
            ],

            const SizedBox(height: 20),

            // CTA "Continuar leitura"
            _ReadCTA(bookId: book.id),

            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: divColor),
          ],
        ),
      ),
    );
  }
}

class _BookHeroBanner extends StatelessWidget {
  final Book book;
  const _BookHeroBanner({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgHero  = isDark ? ReadLogColors.canvasElevated : const Color(0xFF3A322C);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LumenRadius.card),
        color: bgHero,
        image: book.coverUrl != null
            ? DecorationImage(
                image: NetworkImage(book.coverUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.45),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: ReadLogType.bookTitle(
              size: 20,
              color: const Color(0xFFFAF8F4),
              weight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (book.author != null) ...[
            const SizedBox(height: 4),
            Text(
              book.author!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: const Color(0xFFFAF8F4).withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double value;
  final Color color;
  final Color trackColor;

  const _ProgressTrack({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w   = constraints.maxWidth;
        final dot = 6.0;
        final pos = (w * value).clamp(dot / 2, w - dot / 2);

        return SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // trilho
              Positioned.fill(
                top: 5,
                bottom: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // preenchimento
              Positioned(
                left: 0,
                top: 5,
                bottom: 5,
                width: pos,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // ponto indicador
              Positioned(
                left: pos - dot / 2,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReadCTA extends StatelessWidget {
  final String bookId;
  const _ReadCTA({required this.bookId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ReadLogColors.inkInverse : ReadLogColors.ink;
    final fg     = isDark ? ReadLogColors.ink        : ReadLogColors.inkInverse;

    return GestureDetector(
      onTap: () => context.push('/session?bookId=$bookId'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LumenRadius.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          'Continuar leitura',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Presença do clube (condicional — só aparece se houver alguém lendo) ────────

class _ClubPresenceRow extends ConsumerWidget {
  const _ClubPresenceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(_homeFriendsPresenceProvider);

    return presenceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clubPresences) {
        // Conta total de membros online em todos os clubes
        final totalOnline = clubPresences.fold<int>(
          0,
          (sum, cp) => sum + cp.members.where((m) => m.isActive).length,
        );
        if (totalOnline == 0 || clubPresences.isEmpty) return const SizedBox.shrink();

        final clubName = clubPresences.first.club.name;
        final isDark   = Theme.of(context).brightness == Brightness.dark;
        final fgMut    = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(
            children: [
              _PresenceDot(
                isActive: true,
                color: ReadLogColors.read,
                activeColor: ReadLogColors.readLight,
              ),
              const SizedBox(width: 8),
              Text(
                '$clubName · $totalOnline ${totalOnline == 1 ? 'lendo agora' : 'lendo agora'}',
                style: ReadLogType.mono(size: 11, color: fgMut),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Linha de atividade social (1 amigo, mais recente) ────────────────────────

class _SocialActivityRow extends ConsumerWidget {
  const _SocialActivityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(_homeFriendsPresenceProvider);

    return presenceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clubPresences) {
        // Pega o membro mais recente que NÃO está ativamente lendo (tem elapsed)
        ClubPresenceMember? recent;
        for (final cp in clubPresences) {
          for (final m in cp.members) {
            if (!m.isActive) {
              recent = m;
              break;
            }
          }
          if (recent != null) break;
        }
        if (recent == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg     = isDark ? ReadLogColors.inkInverse      : ReadLogColors.ink;
        final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
        final divColor = isDark ? ReadLogColors.hairlineDark  : ReadLogColors.hairline;

        final name     = recent.userName ?? 'Alguém';
        final elapsed  = recent.presenceLabel;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: fgMut,
                  ),
                  children: [
                    TextSpan(
                      text: name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    TextSpan(text: ' estava lendo · $elapsed'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(height: 1, thickness: 1, color: divColor),
            ],
          ),
        );
      },
    );
  }
}

// ── Linha de livro na estante ─────────────────────────────────────────────────

class _ShelfRow extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ShelfRow({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? ReadLogColors.inkInverse      : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;
    final bgCover = isDark ? ReadLogColors.canvasVariant  : ReadLogColors.surfaceSubtle;
    final divColor = isDark ? ReadLogColors.hairlineDark  : ReadLogColors.hairline;

    final progress = (book.totalPages != null && book.totalPages! > 0)
        ? ((book.currentPage ?? 0) / book.totalPages!).clamp(0.0, 1.0)
        : 0.0;
    final pct = (progress * 100).round();
    final pctLabel = pct > 0 ? '$pct%' : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: divColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Miniatura da capa
            Container(
              width: 30,
              height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: bgCover,
                image: book.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(book.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),

            // Título e autor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: ReadLogType.bookTitle(size: 14, color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.author != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: fgMut,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Percentual
            Text(
              pctLabel,
              style: ReadLogType.mono(size: 10.5, color: fgMut),
            ),
          ],
        ),
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
class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider);
    if (!session.hasActiveSession) return const SizedBox.shrink();

    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final bg            = isDark ? ReadLogColors.canvasVariant : ReadLogColors.surfaceVariant;
    final dotColor      = session.isPaused ? ReadLogColors.idle : ReadLogColors.read;
    final dotColorLight = session.isPaused ? ReadLogColors.idle : ReadLogColors.readLight;

    final elapsed  = session.elapsedSeconds;
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;
    final s = elapsed % 60;
    final timeStr = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final statusLabel = session.isPaused ? 'pausada' : 'em leitura';
    final fg     = isDark ? ReadLogColors.ink : ReadLogColors.ink;
    final fgMut  = isDark ? ReadLogColors.inkMutedInverse : ReadLogColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
              color: session.isPaused ? ReadLogColors.idle : ReadLogColors.read,
            ),
          ),
          child: Row(
            children: [
              _PresenceDot(
                isActive: !session.isPaused,
                color: dotColor,
                activeColor: dotColorLight,
              ),
              const SizedBox(width: 12),
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
                        color: session.isPaused
                            ? ReadLogColors.idle
                            : (isDark ? ReadLogColors.readLight : ReadLogColors.read),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeStr,
                style: ReadLogType.mono(
                  size: 15,
                  weight: FontWeight.w500,
                  color: session.isPaused
                      ? fgMut
                      : (isDark ? ReadLogColors.readLight : ReadLogColors.read),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: fgMut),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ponto de presença: pulsa quando ativo.
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
        width: 6,
        height: 6,
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
                color: isDark ? ReadLogColors.readLight : ReadLogColors.read,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
