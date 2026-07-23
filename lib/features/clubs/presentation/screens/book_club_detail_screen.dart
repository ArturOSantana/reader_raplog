import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';
import '../../../library/data/book_search_result.dart';
import '../../../library/data/book_search_service.dart';

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

  const _ClubDetailBody({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(club.name),
        actions: [
          if (club.canManage)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenuSelected(context, ref, v),
              itemBuilder: (_) => _buildMenuItems(club),
            ),
        ],
      ),
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
        },
        child: Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final sectionStyle = AppTextStyles.headlineMedium
              .copyWith(color: cs.onSurface);
          return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Status banner ────────────────────────────────────────────
            if (!club.isActive) _StatusBanner(club: club),
            if (!club.isActive) const SizedBox(height: 16),
            // ── Cabeçalho ────────────────────────────────────────────────
            _ClubHeader(club: club),
            const SizedBox(height: 16),
            // ── Código de convite ────────────────────────────────────────
            if (club.inviteCode != null && club.canManage && !club.isClosed)
              _InviteCodeCard(inviteCode: club.inviteCode!),
            if (club.inviteCode != null && club.canManage && !club.isClosed)
              const SizedBox(height: 16),
            // ── Livro atual ──────────────────────────────────────────────
            _CurrentBookCard(club: club),
            const SizedBox(height: 16),
            // ── Progresso coletivo (só quando há livro em leitura) ───────
            if (club.currentBookStatus == 'reading') ...[
              _ReadingProgressSection(clubId: clubId),
              const SizedBox(height: 16),
              // ── Lendo agora ───────────────────────────────────────────
              _ReadingNowSection(clubId: clubId),
              const SizedBox(height: 24),
            ],
            // ── Votação de próximo livro ──────────────────────────────────
            if (!club.isClosed) ...[
              _BookPollSection(club: club, clubId: clubId),
              const SizedBox(height: 24),
            ],
            // ── Encontros ────────────────────────────────────────────────
            if (!club.isClosed) ...[
              Text('Encontros', style: sectionStyle),
              const SizedBox(height: 12),
              _MeetingsList(clubId: clubId),
              const SizedBox(height: 24),
            ],
            // ── Membros ──────────────────────────────────────────────────
            Text('Membros', style: sectionStyle),
            const SizedBox(height: 12),
            _MembersList(club: club, clubId: clubId),
            const SizedBox(height: 24),
            // ── Histórico de livros ──────────────────────────────────────
            Text('Histórico de leituras', style: sectionStyle),
            const SizedBox(height: 12),
            _BookHistoryList(clubId: clubId),
            const SizedBox(height: 24),
            // ── Hall da Fama ──────────────────────────────────────────────
            _HallOfFameSection(clubId: clubId),
            const SizedBox(height: 24),
            // ── Ações do membro ──────────────────────────────────────────
            if (club.isOwner && !club.isClosed)
              _LeaveAsOwnerButton(club: club, clubId: clubId),
            if (!club.isOwner && !club.isClosed)
              _LeaveButton(club: club, clubId: clubId),
            // ── Excluir clube (dono, após carência) ──────────────────────
            if (club.isOwner && club.canBeDeleted)
              _DeleteClubButton(club: club, clubId: clubId),
            const SizedBox(height: 8),
          ],
        );
        }),
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
    final isVacation = club.isOnVacation;
    final bg = isVacation
        ? AppColors.warmGold.withValues(alpha: 0.1)
        : AppColors.surfaceVariant;
    final fg = isVacation ? AppColors.warmGold : AppColors.textMuted;
    final icon =
        isVacation ? Icons.beach_access_outlined : Icons.lock_outline;
    final msg = isVacation
        ? 'Este clube está em férias. Leituras e encontros estão pausados.'
        : 'Este clube foi encerrado. Apenas consulta disponível.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: TextStyle(
                    fontSize: 13, color: fg, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Invite Code Card ──────────────────────────────────────────────────────────

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;

  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = AppColors.warmGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key_outlined, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código de convite',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  inviteCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_outlined, color: accentColor, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado!')),
              );
            },
            tooltip: 'Copiar código',
          ),
        ],
      ),
    );
  }
}

// ── Club Header ───────────────────────────────────────────────────────────────

class _ClubHeader extends StatelessWidget {
  final BookClub club;

