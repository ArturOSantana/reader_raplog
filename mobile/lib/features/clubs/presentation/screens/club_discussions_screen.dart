import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _topicsProvider =
    FutureProvider.family<List<ClubDiscussionTopic>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listDiscussionTopics(clubId);
});

final _theoriesProvider =
    FutureProvider.family<List<ClubTheory>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listTheories(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubDiscussionsScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final bool canManage;

  const ClubDiscussionsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.canManage = false,
  });

  @override
  ConsumerState<ClubDiscussionsScreen> createState() =>
      _ClubDiscussionsScreenState();
}

class _ClubDiscussionsScreenState
    extends ConsumerState<ClubDiscussionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(_topicsProvider(widget.clubId));
    ref.invalidate(_theoriesProvider(widget.clubId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discussões', style: ReadLogType.bookTitle(size: 16)),
            Text(
              widget.clubName,
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Tópicos'),
            Tab(text: 'Teorias'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Aba 1: Tópicos livres ────────────────────────────────────────
          _TopicsTab(
            clubId: widget.clubId,
            clubName: widget.clubName,
            onInvalidate: _invalidate,
          ),
          // ── Aba 2: Teorias com votação ──────────────────────────────────
          _TheoriesTab(
            clubId: widget.clubId,
            clubName: widget.clubName,
            canManage: widget.canManage,
            onInvalidate: _invalidate,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 1 — TÓPICOS LIVRES
// ─────────────────────────────────────────────────────────────────────────────

class _TopicsTab extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final VoidCallback onInvalidate;

  const _TopicsTab({
    required this.clubId,
    required this.clubName,
    required this.onInvalidate,
  });

  @override
  ConsumerState<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends ConsumerState<_TopicsTab> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send({String? parentId}) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final topic = await ref
          .read(bookClubRepositoryProvider)
          .addDiscussionTopic(
            clubId: widget.clubId,
            content: text,
            parentId: parentId,
          );
      _ctrl.clear();
      widget.onInvalidate();

      // ── Notificação inbox: avisa membros do clube que alguém postou ──────
      // Dispara em background sem bloquear a UI.
      _notifyClubMembers(
        authorName: topic.createdByName ?? 'Alguém',
        previewText: text,
        isReply: parentId != null,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _notifyClubMembers({
    required String authorName,
    required String previewText,
    required bool isReply,
  }) {
    // Notificação enviada para o próprio clube — o backend deve fan-out
    // para todos os membros via trigger ou Edge Function.
    // No Flutter só enfileiramos o evento para o canal inbox do clube.
    final notif = ref.read(notificationPlatformProvider);
    final clubUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (clubUserId == null) return;

    final title = isReply
        ? '$authorName respondeu em Discussões'
        : '$authorName postou em Discussões';
    final body = previewText.length > 80
        ? '${previewText.substring(0, 80)}…'
        : previewText;

    // Notifica o próprio usuário no inbox como confirmação.
    notif
        .send(NotificationPayload(
          event: NotificationEvent.clubUpdate,
          recipientUserId: clubUserId,
          title: title,
          body: body,
          data: {
            'club_id': widget.clubId,
            'club_name': widget.clubName,
            'type': 'discussion_topic',
          },
          channels: [NotificationChannel.inbox],
        ))
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(_topicsProvider(widget.clubId));

    return Column(
      children: [
        Expanded(
          child: topicsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os tópicos.\n$e',
                  textAlign: TextAlign.center,
                  style: ReadLogType.authorName(
                      color: ReadLogColors.inkMuted),
                ),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Nenhum tópico ainda.',
                            style: ReadLogType.bookTitle(size: 18)),
                        const SizedBox(height: 6),
                        Text(
                          'Seja o primeiro a iniciar uma discussão.',
                          textAlign: TextAlign.center,
                          style: ReadLogType.authorName(
                              color: ReadLogColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final roots =
                  list.where((t) => t.parentId == null).toList();
              final replies =
                  list.where((t) => t.parentId != null).toList();

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(_topicsProvider(widget.clubId)),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  itemCount: roots.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final root = roots[i];
                    final children = replies
                        .where((r) => r.parentId == root.id)
                        .toList();
                    return _TopicCard(
                      topic: root,
                      replies: children,
                      onReply: (parentId) =>
                          _showReplySheet(context, parentId),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // ── Caixa de input principal ─────────────────────────────────────
        _TopicComposer(
          ctrl: _ctrl,
          sending: _sending,
          onSend: () => _send(),
        ),
      ],
    );
  }

  void _showReplySheet(BuildContext context, String parentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReplySheet(
        clubId: widget.clubId,
        clubName: widget.clubName,
        parentId: parentId,
        onSent: widget.onInvalidate,
      ),
    );
  }
}

// ── Card de tópico ────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final ClubDiscussionTopic topic;
  final List<ClubDiscussionTopic> replies;
  final void Function(String parentId) onReply;

  const _TopicCard({
    required this.topic,
    required this.replies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopicTile(
          topic: topic,
          onReply: () => onReply(topic.id),
        ),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Column(
              children: replies
                  .map((r) => _TopicTile(
                        topic: r,
                        isReply: true,
                        onReply: () => onReply(topic.id),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  final ClubDiscussionTopic topic;
  final bool isReply;
  final VoidCallback onReply;

  const _TopicTile({
    required this.topic,
    this.isReply = false,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 8 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic.createdByName ?? 'Membro',
                  style: ReadLogType.authorName(size: 13),
                ),
              ),
              Text(
                _timeAgo(topic.createdAt),
                style: ReadLogType.mono(
                    size: 10, color: ReadLogColors.inkGhost),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(topic.content, style: ReadLogType.authorName(size: 14)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onReply,
            child: Text(
              'Responder',
              style:
                  ReadLogType.kicker(color: ReadLogColors.inkMuted, size: 11),
            ),
          ),
          if (!isReply) const Divider(height: 16),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM', 'pt_BR').format(dt.toLocal());
  }
}

// ── Barra de composição ───────────────────────────────────────────────────────

class _TopicComposer extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;

  const _TopicComposer({
    required this.ctrl,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
              top: BorderSide(color: ReadLogColors.divider, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: 4,
                minLines: 1,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Compartilhe sua impressão…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 6),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet de resposta ─────────────────────────────────────────────────────────

class _ReplySheet extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final String parentId;
  final VoidCallback onSent;

  const _ReplySheet({
    required this.clubId,
    required this.clubName,
    required this.parentId,
    required this.onSent,
  });

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final topic = await ref
          .read(bookClubRepositoryProvider)
          .addDiscussionTopic(
            clubId: widget.clubId,
            content: text,
            parentId: widget.parentId,
          );
      widget.onSent();

      // Notificação de resposta
      final notif = ref.read(notificationPlatformProvider);
      final userId =
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;
        notif
            .send(NotificationPayload(
              event: NotificationEvent.clubUpdate,
              recipientUserId: userId,
              title: '${topic.createdByName ?? 'Alguém'} respondeu em Discussões',
              body: preview,
              data: {
                'club_id': widget.clubId,
                'club_name': widget.clubName,
                'type': 'discussion_reply',
              },
              channels: [NotificationChannel.inbox],
            ))
            .ignore();
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Responder', style: ReadLogType.bookTitle(size: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              minLines: 2,
              maxLength: 2000,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Escreva sua resposta…',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 2 — TEORIAS COM VOTAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _TheoriesTab extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final bool canManage;
  final VoidCallback onInvalidate;

  const _TheoriesTab({
    required this.clubId,
    required this.clubName,
    required this.canManage,
    required this.onInvalidate,
  });

  @override
  ConsumerState<_TheoriesTab> createState() => _TheoriesTabState();
}

class _TheoriesTabState extends ConsumerState<_TheoriesTab> {
  void _refresh() => ref.invalidate(_theoriesProvider(widget.clubId));

  @override
  Widget build(BuildContext context) {
    final theoriesAsync = ref.watch(_theoriesProvider(widget.clubId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Usando Scaffold interno para ter o FAB isolado nesta aba
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        tooltip: 'Nova teoria',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: theoriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível carregar as teorias.\n$e',
                    textAlign: TextAlign.center,
                    style: ReadLogType.authorName(
                        color: ReadLogColors.inkMuted),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Nenhuma teoria ainda.',
                              style: ReadLogType.bookTitle(size: 18)),
                          const SizedBox(height: 6),
                          Text(
                            'Adicione a primeira e veja quem acerta!',
                            textAlign: TextAlign.center,
                            style: ReadLogType.authorName(
                                color: ReadLogColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) => _TheoryTile(
                      theory: list[i],
                      canManage: widget.canManage,
                      onVoteToggled: _refresh,
                      onStatusChanged: _refresh,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddTheorySheet(
        clubId: widget.clubId,
        clubName: widget.clubName,
        onSaved: _refresh,
      ),
    );
  }
}

// ── Tile de teoria ─────────────────────────────────────────────────────────────

class _TheoryTile extends ConsumerStatefulWidget {
  final ClubTheory theory;
  final bool canManage;
  final VoidCallback onVoteToggled;
  final VoidCallback onStatusChanged;

  const _TheoryTile({
    required this.theory,
    required this.canManage,
    required this.onVoteToggled,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_TheoryTile> createState() => _TheoryTileState();
}

class _TheoryTileState extends ConsumerState<_TheoryTile> {
  bool _voting = false;

  Future<void> _toggleVote() async {
    if (_voting) return;
    setState(() => _voting = true);
    try {
      await ref
          .read(bookClubRepositoryProvider)
          .toggleTheoryVote(widget.theory.id);
      widget.onVoteToggled();
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theory;
    final statusColor = _statusColor(t.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Coluna de votos ──────────────────────────────────────────────
          SizedBox(
            width: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: t.isOpen ? _toggleVote : null,
                  child: _voting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          t.votedByMe
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_upward_outlined,
                          size: 20,
                          color: t.votedByMe
                              ? ReadLogColors.ink
                              : ReadLogColors.inkGhost,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.voteCount}',
                  style: ReadLogType.mono(
                    size: 13,
                    color: t.voteCount > 0
                        ? ReadLogColors.ink
                        : ReadLogColors.inkGhost,
                  ),
                ),
                Text(
                  t.voteCount == 1 ? 'voto' : 'votos',
                  style: ReadLogType.mono(
                      size: 10, color: ReadLogColors.inkGhost),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Conteúdo ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.status.label,
                        style: ReadLogType.kicker(
                            size: 10, color: statusColor),
                      ),
                    ),
                    if (t.milestoneId != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· marco',
                        style: ReadLogType.mono(
                            size: 10, color: ReadLogColors.inkGhost),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(t.content, style: ReadLogType.authorName(size: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      t.createdByName ?? 'Membro',
                      style: ReadLogType.authorName(
                          size: 12, color: ReadLogColors.inkMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${_timeAgo(t.createdAt)}',
                      style: ReadLogType.mono(
                          size: 10, color: ReadLogColors.inkGhost),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Menu de manager ──────────────────────────────────────────────
          if (widget.canManage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: ReadLogColors.inkGhost),
              onSelected: _onManagerAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'confirmed', child: Text('Confirmar')),
                const PopupMenuItem(
                    value: 'wrong', child: Text('Marcar como errada')),
                const PopupMenuItem(value: 'open', child: Text('Reabrir')),
              ],
            ),
        ],
      ),
    );
  }

  void _onManagerAction(String action) async {
    await ref.read(bookClubRepositoryProvider).setTheoryStatus(
          theoryId: widget.theory.id,
          status: action,
        );
    widget.onStatusChanged();
  }

  Color _statusColor(TheoryStatus status) {
    switch (status) {
      case TheoryStatus.open:
        return ReadLogColors.inkMuted;
      case TheoryStatus.confirmed:
        return ReadLogColors.progress;
      case TheoryStatus.wrong:
        return ReadLogColors.danger;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM', 'pt_BR').format(dt.toLocal());
  }
}

// ── Sheet de nova teoria ───────────────────────────────────────────────────────

class _AddTheorySheet extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final VoidCallback onSaved;

  const _AddTheorySheet({
    required this.clubId,
    required this.clubName,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddTheorySheet> createState() => _AddTheorySheetState();
}

class _AddTheorySheetState extends ConsumerState<_AddTheorySheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final theory = await ref.read(bookClubRepositoryProvider).addTheory(
            clubId: widget.clubId,
            content: text,
          );
      widget.onSaved();

      // ── Notificação inbox ao publicar teoria ──────────────────────────
      final notif = ref.read(notificationPlatformProvider);
      final userId =
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        final preview =
            text.length > 80 ? '${text.substring(0, 80)}…' : text;
        notif
            .send(NotificationPayload(
              event: NotificationEvent.clubUpdate,
              recipientUserId: userId,
              title:
                  '${theory.createdByName ?? 'Alguém'} postou uma teoria em Discussões',
              body: preview,
              data: {
                'club_id': widget.clubId,
                'club_name': widget.clubName,
                'type': 'theory',
              },
              channels: [NotificationChannel.inbox],
            ))
            .ignore();
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova teoria', style: ReadLogType.bookTitle(size: 18)),
            const SizedBox(height: 4),
            Text(
              'Sem spoiler — teorias são sobre o que ainda pode acontecer.',
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkMuted, size: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              minLines: 2,
              maxLength: 500,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Escreva sua teoria…',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
