import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/models/club_bets_and_polls.dart';
import '../../../../shared/providers/providers.dart';
import '../../../library/data/book_search_result.dart';
import '../../../library/data/book_search_service.dart';
import '../widgets/club_activity_spotlight.dart';
import '../widgets/club_collective_stats_card.dart';
import '../widgets/club_presence_strip.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clubDetailProvider =
    FutureProvider.family<BookClub?, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchById(clubId);
});

final _clubMembersProvider =
    FutureProvider.family<List<ClubMember>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listMembers(clubId);
});

final _clubMeetingsProvider =
    FutureProvider.family<List<BookClubMeeting>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listMeetings(clubId);
});

final _clubHistoryProvider =
    FutureProvider.family<List<ClubBookHistory>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listBookHistory(clubId);
});

final _clubPollsProvider =
    FutureProvider.family<List<ClubBookPoll>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listPolls(clubId);
});

final _clubReadingNowProvider =
    FutureProvider.family<List<ClubReadingNowEntry>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchReadingNow(clubId);
});

final _clubReadingProgressProvider =
    FutureProvider.family<ClubReadingProgress?, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchReadingProgress(clubId);
});

final _clubHallOfFameProvider =
    FutureProvider.family<List<ClubHallOfFameEntry>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchHallOfFame(clubId);
});

final _clubChallengesProvider =
    FutureProvider.family<List<ClubChallenge>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listChallenges(clubId, activeOnly: false);
});

final _clubStreakProvider =
    FutureProvider.family<int, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).fetchClubStreak(clubId);
});