  const _ClubHeader({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconBg = club.isClosed
        ? cs.surfaceContainerHighest
        : club.isOnVacation
            ? AppColors.warmGold.withValues(alpha: isDark ? 0.18 : 0.1)
            : AppColors.warmGold.withValues(alpha: isDark ? 0.18 : 0.1);
    final iconFg = club.isClosed
        ? cs.onSurfaceVariant
        : club.isOnVacation
            ? AppColors.warmGold
            : cs.onSurface;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.groups, color: iconFg, size: 36),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(club.name,
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: cs.onSurface)),
              if (club.description != null && club.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    club.description!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${club.memberCount} ${club.memberCount == 1 ? 'membro' : 'membros'}',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  _statusChip(club),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(BookClub c) {
    late final Color bg, fg;
    late final IconData icon;
    switch (c.status) {
      case ClubStatus.active:
        bg = AppColors.success.withValues(alpha: 0.22);
        fg = AppColors.success;
        icon = Icons.circle;
        break;
      case ClubStatus.onVacation:
        bg = AppColors.warmGold.withValues(alpha: 0.22);
        fg = AppColors.warmGold;
        icon = Icons.beach_access_outlined;
        break;
      case ClubStatus.closed:
        bg = Colors.white.withValues(alpha: 0.12);
        fg = Colors.white70;
        icon = Icons.lock_outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: c.isActive ? 7 : 12, color: fg),
        const SizedBox(width: 4),
        Text(c.status.label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg)),
      ]),
    );
  }
}

// ── Current Book Card ─────────────────────────────────────────────────────────

class _CurrentBookCard extends StatelessWidget {
  final BookClub club;

