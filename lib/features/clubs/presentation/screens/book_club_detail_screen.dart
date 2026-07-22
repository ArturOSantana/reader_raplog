import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/providers/providers.dart';

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
          if (club.isModerator)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenuSelected(context, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'set_book',
                  child: ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('Definir livro atual'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_meeting',
                  child: ListTile(
                    leading: Icon(Icons.event_outlined),
                    title: Text('Agendar encontro'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_clubDetailProvider(clubId));
          ref.invalidate(_clubMembersProvider(clubId));
          ref.invalidate(_clubMeetingsProvider(clubId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Cabeçalho ────────────────────────────────────────────────
            _ClubHeader(club: club),
            const SizedBox(height: 24),
            // ── Livro atual ──────────────────────────────────────────────
            _CurrentBookCard(club: club),
            const SizedBox(height: 24),
            // ── Encontros ────────────────────────────────────────────────
            Text('Encontros', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),
            _MeetingsList(clubId: clubId),
            const SizedBox(height: 24),
            // ── Membros ──────────────────────────────────────────────────
            Text('Membros', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),
            _MembersList(clubId: clubId),
            const SizedBox(height: 24),
            // ── Sair do clube ────────────────────────────────────────────
            if (!club.isAdmin)
              OutlinedButton.icon(
                onPressed: () => _confirmLeave(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Sair do clube'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value) {
    if (value == 'set_book') {
      _showSetBookSheet(context, ref);
    } else if (value == 'add_meeting') {
      _showAddMeetingSheet(context, ref);
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
        clubId: clubId,
        onSaved: () => ref.invalidate(_clubDetailProvider(clubId)),
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

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do clube'),
        content:
            Text('Deseja sair do clube "${club.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(bookClubRepositoryProvider)
                  .leaveClub(clubId);
              if (context.mounted) context.pop();
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Sair'),
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
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.groups,
            color: AppColors.forestGreen,
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(club.name, style: AppTextStyles.headlineMedium),
              if (club.description != null && club.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    club.description!,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${club.memberCount} ${club.memberCount == 1 ? 'membro' : 'membros'}',
                    style: AppTextStyles.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Current Book Card ─────────────────────────────────────────────────────────

class _CurrentBookCard extends StatelessWidget {
  final BookClub club;

  const _CurrentBookCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final hasBook = club.currentBookTitle != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasBook
            ? AppColors.forestGreen.withValues(alpha: 0.06)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBook
              ? AppColors.forestGreen.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 60,
            decoration: BoxDecoration(
              color: hasBook
                  ? AppColors.forestGreen.withValues(alpha: 0.15)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              color: hasBook ? AppColors.forestGreen : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leitura atual',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  hasBook
                      ? club.currentBookTitle!
                      : 'Nenhum livro definido',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: hasBook
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (club.currentBookAuthor != null)
                  Text(
                    club.currentBookAuthor!,
                    style: AppTextStyles.bodyMedium,
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

// ── Meetings List ─────────────────────────────────────────────────────────────

class _MeetingsList extends ConsumerWidget {
  final String clubId;

  const _MeetingsList({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(_clubMeetingsProvider(clubId));

    return meetingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.bodyMedium),
      data: (meetings) {
        if (meetings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_outlined,
                    color: AppColors.textMuted, size: 20),
                SizedBox(width: 10),
                Text('Nenhum encontro agendado',
                    style: TextStyle(color: AppColors.textMuted)),
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
    final fmt = DateFormat("d MMM 'às' HH:mm", 'pt_BR');
    final isUpcoming = meeting.isUpcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpcoming
              ? AppColors.warmGold.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (isUpcoming)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warmGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Em breve',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warmGold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(fmt.format(meeting.scheduledAt),
                  style: AppTextStyles.labelMedium),
              if (meeting.location != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.place_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(meeting.location!,
                      style: AppTextStyles.labelMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '✅ ${meeting.goingCount}  🤔 ${meeting.maybeCount}',
                style: AppTextStyles.labelMedium,
              ),
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
            color: isActive ? activeColor : AppColors.border,
          ),
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
  final String clubId;

  const _MembersList({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_clubMembersProvider(clubId));

    return membersAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Erro: $e'),
      data: (members) => Column(
        children: members
            .map((m) => _MemberTile(member: m))
            .toList(),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ClubMember member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.forestGreen.withValues(alpha: 0.1),
        child: member.avatarUrl != null
            ? ClipOval(
                child: Image.network(
                  member.avatarUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _initials(member.name ?? '?'),
                ),
              )
            : _initials(member.name ?? '?'),
      ),
      title: Text(
        member.name ?? 'Usuário',
        style: AppTextStyles.titleMedium,
      ),
      trailing: member.role != 'member'
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: member.role == 'admin'
                    ? AppColors.forestGreen.withValues(alpha: 0.12)
                    : AppColors.warmGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                member.role == 'admin' ? 'Admin' : 'Mod',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: member.role == 'admin'
                      ? AppColors.forestGreen
                      : AppColors.warmGold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _initials(String name) {
    final parts = name.trim().split(' ');
    final text = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.forestGreen,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

// ── Set Book Sheet ────────────────────────────────────────────────────────────

class _SetBookSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onSaved;

  const _SetBookSheet({required this.clubId, required this.onSaved});

  @override
  ConsumerState<_SetBookSheet> createState() => _SetBookSheetState();
}

class _SetBookSheetState extends ConsumerState<_SetBookSheet> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
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
          const SizedBox(height: 20),
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