final _clubOpenPollsProvider =
    FutureProvider.family<List<ClubOpenPoll>, String>((ref, clubId) {
  return ref.watch(bookClubRepositoryProvider).listOpenPolls(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class BookClubDetailScreen extends ConsumerWidget {
  final String clubId;

  const BookClubDetailScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(_clubDetailProvider(clubId));

    return clubAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (club) {
        if (club == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Clube não encontrado.')),
          );
        }
        return _ClubDetailBody(club: club, clubId: clubId);
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ClubDetailBody extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  _ClubDetailBody({required this.club, required this.clubId});

  final _membersKey    = GlobalKey();
  final _challengesKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Invalida progresso e desafios quando sessão finaliza.
    ref.listen(clubSessionRefreshProvider, (_, __) {
      ref.invalidate(_clubReadingProgressProvider(clubId));
      ref.invalidate(_clubReadingNowProvider(clubId));
      ref.invalidate(_clubStreakProvider(clubId));
      ref.invalidate(_clubChallengesProvider(clubId));
    });

    final hasPollBadge =
        (ref.watch(_clubOpenPollsProvider(clubId)).valueOrNull ?? [])
            .where((p) => p.isOpen)
            .isNotEmpty;

    // Invalida presença e stats ao refrescar
    // (já invalidado no onRefresh abaixo via clubPresenceProvider)

    return Scaffold(
      backgroundColor: ReadLogColors.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_clubDetailProvider(clubId));
          ref.invalidate(_clubMembersProvider(clubId));
          ref.invalidate(_clubMeetingsProvider(clubId));
          ref.invalidate(_clubHistoryProvider(clubId));
          ref.invalidate(_clubPollsProvider(clubId));
          ref.invalidate(_clubReadingNowProvider(clubId));
          ref.invalidate(_clubReadingProgressProvider(clubId));
          ref.invalidate(_clubHallOfFameProvider(clubId));
          ref.invalidate(_clubChallengesProvider(clubId));
          ref.invalidate(_clubStreakProvider(clubId));
          ref.invalidate(_clubOpenPollsProvider(clubId));
          ref.invalidate(clubPresenceProvider(clubId));
          ref.invalidate(clubCollectiveStatsProvider(clubId));
          ref.invalidate(clubSocialHeatmapProvider(clubId));
        },
        child: CustomScrollView(
          slivers: [
            // ── Header expansível 220px ───────────────────────────────
            SliverToBoxAdapter(
              child: _ClubHeroHeader(
                club: club,
                onMenu: club.canManage
                    ? () => _showManageMenu(context, ref, club)
                    : null,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 28,
                bottom: MediaQuery.of(context).padding.bottom + 40,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // ── Status e convite ─────────────────────────────────────
            if (!club.isActive) ...[
              _StatusBanner(club: club),
              const Divider(height: 1),
              const SizedBox(height: 20),
            ],
            if (club.inviteCode != null && !club.isClosed) ...[
              _InviteCodeCard(
                  inviteCode: club.inviteCode!, clubName: club.name),
              const Divider(height: 1),
              const SizedBox(height: 28),
            ],

            // ════════════════════════════════════════════════════════
            // NÍVEL 1 — LIVRO ATUAL
            // ════════════════════════════════════════════════════════
            _CurrentBookCard(club: club),
            if (club.currentBookStatus == 'reading') ...[
              const SizedBox(height: 20),
              _ReadingProgressSection(clubId: clubId),
              const SizedBox(height: 16),
              _ReadingNowSection(clubId: clubId),
            ],
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),

            // ── Métricas coletivas ──────────────────────────────────
            ClubCollectiveStatsCard(clubId: clubId),
            const SizedBox(height: 8),
            ClubPresenceStrip(clubId: clubId),
            const SizedBox(height: 24),
            const Divider(height: 1, color: ReadLogColors.hairline),
            const SizedBox(height: 24),
            ClubActivitySpotlight(
              clubId: clubId,
              hasCurrentBook: club.currentBookStatus == 'reading',
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),

            // ════════════════════════════════════════════════════════
            // NÍVEL 2 — EXPLORAR
            // ════════════════════════════════════════════════════════
            _SectionLabel('Explorar'),
            const SizedBox(height: 4),
            _ExploreLink(
              label: 'Feed',
              onTap: () => context.push(
                '/clubs/$clubId/feed',
                extra: {'clubName': club.name},
              ),
            ),
            const Divider(height: 1),
            _ReadingRoomLink(
              clubId: clubId,
              clubName: club.name,
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: 'Desafios',
              onTap: () {
                final ctx = _challengesKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(ctx,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut);
                }
              },
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: hasPollBadge ? 'Votações ·' : 'Votações',
              onTap: () => context.push(
                '/clubs/$clubId/polls',
                extra: {
                  'clubName': club.name,
                  'canManage': club.canManage,
                },
              ),
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: 'Discussões',
              onTap: () => context.push(
                '/clubs/$clubId/discussions',
                extra: {
                  'clubName': club.name,
                  'canManage': club.canManage,
                },
              ),
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: 'Teorias',
              onTap: () => context.push(
                '/clubs/$clubId/theories',
                extra: {
                  'clubName': club.name,
                  'canManage': club.canManage,
                },
              ),
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: 'Calendário',
              onTap: () => context.push(
                '/clubs/$clubId/calendar',
                extra: {'clubName': club.name},
              ),
            ),
            const Divider(height: 1),
            _ExploreLink(
              label: 'Membros',
              onTap: () {
                final ctx = _membersKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(ctx,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut);
                }
              },
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),

            // ════════════════════════════════════════════════════════
            // NÍVEL 3 — MEMÓRIA DO CLUBE
            // ════════════════════════════════════════════════════════
            _SectionLabel('Memória do clube'),
            const SizedBox(height: 4),
            _MemoryAccordion(
              title: 'Hall da Fama, Linha do Tempo & Estatísticas',
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _HallOfFameSection(clubId: clubId),
                  const Divider(height: 24),
                  _TimelineButton(clubId: clubId, clubName: club.name),
                  const Divider(height: 1),
                  _StatsButton(clubId: clubId, clubName: club.name),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),

            // ════════════════════════════════════════════════════════
            // SEÇÕES SCROLL-DESTINO
            // ════════════════════════════════════════════════════════
            SizedBox(key: _membersKey, height: 0),
            _SectionLabel('Membros'),
            const SizedBox(height: 16),
            _MembersList(club: club, clubId: clubId),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 28),

            if (!club.isClosed) ...[
              SizedBox(key: _challengesKey, height: 0),
              _ChallengesSection(club: club, clubId: clubId),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 28),
            ],

            _SectionLabel('Histórico'),
            const SizedBox(height: 16),
            _BookHistoryList(clubId: clubId),
            const SizedBox(height: 36),

            // ── Ações do membro ──────────────────────────────────────
            if (club.isOwner && !club.isClosed)
              _LeaveAsOwnerButton(club: club, clubId: clubId),
            if (!club.isOwner && !club.isClosed)
              _LeaveButton(club: club, clubId: clubId),
            if (club.isOwner && club.canBeDeleted)
              _DeleteClubButton(club: club, clubId: clubId),
            const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe o menu de gerenciamento via bottom sheet simples
  void _showManageMenu(BuildContext context, WidgetRef ref, BookClub club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReadLogColors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildMenuItems(club).whereType<PopupMenuItem<String>>().map((item) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _onMenuSelected(context, ref, item.value!);
              },
              child: item.child ?? const SizedBox.shrink(),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BookClub club) {
    final items = <PopupMenuEntry<String>>[];

    if (!club.isClosed) {
      items.add(const PopupMenuItem(
        value: 'set_book',
        child: ListTile(
          leading: Icon(Icons.menu_book_outlined),
          title: Text('Definir livro atual'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
      items.add(const PopupMenuItem(
        value: 'add_meeting',
        child: ListTile(
          leading: Icon(Icons.event_outlined),
          title: Text('Agendar encontro'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
      items.add(const PopupMenuDivider());
    }

    if (club.isOwner && !club.isClosed) {
      items.add(const PopupMenuItem(
        value: 'edit_club',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar clube'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
      items.add(const PopupMenuDivider());
    }

    // Apenas o dono pode alterar status do clube (férias, reativar, encerrar)
    if (club.isOwner) {
      if (club.isActive) {
        items.add(const PopupMenuItem(
          value: 'vacation',
          child: ListTile(
            leading: Icon(Icons.beach_access_outlined),
            title: Text('Colocar em férias'),
            contentPadding: EdgeInsets.zero,
          ),
        ));
      }
      if (club.isOnVacation) {
        items.add(const PopupMenuItem(
          value: 'reactivate',
          child: ListTile(
            leading: Icon(Icons.play_circle_outline),
            title: Text('Reativar clube'),
            contentPadding: EdgeInsets.zero,
          ),
        ));
      }
      if (!club.isClosed) {
        items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem(
          value: 'close',
          child: ListTile(
            leading: Icon(Icons.lock_outline, color: AppColors.error),
            title: Text('Encerrar clube',
                style: TextStyle(color: AppColors.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ));
      }
    }

    return items;
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'set_book':
        _showSetBookSheet(context, ref);
        break;
      case 'add_meeting':
        _showAddMeetingSheet(context, ref);
        break;
      case 'edit_club':
        _showEditClubSheet(context, ref);
        break;
      case 'vacation':
        _confirmVacation(context, ref);
        break;
      case 'reactivate':
        _confirmReactivate(context, ref);
        break;
      case 'close':
        _confirmClose(context, ref);
        break;
    }
  }

  void _showEditClubSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditClubSheet(
        club: club,
        onSaved: () => ref.invalidate(_clubDetailProvider(clubId)),
      ),
    );
  }

  void _showSetBookSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SetBookSheet(
        club: club,
        clubId: clubId,
        onSaved: () {
          ref.invalidate(_clubDetailProvider(clubId));
          ref.invalidate(_clubHistoryProvider(clubId));
        },
      ),
    );
  }

  void _showAddMeetingSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddMeetingSheet(
        clubId: clubId,
        onSaved: () => ref.invalidate(_clubMeetingsProvider(clubId)),
      ),
    );
  }

  void _confirmVacation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Colocar em férias'),
        content: Text(
          'O clube "${club.name}" ficará em férias. '
          'Leituras e encontros serão pausados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookClubRepositoryProvider).setVacation(clubId);
              ref.invalidate(_clubDetailProvider(clubId));
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmReactivate(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reativar clube'),
        content: Text('Deseja reativar o clube "${club.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookClubRepositoryProvider).reactivate(clubId);
              ref.invalidate(_clubDetailProvider(clubId));
            },
            child: const Text('Reativar'),
          ),
        ],
      ),
    );
  }

  void _confirmClose(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encerrar clube'),
        content: Text(
          'Tem certeza que deseja encerrar "${club.name}"?\n\n'
          'O clube ficará somente para consulta. '
          'Após 30 dias você poderá excluí-lo definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookClubRepositoryProvider).closeClub(clubId);
              ref.invalidate(_clubDetailProvider(clubId));
            },
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final BookClub club;

  const _StatusBanner({required this.club});

  @override
  Widget build(BuildContext context) {
    final msg = club.isOnVacation
        ? 'Clube em férias — leituras e encontros pausados.'
        : 'Clube encerrado — apenas consulta disponível.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        msg,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: ReadLogColors.inkMuted,
        ),
      ),
    );
  }
}

// ── ExploreLink ───────────────────────────────────────────────────────────────

class _ExploreLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExploreLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: ReadLogColors.ink,
                ),
              ),
            ),
            LumenIcon('chevron', size: 16, color: ReadLogColors.inkGhost),
          ],
        ),
      ),
    );
  }
}

// ── ReadingRoomLink — Sala de leitura com counter ao vivo ─────────────────────

class _ReadingRoomLink extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const _ReadingRoomLink({required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowAsync = ref.watch(_clubReadingNowProvider(clubId));
    final count = nowAsync.valueOrNull?.length ?? 0;

    final label = count > 0 ? 'Sala de leitura · $count agora' : 'Sala de leitura';

    return _ExploreLink(
      label: label,
      onTap: () => context.push(
        '/clubs/$clubId/reading-room',
        extra: {'clubName': clubName},
      ),
    );
  }
}

