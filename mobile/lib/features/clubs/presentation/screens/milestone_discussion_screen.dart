import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _milestoneTopicsProvider =
    FutureProvider.family<List<ClubMilestoneTopic>, String>(
        (ref, milestoneId) {
  return ref
      .read(bookClubRepositoryProvider)
      .listMilestoneTopics(milestoneId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MilestoneDiscussionScreen extends ConsumerStatefulWidget {
  final ClubMilestone milestone;
  final String clubId;
  final String clubName;
  final String? coverUrl;

  const MilestoneDiscussionScreen({
    super.key,
    required this.milestone,
    required this.clubId,
    required this.clubName,
    this.coverUrl,
  });

  @override
  ConsumerState<MilestoneDiscussionScreen> createState() =>
      _MilestoneDiscussionScreenState();
}

class _MilestoneDiscussionScreenState
    extends ConsumerState<MilestoneDiscussionScreen> {
  final _ctrl = TextEditingController();
  String _spoilerLevel = 'none';
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
      await ref.read(bookClubRepositoryProvider).addMilestoneTopic(
            milestoneId: widget.milestone.id,
            clubId: widget.clubId,
            content: text,
            spoilerLevel: _spoilerLevel,
          );
      _ctrl.clear();
      setState(() => _spoilerLevel = 'none');
      ref.invalidate(_milestoneTopicsProvider(widget.milestone.id));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(_milestoneTopicsProvider(widget.milestone.id));
    final isUnlocked = widget.milestone.isUnlocked;

    return LumenClubTintBackground(
      coverUrl: widget.coverUrl,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.milestone.label,
                style: ReadLogType.bookTitle(size: 16)),
            Text(widget.clubName,
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Banner do marco — LumenUnlockBanner + LumenSpoilerNote ────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUnlocked)
                  LumenUnlockBanner(
                    label: 'Marco ${widget.milestone.milestonePct}% liberado',
                  )
                else
                  Text(
                    'Marco ${widget.milestone.milestonePct}%',
                    style: ReadLogType.kicker(
                        size: 11, color: ReadLogColors.inkMuted),
                  ),
                if (isUnlocked && widget.milestone.unlockedAt != null) ...[
                  const SizedBox(height: 4),
                  LumenSpoilerNote(
                    text:
                        'Destravado em ${_fmtDate(widget.milestone.unlockedAt!)}. '
                        'Comentários além deste ponto ficam ocultos para quem ainda não chegou aqui.',
                  ),
                ] else if (!isUnlocked) ...[
                  const SizedBox(height: 4),
                  LumenSpoilerNote(
                    text: 'Leia até este ponto para participar desta discussão.',
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: ReadLogColors.hairline),
              ],
            ),
          ),

          // ── Lista de tópicos ─────────────────────────────────────────────
          Expanded(
            child: topics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível carregar as discussões.\n$e',
                    textAlign: TextAlign.center,
                    style:
                        ReadLogType.authorName(color: ReadLogColors.inkMuted),
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
                          Text('Nenhuma discussão ainda.',
                              style: ReadLogType.bookTitle(size: 18)),
                          const SizedBox(height: 6),
                          Text(
                            'Seja o primeiro a compartilhar sua impressão.',
                            textAlign: TextAlign.center,
                            style: ReadLogType.authorName(
                                color: ReadLogColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final roots = list.where((t) => t.parentId == null).toList();
                final replies =
                    list.where((t) => t.parentId != null).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(_milestoneTopicsProvider(widget.milestone.id)),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: roots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
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

          // ── Caixa de input ────────────────────────────────────────────────
          _ComposerBar(
            ctrl: _ctrl,
            spoilerLevel: _spoilerLevel,
            sending: _sending,
            onSpoilerChanged: (v) => setState(() => _spoilerLevel = v),
            onSend: _send,
          ),
        ],
      ),
    ),
    );
  }

  void _showReplySheet(BuildContext context, String parentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ReplySheet(
        milestoneId: widget.milestone.id,
        clubId: widget.clubId,
        parentId: parentId,
        onSent: () =>
            ref.invalidate(_milestoneTopicsProvider(widget.milestone.id)),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      DateFormat("d 'de' MMM", 'pt_BR').format(dt.toLocal());
}

// ── Card de tópico ─────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final ClubMilestoneTopic topic;
  final List<ClubMilestoneTopic> replies;
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
        _TopicTile(topic: topic, onReply: () => onReply(topic.id)),
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
  final ClubMilestoneTopic topic;
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
          // Cabeçalho: nome + tempo + spoiler label
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      topic.userName ?? 'Membro',
                      style: ReadLogType.authorName(size: 13),
                    ),
                    if (topic.hasSpoiler) ...[
                      const SizedBox(width: 6),
                      Text(
                        topic.spoilerLevel == 'full'
                            ? '· spoiler'
                            : '· parcial',
                        style: ReadLogType.mono(
                            size: 10, color: ReadLogColors.inkMuted),
                      ),
                    ],
                  ],
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
          Text(topic.content,
              style: ReadLogType.authorName(size: 14)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onReply,
            child: Text(
              'Responder',
              style: ReadLogType.kicker(
                  color: ReadLogColors.inkMuted, size: 11),
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

// ── Barra de composição ────────────────────────────────────────────────────────

class _ComposerBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String spoilerLevel;
  final bool sending;
  final void Function(String) onSpoilerChanged;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.ctrl,
    required this.spoilerLevel,
    required this.sending,
    required this.onSpoilerChanged,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seletor de spoiler — abas de texto
            Row(
              children: [
                Text('Spoiler:',
                    style: ReadLogType.mono(
                        size: 11, color: ReadLogColors.inkMuted)),
                const SizedBox(width: 8),
                _SpoilerTab(
                    label: 'Nenhum',
                    value: 'none',
                    selected: spoilerLevel == 'none',
                    onTap: onSpoilerChanged),
                const SizedBox(width: 12),
                _SpoilerTab(
                    label: 'Parcial',
                    value: 'partial',
                    selected: spoilerLevel == 'partial',
                    onTap: onSpoilerChanged),
                const SizedBox(width: 12),
                _SpoilerTab(
                    label: 'Spoiler',
                    value: 'full',
                    selected: spoilerLevel == 'full',
                    onTap: onSpoilerChanged),
              ],
            ),
            const SizedBox(height: 6),
            Row(
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
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
          ],
        ),
      ),
    );
  }
}

class _SpoilerTab extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String) onTap;

  const _SpoilerTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: Text(
        label,
        style: ReadLogType.mono(
          size: 11,
          color: selected ? ReadLogColors.ink : ReadLogColors.inkGhost,
        ),
      ),
    );
  }
}

// ── Sheet de resposta ──────────────────────────────────────────────────────────

class _ReplySheet extends ConsumerStatefulWidget {
  final String milestoneId;
  final String clubId;
  final String parentId;
  final VoidCallback onSent;

  const _ReplySheet({
    required this.milestoneId,
    required this.clubId,
    required this.parentId,
    required this.onSent,
  });

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  final _ctrl = TextEditingController();
  // ignore: prefer_final_fields
  String _spoilerLevel = 'none';
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
      await ref.read(bookClubRepositoryProvider).addMilestoneTopic(
            milestoneId: widget.milestoneId,
            clubId: widget.clubId,
            content: text,
            spoilerLevel: _spoilerLevel,
            parentId: widget.parentId,
          );
      widget.onSent();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Responder',
                style: ReadLogType.bookTitle(size: 18)),
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