  const _CurrentBookCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBook = club.currentBookTitle != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBook
              ? AppColors.warmGold.withValues(alpha: 0.4)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 60,
            decoration: BoxDecoration(
              color: hasBook
                  ? AppColors.warmGold.withValues(alpha: 0.18)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              color: hasBook ? AppColors.warmGold : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Leitura atual',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (hasBook) _BookStatusChip(club.currentBookStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasBook ? club.currentBookTitle! : 'Nenhum livro definido',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: hasBook ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (club.currentBookAuthor != null)
                  Text(
                    club.currentBookAuthor!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (hasBook && club.readingPacePerDay != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${club.readingPacePerDay} pág/dia',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ],
                if (hasBook && club.readingTargetEndDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Meta: ${DateFormat('dd/MM/yyyy', 'pt_BR').format(club.readingTargetEndDate!)}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de status do ciclo de leitura ────────────────────────────────────────

class _BookStatusChip extends StatelessWidget {
  final String status; // none|voting|chosen|reading|finished

  const _BookStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'voting'   => ('Votação', AppColors.warmGold),
      'chosen'   => ('Escolhido', AppColors.forestGreenLight),
      'reading'  => ('Em leitura', AppColors.forestGreen),
      'finished' => ('Finalizado', AppColors.textSecondary),
      _          => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Meetings List ─────────────────────────────────────────────────────────────

class _MeetingsList extends ConsumerWidget {
  final String clubId;

  const _MeetingsList({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final meetingsAsync = ref.watch(_clubMeetingsProvider(clubId));

    return meetingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e',
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface)),
      data: (meetings) {
        if (meetings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined,
                    color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 10),
                Text('Nenhum encontro agendado',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return Column(
          children: meetings
              .map((m) => _MeetingTile(meeting: m, clubId: clubId))
              .toList(),
        );
      },
    );
  }
}

class _MeetingTile extends ConsumerWidget {
  final BookClubMeeting meeting;
  final String clubId;

  const _MeetingTile({required this.meeting, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat("d MMM 'às' HH:mm", 'pt_BR');
    final isUpcoming = meeting.isUpcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpcoming
              ? AppColors.warmGold.withValues(alpha: 0.4)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(meeting.title,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: cs.onSurface)),
              ),
              if (isUpcoming)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warmGold.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Em breve',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warmGold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(fmt.format(meeting.scheduledAt),
                  style: AppTextStyles.labelMedium
                      .copyWith(color: cs.onSurfaceVariant)),
              if (meeting.location != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.place_outlined,
                    size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(meeting.location!,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('✅ ${meeting.goingCount}  🤔 ${meeting.maybeCount}',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              if (isUpcoming) _RsvpButtons(meeting: meeting, clubId: clubId),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsvpButtons extends ConsumerWidget {
  final BookClubMeeting meeting;
  final String clubId;

  const _RsvpButtons({required this.meeting, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RsvpChip(
          label: 'Vou',
          isActive: meeting.myRsvp == MeetingRsvp.going,
          activeColor: AppColors.forestGreen,
          onTap: () => _setRsvp(ref, MeetingRsvp.going),
        ),
        const SizedBox(width: 6),
        _RsvpChip(
          label: 'Talvez',
          isActive: meeting.myRsvp == MeetingRsvp.maybe,
          activeColor: AppColors.warmGold,
          onTap: () => _setRsvp(ref, MeetingRsvp.maybe),
        ),
        const SizedBox(width: 6),
        _RsvpChip(
          label: 'Não',
          isActive: meeting.myRsvp == MeetingRsvp.notGoing,
          activeColor: AppColors.error,
          onTap: () => _setRsvp(ref, MeetingRsvp.notGoing),
        ),
      ],
    );
  }

  Future<void> _setRsvp(WidgetRef ref, MeetingRsvp rsvp) async {
    await ref.read(bookClubRepositoryProvider).setRsvp(
          meetingId: meeting.id,
          rsvp: rsvp,
        );
    ref.invalidate(_clubMeetingsProvider(clubId));
  }
}

class _RsvpChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _RsvpChip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? activeColor : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

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
    final cs = Theme.of(context).colorScheme;
    final canActOnMember = club.isOwner ||
        (club.isAdmin && !member.canManage);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.warmGold.withValues(alpha: 0.18),
        child: member.avatarUrl != null
            ? ClipOval(
                child: Image.network(
                  member.avatarUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _initials(member.name ?? '?'),
                ),
              )
            : _initials(member.name ?? '?'),
      ),
      title: Text(member.name ?? 'Usuário',
          style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface)),
      subtitle: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!member.isOwner)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: member.isAdmin
                    ? AppColors.warmGold.withValues(alpha: 0.22)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                member.roleLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: member.isAdmin
                      ? AppColors.warmGold
                      : cs.onSurfaceVariant,
                ),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Dono',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warmGold,
                ),
              ),
            ),
          if (canActOnMember && !club.isClosed)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: cs.onSurfaceVariant),
              onSelected: (v) =>
                  _onMemberAction(context, ref, v),
              itemBuilder: (_) => _memberMenuItems(),
            ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _memberMenuItems() {
    final items = <PopupMenuEntry<String>>[];
    if (member.role == 'member' &&
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
      case 'demote':
        _confirmDemotion(context, ref);
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

  Widget _initials(String name) {
    final parts = name.trim().split(' ');
    final text = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return Text(text,
        style: const TextStyle(
          color: AppColors.warmGold,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ));
  }
}

// ── Book History List ─────────────────────────────────────────────────────────

class _BookHistoryList extends ConsumerWidget {
  final String clubId;

  const _BookHistoryList({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(_clubHistoryProvider(clubId));

    return historyAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e',
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface)),
      data: (history) {
        if (history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 10),
                Text('Nenhum livro no histórico ainda.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
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
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MMM/yyyy', 'pt_BR');
    final period = entry.isFinished
        ? '${dateFmt.format(entry.startedAt)} → ${dateFmt.format(entry.endedAt!)}'
        : 'Iniciado em ${dateFmt.format(entry.startedAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warmGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.menu_book_outlined,
                color: AppColors.warmGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.bookTitle,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: cs.onSurface)),
                if (entry.bookAuthor != null)
                  Text(entry.bookAuthor!,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(period,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (entry.meetingCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${entry.meetingCount} encontros',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warmGold,
                ),
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
    return OutlinedButton.icon(
      onPressed: () => _confirmLeave(context, ref),
      icon: const Icon(Icons.logout),
      label: const Text('Sair do clube'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
      ),
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
    return OutlinedButton.icon(
      onPressed: () => _confirmLeave(context, ref),
      icon: const Icon(Icons.logout),
      label: const Text('Transferir e sair'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
      ),
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
      child: OutlinedButton.icon(
        onPressed: () => _confirmDelete(context, ref),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Excluir clube definitivamente'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
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
    final cs = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(_clubReadingProgressProvider(clubId));

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (progress) {
        if (progress == null) return const SizedBox.shrink();
        final pct = progress.percentComplete.clamp(0.0, 100.0);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Progresso do grupo',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 6,
                  backgroundColor: cs.outlineVariant,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatPill(
                    icon: Icons.menu_book_outlined,
                    label: '${progress.totalPagesRead} pág lidas',
                  ),
                  _StatPill(
                    icon: Icons.people_outline,
                    label: '${progress.membersReadToday} hoje',
                  ),
                  _StatPill(
                    icon: Icons.auto_stories_outlined,
                    label: 'pág ${progress.avgCurrentPage.toStringAsFixed(0)} em média',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(color: cs.onSurfaceVariant)),
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
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.forestGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Lendo agora (${readers.length})',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: readers.map((r) => _ReaderChip(reader: r)).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _ReaderChip extends StatelessWidget {
  final ClubReadingNowEntry reader;

  const _ReaderChip({required this.reader});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = reader.userName ?? 'Leitor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.forestGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.forestGreen.withValues(alpha: 0.3),
            backgroundImage: reader.avatarUrl != null
                ? NetworkImage(reader.avatarUrl!)
                : null,
            child: reader.avatarUrl == null
                ? Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w600)),
              Text(reader.elapsedLabel,
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
            ],
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
    final cs = Theme.of(context).colorScheme;
    final hofAsync = ref.watch(_clubHallOfFameProvider(clubId));

    return hofAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined,
                    size: 18, color: AppColors.warmGold),
                const SizedBox(width: 6),
                Text('Hall da Fama',
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.map((e) => _HofCard(entry: e)),
          ],
        );
      },
    );
  }
}

