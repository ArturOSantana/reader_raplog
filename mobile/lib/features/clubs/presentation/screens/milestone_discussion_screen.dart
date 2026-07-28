import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_schedule_milestones_challenges.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

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

  const MilestoneDiscussionScreen({
    super.key,
    required this.milestone,
    required this.clubId,
    required this.clubName,
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
      // Invalida o provider para recarregar a lista
      ref.invalidate(_milestoneTopicsProvider(widget.milestone.id));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = ref.watch(_milestoneTopicsProvider(widget.milestone.id));
    final milestoneColor = _milestoneColor(widget.milestone.milestonePct);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.milestone.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.clubName,
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Banner do marco ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: milestoneColor.withValues(alpha: isDark ? 0.18 : 0.1),
            child: Row(
              children: [
                Icon(
                  widget.milestone.icon,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.milestone.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: milestoneColor,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.milestone.isUnlocked)
                        Text(
                          'Destravado em ${_fmtDate(widget.milestone.unlockedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        )
                      else
                        Text(
                          'Ainda não destravado — leia mais para participar',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
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
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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
                          Icon(
                            widget.milestone.icon,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma discussão ainda.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seja o primeiro a compartilhar sua impressão!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Separa tópicos raiz das respostas
                final roots = list.where((t) => t.parentId == null).toList();
                final replies = list.where((t) => t.parentId != null).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(_milestoneTopicsProvider(widget.milestone.id)),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: roots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final root = roots[i];
                      final children =
                          replies.where((r) => r.parentId == root.id).toList();
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

  Color _milestoneColor(int pct) {
    switch (pct) {
      case 25:  return AppColors.forestGreenLight;
      case 50:  return AppColors.forestGreen;
      case 75:  return AppColors.warmGold;
      case 100: return AppColors.warmGoldLight;
      default:  return AppColors.forestGreen;
    }
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
            padding: const EdgeInsets.only(left: 40),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniAvatar(
            url: topic.userAvatarUrl,
            name: topic.userName ?? '?',
            radius: isReply ? 14 : 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? cs.surface : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        topic.userName ?? 'Membro',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (topic.hasSpoiler) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topic.spoilerLevel == 'full'
                                ? 'spoiler'
                                : 'parcial',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _timeAgo(topic.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(topic.content, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onReply,
                    child: Text(
                      'Responder',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 8,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seletor de spoiler
            Row(
              children: [
                Text(
                  'Aviso de spoiler:',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6),
                _SpoilerChip(
                    label: 'Nenhum',
                    value: 'none',
                    selected: spoilerLevel == 'none',
                    onTap: onSpoilerChanged),
                const SizedBox(width: 4),
                _SpoilerChip(
                    label: 'Parcial',
                    value: 'partial',
                    selected: spoilerLevel == 'partial',
                    onTap: onSpoilerChanged),
                const SizedBox(width: 4),
                _SpoilerChip(
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
                    decoration: InputDecoration(
                      hintText: 'Compartilhe sua impressão…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: onSend,
                        icon: const Icon(Icons.send_rounded),
                        color: cs.primary,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpoilerChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String) onTap;

  const _SpoilerChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
          ),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Responder',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onSurface)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              minLines: 2,
              maxLength: 2000,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escreva sua resposta…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
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