// ── Invite Code Card ──────────────────────────────────────────────────────────

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  final String clubName;

  const _InviteCodeCard(
      {required this.inviteCode, required this.clubName});

  String get _inviteLink => 'https://readlog.app/join/$inviteCode';

  @override
  Widget build(BuildContext context) {
    // field-line: sem fundo, sem borda — label à esquerda, código à direita
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Código de convite',
                    style: ReadLogType.kicker(size: 10, color: ReadLogColors.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inviteCode.toUpperCase(),
                    style: ReadLogType.mono(
                      size: 16,
                      color: ReadLogColors.ink,
                      weight: FontWeight.w600,
                    ).copyWith(letterSpacing: 2.0),
                  ),
              ],
            ),
          ),
          // Copiar
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado!')),
              );
            },
            child: Icon(
              Icons.copy_outlined,
              size: 16,
              color: ReadLogColors.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          // Compartilhar
          GestureDetector(
            onTap: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Venha ler comigo no clube "$clubName" no Readlog! 📚\n'
                      'Use o código **$inviteCode** ou acesse:\n$_inviteLink',
                  subject: 'Convite para o clube $clubName',
                ),
              );
            },
            child: Icon(
              Icons.share_outlined,
              size: 16,
              color: ReadLogColors.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Club Hero Header (substitui _ClubHeader) ─────────────────────────────────
// Header expansível 220px com fundo ink 85% + overlay + chips do clube

class _ClubHeroHeader extends ConsumerWidget {
  final BookClub club;
  final VoidCallback? onMenu;

  const _ClubHeroHeader({required this.club, this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(_clubStreakProvider(club.id));
    final streak = streakAsync.valueOrNull ?? 0;

    final statusLabel = club.isClosed
        ? 'ENCERRADO'
        : club.isOnVacation
            ? 'FÉRIAS'
            : 'ATIVO';

    final roleLabel = club.isOwner
        ? 'DONO'
        : club.isAdmin
            ? 'ADMIN'
            : 'MEMBRO';

    return Container(
      height: 220,
      width: double.infinity,
      color: ReadLogColors.ink,
      child: Stack(
        children: [
          // Overlay escuro
          Container(color: ReadLogColors.ink.withValues(alpha: 0.85)),

          // Conteúdo
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha de navegação
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: LumenIcon('chevron',
                            size: 20, color: ReadLogColors.inkInverse),
                      ),
                      const Spacer(),
                      if (onMenu != null)
                        GestureDetector(
                          onTap: onMenu,
                          child: const Icon(Icons.more_horiz,
                              size: 20, color: ReadLogColors.inkInverse),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Kicker — verde-musgo sobre fundo escuro (accent do sistema)
                  Text(
                    'CLUBE · ${club.inviteCode?.toUpperCase() ?? club.id.substring(0, 6).toUpperCase()}',
                    style: ReadLogType.mono(
                      size: 10,
                      color: ReadLogColors.progress,
                    ).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),

                  // Nome do clube
                  Text(
                    club.name,
                    style: ReadLogType.display(
                        size: 22, color: ReadLogColors.inkInverse),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Metadados do clube em texto corrido — sem chips com borda
                  Text(
                    [
                      roleLabel.toLowerCase(),
                      statusLabel.toLowerCase(),
                      '${club.memberCount} membros',
                      if (streak > 0) '$streak dias',
                    ].join(' · '),
                    style: ReadLogType.mono(
                      size: 10,
                      color: ReadLogColors.inkInverse.withValues(alpha: 0.55),
                    ).copyWith(letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── (HeroChip removida — metadados agora são texto corrido) ───────────────────


// ── Current Book Card ─────────────────────────────────────────────────────────

class _CurrentBookCard extends ConsumerStatefulWidget {
  final BookClub club;

  const _CurrentBookCard({required this.club});

  @override
  ConsumerState<_CurrentBookCard> createState() => _CurrentBookCardState();
}

class _CurrentBookCardState extends ConsumerState<_CurrentBookCard> {
  bool _addingToLibrary = false;

  Future<void> _addToLibrary() async {
    final club = widget.club;
    if (club.currentBookTitle == null) return;
    setState(() => _addingToLibrary = true);
    try {
      // Verifica se o livro deste clube já está na biblioteca
      final existing = await ref
          .read(bookRepositoryProvider)
          .fetchBySourceClub(club.id);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${club.currentBookTitle}" já está na sua biblioteca.',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(bookRepositoryProvider).insert({
        'title': club.currentBookTitle,
        'author': club.currentBookAuthor,
        'status': 'reading',
        'source_club_id': club.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${club.currentBookTitle}" adicionado à sua biblioteca!',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao adicionar à biblioteca.')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToLibrary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final hasBook = club.currentBookTitle != null;

    // Sem container bordado — conteúdo editorial direto
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kicker
        Text(
          'EM LEITURA',
          style: ReadLogType.kicker(
            size: 10,
            color: ReadLogColors.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (!hasBook)
          Text(
            'Nenhum livro definido.',
            style: ReadLogType.bookTitle(
              size: 22,
              color: ReadLogColors.ink.withValues(alpha: 0.35),
              italic: true,
            ),
          )
        else ...[
          // Título em display — Fraunces, protagonista
          Text(
            club.currentBookTitle!,
            style: ReadLogType.bookTitle(
              size: 26,
              color: ReadLogColors.ink,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (club.currentBookAuthor != null) ...[
            const SizedBox(height: 4),
            Text(
              club.currentBookAuthor!,
              style: ReadLogType.authorName(
                size: 14,
                color: ReadLogColors.inkMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Metadados inline: ritmo · meta
          if (club.readingPacePerDay != null || club.readingTargetEndDate != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (club.readingPacePerDay != null)
                  '${club.readingPacePerDay} pág/dia',
                if (club.readingTargetEndDate != null)
                  'meta ${DateFormat('dd/MM/yyyy', 'pt_BR').format(club.readingTargetEndDate!)}',
              ].join(' · '),
              style: ReadLogType.mono(
                size: 11,
                color: ReadLogColors.inkMuted,
              ),
            ),
          ],
          // Botão de adicionar à biblioteca
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _addingToLibrary ? null : _addToLibrary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_addingToLibrary)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: ReadLogColors.inkMuted,
                    ),
                  )
                else
                  Icon(
                    Icons.add,
                    size: 14,
                    color: ReadLogColors.inkMuted,
                  ),
                const SizedBox(width: 6),
                Text(
                  'Adicionar à minha biblioteca',
                  style: ReadLogType.authorName(
                    size: 13,
                    color: ReadLogColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Meetings List ─────────────────────────────────────────────────────────────

// ── Members List ──────────────────────────────────────────────────────────────

class _MembersList extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _MembersList({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_clubMembersProvider(clubId));

    return membersAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e'),
      data: (members) => Column(
        children: members
            .map((m) => _MemberTile(
                  member: m,
                  club: club,
                  clubId: clubId,
                ))
            .toList(),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final ClubMember member;
  final BookClub club;
  final String clubId;

  const _MemberTile({
    required this.member,
    required this.club,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canActOnMember = club.isOwner ||
        (club.isAdmin && !member.canManage);

    final roleText = member.isOwner
        ? 'dono'
        : member.isAdmin
            ? 'admin'
            : member.isMentor
                ? 'mentor'
                : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name ?? 'Usuário',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: ReadLogColors.ink,
                  ),
                ),
                if (roleText != null)
                  Text(
                    roleText,
                    style: ReadLogType.kicker(
                      size: 10,
                      color: ReadLogColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (canActOnMember && !club.isClosed)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz,
                  size: 18, color: ReadLogColors.ink.withValues(alpha: 0.4)),
              onSelected: (v) => _onMemberAction(context, ref, v),
              itemBuilder: (_) => _memberMenuItems(),
            ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _memberMenuItems() {
    final items = <PopupMenuEntry<String>>[];

    // Promover para Admin (member ou mentor → admin)
    if ((member.role == 'member' || member.role == 'mentor') &&
        (club.isOwner ||
            (club.isAdmin && club.adminsCanPromote))) {
      items.add(const PopupMenuItem(
        value: 'promote',
        child: ListTile(
          leading: Icon(Icons.arrow_upward),
          title: Text('Promover para Admin'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    // Tornar Mentor (apenas member → mentor, por owner ou admin)
    if (member.role == 'member' && club.canManage) {
      items.add(const PopupMenuItem(
        value: 'make_mentor',
        child: ListTile(
          leading: Icon(Icons.school_outlined),
          title: Text('Tornar Mentor'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    // Remover papel de Mentor (mentor → member)
    if (member.isMentor && club.canManage) {
      items.add(const PopupMenuItem(
        value: 'remove_mentor',
        child: ListTile(
          leading: Icon(Icons.school_outlined),
          title: Text('Remover papel de Mentor'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    // Rebaixar Admin para Membro (somente owner)
    if (member.role == 'admin' && club.isOwner) {
      items.add(const PopupMenuItem(
        value: 'demote',
        child: ListTile(
          leading: Icon(Icons.arrow_downward),
          title: Text('Rebaixar para Membro'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    // Boas-vindas de mentor (só o próprio mentor vê, para membros que entraram recentemente)
    if (club.isMentor && !member.isOwner && !member.isAdmin) {
      items.add(const PopupMenuItem(
        value: 'welcome',
        child: ListTile(
          leading: Icon(Icons.waving_hand_outlined),
          title: Text('Dar boas-vindas'),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }

    if (!member.isOwner) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'remove',
        child: ListTile(
          leading: Icon(Icons.person_remove_outlined,
              color: AppColors.error),
          title: Text('Remover do clube',
              style: TextStyle(color: AppColors.error)),
          contentPadding: EdgeInsets.zero,
        ),
      ));
    }
    return items;
  }

  void _onMemberAction(
      BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'promote':
        _confirmPromotion(context, ref);
        break;
      case 'make_mentor':
        _confirmSetMentor(context, ref, promote: true);
        break;
      case 'remove_mentor':
        _confirmSetMentor(context, ref, promote: false);
        break;
      case 'demote':
        _confirmDemotion(context, ref);
        break;
      case 'welcome':
        _sendWelcome(context, ref);
        break;
      case 'remove':
        _confirmRemoval(context, ref);
        break;
    }
  }

  void _confirmPromotion(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Promover para Admin'),
        content: Text(
            'Promover "${member.name ?? 'este membro'}" para administrador?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(bookClubRepositoryProvider)
                  .promoteMember(clubId, member.userId);
              ref.invalidate(_clubMembersProvider(clubId));
            },
            child: const Text('Promover'),
          ),
        ],
      ),
    );
  }

  void _confirmDemotion(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rebaixar para Membro'),
        content: Text(
            'Rebaixar "${member.name ?? 'este admin'}" para membro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(bookClubRepositoryProvider)
                  .demoteMember(clubId, member.userId);
              ref.invalidate(_clubMembersProvider(clubId));
            },
            child: const Text('Rebaixar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoval(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text(
            'Remover "${member.name ?? 'este membro'}" do clube?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(bookClubRepositoryProvider)
                  .removeMember(clubId, member.userId);
              ref.invalidate(_clubMembersProvider(clubId));
              ref.invalidate(_clubDetailProvider(clubId));
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _confirmSetMentor(BuildContext context, WidgetRef ref,
      {required bool promote}) {
    final action = promote ? 'Tornar Mentor' : 'Remover papel de Mentor';
    final body = promote
        ? 'Tornar "${member.name ?? 'este membro'}" Mentor do clube?'
        : 'Remover o papel de Mentor de "${member.name ?? 'este mentor'}"?';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(action),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookClubRepositoryProvider).setMentor(
                    clubId: clubId,
                    userId: member.userId,
                    promote: promote,
                  );
              ref.invalidate(_clubMembersProvider(clubId));
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _sendWelcome(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final defaultMsg =
        'Bem-vindo(a) ao clube, ${member.name ?? 'novo leitor'}! 📚';
    controller.text = defaultMsg;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dar boas-vindas'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Mensagem de boas-vindas…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final msg = controller.text.trim();
              Navigator.pop(context);
              await ref
                  .read(bookClubRepositoryProvider)
                  .mentorWelcomeMember(
                    clubId: clubId,
                    newMemberId: member.userId,
                    message: msg.isNotEmpty ? msg : null,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Mensagem de boas-vindas enviada!')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

}

// ── (RoleBadge substituído por texto inline em _MemberTile) ──────────────────

// ── Book History List ─────────────────────────────────────────────────────────

class _BookHistoryList extends ConsumerWidget {
  final String clubId;

  const _BookHistoryList({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_clubHistoryProvider(clubId));

    return historyAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.ink)),
      data: (history) {
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhum livro no histórico ainda.',
              style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.ink.withValues(alpha: 0.45),
              ),
            ),
          );
        }
        return Column(
          children: history.map((h) => _HistoryTile(entry: h)).toList(),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ClubBookHistory entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM/yyyy', 'pt_BR');
    final period = entry.isFinished
        ? '${dateFmt.format(entry.startedAt)} → ${dateFmt.format(entry.endedAt!)}'
        : 'Iniciado em ${dateFmt.format(entry.startedAt)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.bookTitle,
                  style: ReadLogType.bookTitle(size: 15, color: ReadLogColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (entry.bookAuthor != null) entry.bookAuthor!,
                    period,
                    if (entry.meetingCount > 0) '${entry.meetingCount} encontros',
                  ].join(' · '),
                  style: ReadLogType.authorName(size: 12, color: ReadLogColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leave Button ──────────────────────────────────────────────────────────────

class _LeaveButton extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _LeaveButton({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _confirmLeave(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        padding: EdgeInsets.zero,
      ),
      child: const Text('Sair do clube'),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do clube'),
        content: Text('Deseja sair do clube "${club.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookClubRepositoryProvider).leaveClub(clubId);
              if (context.mounted) context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ── Leave as Owner Button (tela separada com fluxo de transferência) ──────────

class _LeaveAsOwnerButton extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _LeaveAsOwnerButton({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _confirmLeave(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        padding: EdgeInsets.zero,
      ),
      child: const Text('Transferir e sair'),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair como Dono'),
        content: const Text(
          'Como você é o dono, a propriedade será transferida '
          'automaticamente para o admin mais antigo, ou para o '
          'membro mais antigo caso não haja admins.\n\n'
          'Se você for o único membro, o clube será encerrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(bookClubRepositoryProvider)
                  .leaveClubAsOwner(clubId);
              if (!context.mounted) return;
              final msg = result == 'closed'
                  ? 'Clube encerrado (nenhum outro membro).'
                  : 'Propriedade transferida com sucesso.';
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
              context.pop();
            },
            child: const Text('Confirmar saída'),
          ),
        ],
      ),
    );
  }
}

// ── Delete Club Button ────────────────────────────────────────────────────────

class _DeleteClubButton extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _DeleteClubButton({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: () => _confirmDelete(context, ref),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: EdgeInsets.zero,
        ),
        child: const Text('Excluir clube definitivamente'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Excluir clube'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta ação é irreversível. '
                'Todo o histórico e dados do clube serão perdidos.\n\n'
                'Digite o nome do clube para confirmar:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: club.name,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              onPressed: ctrl.text.trim() == club.name
                  ? () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(bookClubRepositoryProvider)
                          .deleteClub(clubId);
                      if (context.mounted) context.pop();
                    }
                  : null,
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seção de votação de próximo livro ─────────────────────────────────────────


// ── Progresso Coletivo ────────────────────────────────────────────────────────

class _ReadingProgressSection extends ConsumerWidget {
  final String clubId;

  const _ReadingProgressSection({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(_clubReadingProgressProvider(clubId));

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (progress) {
        if (progress == null) return const SizedBox.shrink();
        final pct = (progress.percentComplete / 100).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kicker
            Text(
              'PROGRESSO DO GRUPO',
              style: ReadLogType.kicker(size: 10, color: ReadLogColors.inkMuted),
            ),
            const SizedBox(height: 10),
            // Linha fina canônica — LumenReadingProgress
            LumenReadingProgress(
              progress: pct,
              label: '${progress.percentComplete.toStringAsFixed(0)}% do clube já passou deste ponto',
            ),
            const SizedBox(height: 10),
            // Stats inline sem ícone — só número + legenda
            Row(
              children: [
                _ProgressStat(
                  value: '${progress.totalPagesRead}',
                  label: 'pág lidas',
                ),
                const SizedBox(width: 20),
                _ProgressStat(
                  value: '${progress.membersReadToday}',
                  label: 'hoje',
                ),
                const SizedBox(width: 20),
                _ProgressStat(
                  value: 'pág ${progress.avgCurrentPage.toStringAsFixed(0)}',
                  label: 'média',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProgressStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: ReadLogType.bookTitle(size: 22, color: ReadLogColors.ink),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: ReadLogType.kicker(size: 10, color: ReadLogColors.inkMuted),
        ),
      ],
    );
  }
}

// ── Lendo Agora ───────────────────────────────────────────────────────────────

class _ReadingNowSection extends ConsumerWidget {
  final String clubId;

  const _ReadingNowSection({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowAsync = ref.watch(_clubReadingNowProvider(clubId));

    return nowAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (readers) {
        if (readers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ReadLogColors.progress,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'lendo agora (${readers.length})',
                  style: ReadLogType.kicker(
                    size: 10,
                    color: ReadLogColors.progress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...readers.map((r) => _ReaderRow(reader: r)),
          ],
        );
      },
    );
  }
}

class _ReaderRow extends StatelessWidget {
  final ClubReadingNowEntry reader;

  const _ReaderRow({required this.reader});

  @override
  Widget build(BuildContext context) {
    final name = reader.userName ?? 'Leitor';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: ReadLogColors.ink,
            ),
          ),
          Text(
            reader.elapsedLabel,
            style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ── Hall da Fama ──────────────────────────────────────────────────────────────

class _HallOfFameSection extends ConsumerWidget {
  final String clubId;

  const _HallOfFameSection({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hofAsync = ref.watch(_clubHallOfFameProvider(clubId));

    return hofAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hall da Fama',
              style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) => _HofRow(entry: e)),
          ],
        );
      },
    );
  }
}

class _HofRow extends StatelessWidget {
  final ClubHallOfFameEntry entry;

  const _HofRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM/yyyy', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Livro + data ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.bookTitle,
                      style: ReadLogType.bookTitle(size: 15, color: ReadLogColors.ink),
                    ),
                    if (entry.bookAuthor != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.bookAuthor!,
                        style: ReadLogType.authorName(size: 12, color: ReadLogColors.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt.format(entry.seasonEndedAt),
                style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Totais da temporada ───────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _HofStat(label: 'membros', value: '${entry.totalMembers}'),
              _HofStat(label: 'páginas', value: '${entry.totalPages}'),
              if (entry.totalMinutes > 0)
                _HofStat(
                  label: 'horas',
                  value: (entry.totalMinutes / 60).toStringAsFixed(1),
                ),
              if (entry.totalSessions > 0)
                _HofStat(label: 'sessões', value: '${entry.totalSessions}'),
            ],
          ),
          // ── Destaques individuais ─────────────────────────────────────
          if (entry.topReaderName != null ||
              entry.topStreakName != null ||
              entry.topSessionsName != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (entry.topReaderName != null)
                  _HofHighlight(
                    icon: '📖',
                    label: 'mais leu',
                    name: entry.topReaderName!,
                    detail: entry.topReaderPages != null
                        ? '${entry.topReaderPages} pág'
                        : null,
                  ),
                if (entry.topStreakName != null)
                  _HofHighlight(
                    icon: '🔥',
                    label: 'maior streak',
                    name: entry.topStreakName!,
                    detail: entry.topStreakDays != null
                        ? '${entry.topStreakDays} dias'
                        : null,
                  ),
                if (entry.topSessionsName != null)
                  _HofHighlight(
                    icon: '⏱',
                    label: 'mais sessões',
                    name: entry.topSessionsName!,
                    detail: entry.topSessionsCount != null
                        ? '${entry.topSessionsCount}x'
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _HofStat extends StatelessWidget {
  final String label;
  final String value;

  const _HofStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
        children: [
          TextSpan(
            text: value,
            style: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
    );
  }
}

class _HofHighlight extends StatelessWidget {
  final String icon;
  final String label;
  final String name;
  final String? detail;

  const _HofHighlight({
    required this.icon,
    required this.label,
    required this.name,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          name,
          style: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
        ),
        Text(
          ' · $label${detail != null ? ' ($detail)' : ''}',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.inkMuted),
        ),
      ],
    );
  }
}


// ── Card de votação ───────────────────────────────────────────────────────────

class _PollCard extends ConsumerStatefulWidget {
  final ClubBookPoll poll;
  final BookClub club;
  final String clubId;

  const _PollCard({
    required this.poll,
    required this.club,
    required this.clubId,
  });

  @override
  ConsumerState<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<_PollCard> {
  bool _voting = false;

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final total = poll.totalVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poll.title,
                      style: ReadLogType.mono(size: 13, color: ReadLogColors.ink),
                    ),
                    if (poll.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        poll.description!,
                        style: ReadLogType.mono(
                          size: 10,
                          color: ReadLogColors.ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                poll.isOpen ? 'aberta' : 'encerrada',
                style: ReadLogType.mono(
                  size: 10,
                  color: poll.isOpen ? ReadLogColors.sage : ReadLogColors.ink.withValues(alpha: 0.35),
                ),
              ),
              if (widget.club.canManage)
                PopupMenuButton<String>(
                  onSelected: (v) => _onPollAction(context, v),
                  icon: Icon(Icons.more_horiz,
                      size: 16, color: ReadLogColors.ink.withValues(alpha: 0.4)),
                  itemBuilder: (_) => [
                    if (poll.isOpen)
                      const PopupMenuItem(
                        value: 'close',
                        child: ListTile(
                          leading: Icon(Icons.lock_outline),
                          title: Text('Encerrar votação'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text('Excluir votação',
                            style: TextStyle(color: AppColors.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // ── Opções ─────────────────────────────────────────────────────
        ...poll.options.map((opt) {
          final pct = total == 0 ? 0.0 : opt.voteCount / total;
          final isMyVote = poll.myVoteOptionId == opt.id;

          return InkWell(
            onTap: poll.isOpen && !_voting ? () => _vote(opt.id) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.bookTitle,
                          style: ReadLogType.mono(
                            size: 12,
                            color: isMyVote
                                ? ReadLogColors.ink
                                : ReadLogColors.ink.withValues(alpha: 0.7),
                            weight: isMyVote ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        if (opt.bookAuthor != null)
                          Text(
                            opt.bookAuthor!,
                            style: ReadLogType.mono(
                              size: 10,
                              color: ReadLogColors.ink.withValues(alpha: 0.45),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${opt.voteCount} · ${(pct * 100).toStringAsFixed(0)}%',
                    style: ReadLogType.mono(
                      size: 10,
                      color: isMyVote
                          ? ReadLogColors.ink
                          : ReadLogColors.ink.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // ── Rodapé ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            '$total ${total == 1 ? 'voto total' : 'votos totais'}'
            '${poll.isOpen ? ' · toque para votar' : ''}',
            style: ReadLogType.mono(
              size: 10,
              color: ReadLogColors.ink.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _vote(String optionId) async {
    setState(() => _voting = true);
    try {
      await ref
          .read(bookClubRepositoryProvider)
          .voteOnPoll(pollId: widget.poll.id, optionId: optionId);
      ref.invalidate(_clubPollsProvider(widget.clubId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao votar: $e')));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  void _onPollAction(BuildContext context, String action) {
    if (action == 'close') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Encerrar votação'),
          content: const Text(
              'Nenhum novo voto poderá ser registrado. Continuar?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(bookClubRepositoryProvider)
                    .closePoll(widget.poll.id);
                ref.invalidate(_clubPollsProvider(widget.clubId));
              },
              child: const Text('Encerrar'),
            ),
          ],
        ),
      );
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir votação'),
          content: const Text('Esta ação é irreversível. Confirmar?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(bookClubRepositoryProvider)
                    .deletePoll(widget.poll.id);
                ref.invalidate(_clubPollsProvider(widget.clubId));
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
    }
  }
}

// ── Sheet: criar votação ──────────────────────────────────────────────────────

class _CreatePollSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;

  const _CreatePollSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<_CreatePollSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<_OptionEntry> _options = [
    _OptionEntry(),
    _OptionEntry(),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final opts = _options
        .where((o) => o.titleCtrl.text.trim().isNotEmpty)
        .map((o) => (
              bookTitle: o.titleCtrl.text.trim(),
              bookAuthor: o.authorCtrl.text.trim().isEmpty
                  ? null
                  : o.authorCtrl.text.trim(),
            ))
        .toList();

    if (opts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Adicione pelo menos 2 opções de livros.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).createPoll(
            clubId: widget.clubId,
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            options: opts,
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar votação: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Nova votação de livro',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título da votação *',
                hintText: 'Ex: Próximo livro — agosto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            Text('Opções de livros', style: AppTextStyles.bodyLarge
                .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._options.asMap().entries.map((e) {
              final i = e.key;
              final opt = e.value;
              return _OptionEntryWidget(
                key: ObjectKey(opt),
                entry: opt,
                index: i,
                canRemove: _options.length > 2,
                onRemove: () => setState(() => _options.removeAt(i)),
                onChanged: () => setState(() {}),
              );
            }),
            if (_options.length < 8)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Adicionar opção'),
                onPressed: () =>
                    setState(() => _options.add(_OptionEntry())),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Criar votação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget de opção de livro com busca ───────────────────────────────────────

class _OptionEntryWidget extends StatefulWidget {
  final _OptionEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _OptionEntryWidget({
    super.key,
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_OptionEntryWidget> createState() => _OptionEntryWidgetState();
}

class _OptionEntryWidgetState extends State<_OptionEntryWidget> {
  final _bookSearch = BookSearchService();
  Timer? _debounce;
  List<BookSearchResult> _suggestions = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _bookSearch.search(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
    });
  }

  void _fillFromResult(BookSearchResult result) {
    widget.entry.titleCtrl.text = result.title;
    widget.entry.authorCtrl.text = result.author ?? '';
    widget.entry.coverUrl = result.coverUrl;
    setState(() {
      _suggestions = [];
      widget.entry.searchCtrl.clear();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo de busca
                TextField(
                  controller: widget.entry.searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Buscar livro ${widget.index + 1}',
                    hintText: 'Título ou autor…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                // Lista de sugestões
                if (_suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, i) {
                            final r = _suggestions[i];
                            return InkWell(
                              onTap: () => _fillFromResult(r),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    if (r.coverUrl != null)
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(3),
                                        child: CachedNetworkImage(
                                          imageUrl: r.coverUrl!,
                                          width: 28,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const SizedBox(
                                            width: 28,
                                            height: 40,
                                            child: Icon(
                                                Icons.menu_book_outlined,
                                                color: AppColors.textMuted,
                                                size: 16),
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(
                                        width: 28,
                                        height: 40,
                                        child: Icon(Icons.menu_book_outlined,
                                            color: AppColors.textMuted,
                                            size: 16),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(r.title,
                                              style: AppTextStyles.titleMedium,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          if (r.author != null)
                                            Text(r.author!,
                                                style: AppTextStyles.bodyMedium,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                // Campos de título/autor preenchidos (editáveis)
                TextField(
                  controller: widget.entry.titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Título *',
                    prefixIcon: widget.entry.coverUrl != null
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: CachedNetworkImage(
                                imageUrl: widget.entry.coverUrl!,
                                width: 28,
                                height: 40,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.menu_book_outlined,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.entry.authorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Autor (opcional)',
                  ),
                ),
              ],
            ),
          ),
          if (widget.canRemove)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.error),
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}

class _OptionEntry {
  final searchCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final authorCtrl = TextEditingController();
  String? coverUrl;

  void dispose() {
    searchCtrl.dispose();
    titleCtrl.dispose();
    authorCtrl.dispose();
  }
}



// ── Set Book Sheet ────────────────────────────────────────────────────────────

class _SetBookSheet extends ConsumerStatefulWidget {
  final BookClub club;
  final String clubId;
  final VoidCallback onSaved;

  const _SetBookSheet({
    required this.club,
    required this.clubId,
    required this.onSaved,
  });

  @override
  ConsumerState<_SetBookSheet> createState() => _SetBookSheetState();
}

class _SetBookSheetState extends ConsumerState<_SetBookSheet> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _bookSearch = BookSearchService();
  Timer? _debounce;
  List<BookSearchResult> _suggestions = [];
  bool _searching = false;
  String? _selectedCoverUrl;
  bool _archivePrevious = true;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _bookSearch.search(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
    });
  }

  void _fillFromResult(BookSearchResult result) {
    _titleController.text = result.title;
    _authorController.text = result.author ?? '';
    setState(() {
      _selectedCoverUrl = result.coverUrl;
      _suggestions = [];
      _searchController.clear();
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).setCurrentBook(
            clubId: widget.clubId,
            bookTitle: title,
            bookAuthor: _authorController.text.trim().isEmpty
                ? null
                : _authorController.text.trim(),
            archivePrevious: _archivePrevious,
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPrevious = widget.club.currentBookTitle != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Livro atual', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 16),

          // ── Campo de busca ──────────────────────────────────────
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Buscar livro',
              hintText: 'Título ou autor…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),

          // ── Sugestões ───────────────────────────────────────────
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, i) {
                    final r = _suggestions[i];
                    return InkWell(
                      onTap: () => _fillFromResult(r),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            if (r.coverUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: r.coverUrl!,
                                  width: 32,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const SizedBox(
                                    width: 32,
                                    height: 44,
                                    child: Icon(Icons.menu_book_outlined,
                                        color: AppColors.textMuted, size: 18),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(
                                width: 32,
                                height: 44,
                                child: Icon(Icons.menu_book_outlined,
                                    color: AppColors.textMuted, size: 18),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title,
                                      style: AppTextStyles.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (r.author != null)
                                    Text(r.author!,
                                        style: AppTextStyles.bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Capa selecionada ────────────────────────────────────
          if (_selectedCoverUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedNetworkImage(
                      imageUrl: _selectedCoverUrl!,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 40,
                        height: 56,
                        color: AppColors.border,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Capa selecionada',
                        style: AppTextStyles.bodyMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remover capa',
                    onPressed: () =>
                        setState(() => _selectedCoverUrl = null),
                  ),
                ],
              ),
            ),

          // ── Campos manuais ──────────────────────────────────────
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _authorController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Autor (opcional)'),
          ),
          if (hasPrevious) ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Arquivar livro anterior no histórico',
                  style: TextStyle(fontSize: 13)),
              value: _archivePrevious,
              onChanged: (v) => setState(() => _archivePrevious = v),
              activeThumbColor: AppColors.forestGreen,
              activeTrackColor: AppColors.forestGreen.withValues(alpha: 0.4),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Meeting Sheet ─────────────────────────────────────────────────────────

class _AddMeetingSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;

  const _AddMeetingSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_AddMeetingSheet> createState() => _AddMeetingSheetState();
}

class _AddMeetingSheetState extends ConsumerState<_AddMeetingSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDateTime == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).createMeeting(
            clubId: widget.clubId,
            title: title,
            scheduledAt: _selectedDateTime!,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar encontro.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_BR');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Novo encontro', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ex: Capítulos 1-3',
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDateTime,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Data e hora',
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                  hintText: _selectedDateTime != null
                      ? fmt.format(_selectedDateTime!)
                      : 'Selecionar data',
                ),
                controller: TextEditingController(
                  text: _selectedDateTime != null
                      ? fmt.format(_selectedDateTime!)
                      : '',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Local (opcional)',
              hintText: 'Ex: Café Central ou link da videoconferência',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Agendar encontro'),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO: DESAFIOS DO CLUBE
// ════════════════════════════════════════════════════════════════════════════

class _ChallengesSection extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _ChallengesSection({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(_clubChallengesProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DESAFIOS',
                style: ReadLogType.kicker(size: 10, color: ReadLogColors.inkMuted),
              ),
            ),
            if (club.canManage)
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref),
                child: Text(
                  'Novo',
                  style: ReadLogType.authorName(size: 13, color: ReadLogColors.inkMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        challengesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const SizedBox.shrink(),
          data: (challenges) {
            if (challenges.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  club.canManage
                      ? 'Nenhum desafio ainda. Crie o primeiro.'
                      : 'Nenhum desafio criado ainda.',
                  style: ReadLogType.mono(
                    size: 12,
                    color: ReadLogColors.ink.withValues(alpha: 0.45),
                  ),
                ),
              );
            }
            final active = challenges.where((c) => c.isOngoing).toList();
            final others = challenges.where((c) => !c.isOngoing).toList();
            return Column(
              children: [
                ...active.map((c) => _ChallengeCard(
                      challenge: c,
                      clubId: clubId,
                      isActive: true,
                    )),
                ...others.take(3).map((c) => _ChallengeCard(
                      challenge: c,
                      clubId: clubId,
                      isActive: false,
                    )),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateChallengeSheet(
        clubId: clubId,
        onSaved: () => ref.invalidate(_clubChallengesProvider(clubId)),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  final ClubChallenge challenge;
  final String clubId;
  final bool isActive;

  const _ChallengeCard({
    required this.challenge,
    required this.clubId,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isActive ? ReadLogColors.ink : ReadLogColors.inkMuted;

    return InkWell(
      onTap: () => context.push(
        '/clubs/$clubId/challenges/${challenge.id}',
        extra: {'challengeTitle': challenge.title},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      'meta: ${challenge.goalValue} ${challenge.goalType.unit}',
                      challenge.daysLeftLabel,
                    ].join(' · '),
                    style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isActive ? 'ativo' : (challenge.status.dbValue == 'finished' ? 'encerrado' : 'cancelado'),
              style: ReadLogType.kicker(
                size: 9,
                color: isActive ? ReadLogColors.progress : ReadLogColors.inkGhost,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 14, color: ReadLogColors.inkGhost),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: Criar Desafio ──────────────────────────────────────────────────────

class _CreateChallengeSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;

  const _CreateChallengeSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_CreateChallengeSheet> createState() =>
      _CreateChallengesheetState();
}

class _CreateChallengesheetState extends ConsumerState<_CreateChallengeSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _goalValueCtrl = TextEditingController();
  ChallengeGoalType _goalType = ChallengeGoalType.pages;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 30));
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _goalValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final goalValue = int.tryParse(_goalValueCtrl.text.trim()) ?? 0;
    if (title.isEmpty || goalValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e a meta.')),
      );
      return;
    }
    if (_endsAt.isBefore(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data de fim deve ser após a de início.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).createChallenge(
            clubId: widget.clubId,
            title: title,
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            goalType: _goalType,
            goalValue: goalValue,
            startsAt: _startsAt,
            endsAt: _endsAt,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startsAt : _endsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startsAt = picked;
          if (_endsAt.isBefore(_startsAt)) {
            _endsAt = _startsAt.add(const Duration(days: 30));
          }
        } else {
          _endsAt = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Novo desafio',
                style: AppTextStyles.headlineMedium
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome do desafio *',
                hintText: 'Ex: Desafio de Março',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Tipo de meta', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ChallengeGoalType.values.map((t) {
                final selected = _goalType == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _goalType = t),
                  selectedColor: AppColors.warmGold.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalValueCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Meta (${_goalType.unit}) *',
                hintText: 'Ex: 500',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Início: ${fmt.format(_startsAt)}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text('Fim: ${fmt.format(_endsAt)}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warmGold),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Criar desafio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO: VOTAÇÕES LIVRES (OPEN POLLS)
// ════════════════════════════════════════════════════════════════════════════

class _OpenPollCard extends ConsumerStatefulWidget {
  final ClubOpenPoll poll;
  final String clubId;

  const _OpenPollCard({required this.poll, required this.clubId});

  @override
  ConsumerState<_OpenPollCard> createState() => _OpenPollCardState();
}

class _OpenPollCardState extends ConsumerState<_OpenPollCard> {
  List<OpenPollOptionResult>? _results;
  bool _loadingVote = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final results = await ref
        .read(bookClubRepositoryProvider)
        .fetchOpenPollResults(widget.poll.id);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _vote(String optionId) async {
    setState(() => _loadingVote = true);
    try {
      await ref
          .read(bookClubRepositoryProvider)
          .voteOnOpenPoll(widget.poll.id, [optionId]);
      await _loadResults();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingVote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final results = _results;
    final isOpen = widget.poll.isOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.poll.question,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: cs.onSurface, fontSize: 13),
                ),
              ),
              Text(
                isOpen ? 'aberta' : 'encerrada',
                style: ReadLogType.mono(
                  size: 10,
                  color: isOpen ? ReadLogColors.sage : ReadLogColors.ink.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (results == null)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            ...results.map((r) {
              return InkWell(
                onTap: (isOpen && !_loadingVote) ? () => _vote(r.optionId) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.optionLabel,
                          style: ReadLogType.mono(
                            size: 12,
                            color: r.votedByMe
                                ? ReadLogColors.ink
                                : ReadLogColors.ink.withValues(alpha: 0.7),
                            weight: r.votedByMe ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        '${r.voteCount} · ${r.pct.toStringAsFixed(0)}%',
                        style: ReadLogType.mono(
                          size: 10,
                          color: r.votedByMe
                              ? ReadLogColors.ink
                              : ReadLogColors.ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Sheet: Criar Votação Livre ────────────────────────────────────────────────

class _CreateOpenPollSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;

  const _CreateOpenPollSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_CreateOpenPollSheet> createState() =>
      _CreateOpenPollSheetState();
}

class _CreateOpenPollSheetState extends ConsumerState<_CreateOpenPollSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiSelect = false;
  bool _loading = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha a pergunta e ao menos 2 opções.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final pollOptions = options.asMap().entries.map((e) {
        return OpenPollOption(id: 'opt_${e.key + 1}', label: e.value);
      }).toList();
      await ref.read(bookClubRepositoryProvider).createOpenPoll(
            clubId: widget.clubId,
            question: question,
            options: pollOptions,
            multiSelect: _multiSelect,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nova votação',
                style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: _questionCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Pergunta *',
                hintText: 'Ex: Qual horário preferem para o encontro?',
              ),
            ),
            const SizedBox(height: 12),
            Text('Opções', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            ..._optionCtrls.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Opção ${e.key + 1}',
                          ),
                        ),
                      ),
                      if (_optionCtrls.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.error),
                          onPressed: () => setState(() {
                            e.value.dispose();
                            _optionCtrls.removeAt(e.key);
                          }),
                        ),
                    ],
                  ),
                )),
            if (_optionCtrls.length < 6)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _optionCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar opção'),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Permitir múltiplas escolhas'),
              value: _multiSelect,
              onChanged: (v) => setState(() => _multiSelect = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7c5cd8)),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Criar votação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SectionLabel ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ReadLogType.kicker(
        size: 10,
        color: ReadLogColors.inkMuted,
      ),
    );
  }
}

// ── _MemoryAccordion ──────────────────────────────────────────────────────────

class _MemoryAccordion extends StatefulWidget {
  final String title;
  final Widget? child;

  const _MemoryAccordion({
    required this.title,
    this.child,
  });

  @override
  State<_MemoryAccordion> createState() => _MemoryAccordionState();
}

class _MemoryAccordionState extends State<_MemoryAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.child != null
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: ReadLogColors.ink,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: ReadLogColors.inkGhost,
                ),
              ],
            ),
          ),
          if (_expanded && widget.child != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.child!,
            ),
        ],
      ),
    );
  }
}

// ── _TimelineButton ───────────────────────────────────────────────────────────

class _TimelineButton extends StatelessWidget {
  final String clubId;
  final String clubName;

  const _TimelineButton({required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/clubs/$clubId/timeline',
        extra: {'clubName': clubName},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Linha do tempo',
                style: ReadLogType.mono(size: 13, color: ReadLogColors.ink),
              ),
            ),
            Icon(Icons.chevron_right, size: 14,
                color: ReadLogColors.ink.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _StatsButton extends StatelessWidget {
  final String clubId;
  final String clubName;

  const _StatsButton({required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/clubs/$clubId/stats',
        extra: {'clubName': clubName},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Estatísticas',
                style: ReadLogType.mono(size: 13, color: ReadLogColors.ink),
              ),
            ),
            Icon(Icons.chevron_right, size: 14,
                color: ReadLogColors.ink.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHEET: EDITAR CLUBE
// ════════════════════════════════════════════════════════════════════════════

class _EditClubSheet extends ConsumerStatefulWidget {
  final BookClub club;
  final VoidCallback onSaved;

  const _EditClubSheet({required this.club, required this.onSaved});

  @override
  ConsumerState<_EditClubSheet> createState() => _EditClubSheetState();
}

class _EditClubSheetState extends ConsumerState<_EditClubSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  File? _coverFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.club.name);
    _descController =
        TextEditingController(text: widget.club.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCover(ImageSource source) async {
    try {
      final xFile = await ImagePicker()
          .pickImage(source: source, imageQuality: 85, maxWidth: 1024);
      if (xFile != null && mounted) {
        setState(() => _coverFile = File(xFile.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível acessar a câmera ou galeria.')),
        );
      }
    }
  }

  void _showCoverSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickCover(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickCover(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      String? coverUrl;
      if (_coverFile != null) {
        coverUrl = await ref
            .read(bookClubRepositoryProvider)
            .uploadClubCover(widget.club.id, _coverFile!);
      }
      await ref.read(bookClubRepositoryProvider).updateClub(
            clubId: widget.club.id,
            name: name,
            description:
                _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            coverUrl: coverUrl,
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final existingCoverUrl = widget.club.coverUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar clube', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          // ── Capa do clube ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _showCoverSourceSheet,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                image: _coverFile != null
                    ? DecorationImage(
                        image: FileImage(_coverFile!),
                        fit: BoxFit.cover,
                      )
                    : (existingCoverUrl != null
                        ? DecorationImage(
                            image: NetworkImage(existingCoverUrl),
                            fit: BoxFit.cover,
                          )
                        : null),
              ),
              child: (_coverFile == null && existingCoverUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 32, color: cs.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text('Adicionar capa',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: cs.surface.withValues(alpha: 0.85),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: cs.onSurface),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome do clube'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(labelText: 'Descrição (opcional)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