class _HofCard extends StatelessWidget {
  final ClubHallOfFameEntry entry;

  const _HofCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM/yyyy', 'pt_BR');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.warmGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 16, color: AppColors.warmGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.bookTitle,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                fmt.format(entry.seasonEndedAt),
                style: AppTextStyles.labelMedium
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (entry.bookAuthor != null) ...[
            const SizedBox(height: 2),
            Text(entry.bookAuthor!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (entry.topReaderName != null)
                _HofStat('📖 +leu', entry.topReaderName!,
                    sub: '${entry.topReaderPages ?? 0} pág'),
              if (entry.topSessionsName != null)
                _HofStat('⏱ +sessões', entry.topSessionsName!,
                    sub: '${entry.topSessionsCount ?? 0}×'),
              _HofStat('👥 Membros', '${entry.totalMembers}'),
              _HofStat('📄 Páginas', '${entry.totalPages}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HofStat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;

  const _HofStat(this.label, this.value, {this.sub});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        Text(value,
            style: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
        if (sub != null)
          Text(sub!,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }
}


class _BookPollSection extends ConsumerWidget {
  final BookClub club;
  final String clubId;

  const _BookPollSection({required this.club, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pollsAsync = ref.watch(_clubPollsProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Votação de livro',
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: cs.onSurface)),
            ),
            if (club.canManage)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova votação'),
                onPressed: () => _showCreatePollSheet(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 12),
        pollsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('Erro ao carregar votações: $e',
                  style: const TextStyle(color: AppColors.error)),
          data: (polls) {
            if (polls.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'Nenhuma votação criada.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: polls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PollCard(
                poll: polls[i],
                club: club,
                clubId: clubId,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showCreatePollSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreatePollSheet(
        clubId: clubId,
        onSaved: () => ref.invalidate(_clubPollsProvider(clubId)),
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poll.title,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (poll.description != null) ...[
                        const SizedBox(height: 2),
                        Text(poll.description!,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                // Badge de status
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: poll.isOpen
                        ? AppColors.forestGreen.withAlpha(26)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    poll.isOpen ? 'Aberta' : 'Encerrada',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: poll.isOpen
                          ? AppColors.forestGreen
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.club.canManage)
                  PopupMenuButton<String>(
                    onSelected: (v) =>
                        _onPollAction(context, v),
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
                          leading: Icon(Icons.delete_outline,
                              color: AppColors.error),
                          title: Text('Excluir votação',
                              style:
                                  TextStyle(color: AppColors.error)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // ── Opções ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: poll.options.map((opt) {
                final pct =
                    total == 0 ? 0.0 : opt.voteCount / total;
                final isMyVote =
                    poll.myVoteOptionId == opt.id;
                final isLeading = poll.leadingOption?.id == opt.id &&
                    opt.voteCount > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: poll.isOpen && !_voting
                        ? () => _vote(opt.id)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMyVote
                              ? AppColors.forestGreen
                              : AppColors.border,
                          width: isMyVote ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isLeading)
                                          const Icon(
                                              Icons.emoji_events,
                                              size: 16,
                                              color: Color(0xFFB8860B)),
                                        if (isLeading)
                                          const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            opt.bookTitle,
                                            style: AppTextStyles
                                                .bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (opt.bookAuthor != null)
                                      Text(
                                        opt.bookAuthor!,
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                                color:
                                                    AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opt.voteCount} ${opt.voteCount == 1 ? 'voto' : 'votos'}',
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isMyVote
                                      ? AppColors.forestGreen
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: AppColors.border,
                              color: isMyVote
                                  ? AppColors.forestGreen
                                  : AppColors.textMuted
                                      .withAlpha(128),
                            ),
                          ),
                          if (pct > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Rodapé ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              '$total ${total == 1 ? 'voto total' : 'votos totais'}'
              '${poll.isOpen ? ' · Toque para votar' : ''}',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
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
