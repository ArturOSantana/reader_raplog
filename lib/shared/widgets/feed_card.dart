/// Widgets de feed reutilizados pelo SocialScreen e pelo ClubFeedScreen.
/// Exporta: FeedCardWidget, MiniAvatar, FeedEventContent
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social_feed.dart';
import '../providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ── Avatar ────────────────────────────────────────────────────────────────────

class MiniAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const MiniAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.border,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _Initials(name: name, radius: radius),
          ),
        ),
      );
    }
    return _Initials(name: name, radius: radius);
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double radius;
  const _Initials({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Conteúdo do evento ────────────────────────────────────────────────────────

class FeedEventContent extends StatelessWidget {
  final FeedItem item;

  const FeedEventContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.eventType) {
      case FeedEventType.finishedBook:
        return _FinishedBookCard(item: item);
      case FeedEventType.startedBook:
        return _SimpleEventCard(
          emoji: '📖',
          color: AppColors.forestGreenLight,
          lines: ['Começou a ler', if (item.bookTitle != null) item.bookTitle!],
        );
      case FeedEventType.streak:
        return _SimpleEventCard(
          emoji: '🔥',
          color: AppColors.warmGold,
          lines: ['Ofensiva de', '${item.streakDays ?? 0} dias lendo!'],
        );
      case FeedEventType.achievement:
        return _SimpleEventCard(
          emoji: '🏅',
          color: AppColors.warmGoldLight,
          lines: [
            'Conquista desbloqueada',
            if (item.achievementName != null) item.achievementName!,
          ],
        );
      case FeedEventType.goalCompleted:
        return _SimpleEventCard(
          emoji: '🎯',
          color: AppColors.forestGreen,
          lines: [
            'Completou a meta',
            if (item.goalDescription != null) item.goalDescription!,
          ],
        );
      case FeedEventType.readingSession:
        return _SimpleEventCard(
          emoji: '📖',
          color: AppColors.forestGreenLight,
          lines: [
            'Terminou uma sessão',
            if (item.bookTitle != null) item.bookTitle!,
            if (item.pagesRead != null && item.pagesRead! > 0)
              '${item.pagesRead} páginas · ${item.readingTimeLabel}',
            if (item.streakDays != null && item.streakDays! > 1)
              '🔥 ${item.streakDays} dias de ofensiva',
          ],
        );
      case FeedEventType.joinedClub:
        return _SimpleEventCard(
          emoji: '📚',
          color: AppColors.warmGoldLight,
          lines: ['Entrou em um clube de leitura'],
        );
    }
  }
}

class _FinishedBookCard extends StatelessWidget {
  final FeedItem item;
  const _FinishedBookCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terminou de ler', style: AppTextStyles.bodyMedium),
                if (item.bookTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(item.bookTitle!,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
                if (item.rating != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < item.rating!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: i < item.rating! ? AppColors.warmGold : AppColors.border,
                    )),
                  ),
                ],
                if (item.review != null && item.review!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${item.review!}"',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.readingTimeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(item.readingTimeLabel, style: AppTextStyles.labelMedium),
                    ],
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

class _SimpleEventCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final List<String> lines;

  const _SimpleEventCard({
    required this.emoji,
    required this.color,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.asMap().entries.map((e) => Text(
                e.value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: e.key == 1 ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra de reações ──────────────────────────────────────────────────────────

class ReactionsBar extends StatelessWidget {
  final Set<String> myReactions;
  final Map<String, int> summary;
  final void Function(FeedReactionType) onToggle;

  const ReactionsBar({
    super.key,
    required this.myReactions,
    required this.summary,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: FeedReactionType.values.map((type) {
        final isActive = myReactions.contains(type.dbValue);
        final count = summary[type.dbValue] ?? 0;
        return GestureDetector(
          onTap: () => onToggle(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.warmGold.withValues(alpha: 0.2)
                  : AppColors.textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? AppColors.warmGold.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 14)),
                if (count > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.warmGold : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Card principal do feed ────────────────────────────────────────────────────

class FeedCardWidget extends ConsumerStatefulWidget {
  final FeedItem item;
  final VoidCallback onLikeToggle;
  /// Se true, mostra botão de comentários que abre bottom sheet
  final bool showComments;

  const FeedCardWidget({
    super.key,
    required this.item,
    required this.onLikeToggle,
    this.showComments = false,
  });

  @override
  ConsumerState<FeedCardWidget> createState() => _FeedCardWidgetState();
}

class _FeedCardWidgetState extends ConsumerState<FeedCardWidget> {
  Set<String> _myReactions = {};
  bool _reactionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMyReactions();
  }

  Future<void> _loadMyReactions() async {
    final reactions = await ref
        .read(socialFeedRepositoryProvider)
        .fetchMyReactions(widget.item.id);
    if (mounted) {
      setState(() {
        _myReactions = reactions;
        _reactionsLoaded = true;
      });
    }
  }

  Future<void> _toggleReaction(FeedReactionType type) async {
    final wasActive = _myReactions.contains(type.dbValue);
    setState(() {
      if (wasActive) {
        _myReactions = Set.from(_myReactions)..remove(type.dbValue);
      } else {
        _myReactions = Set.from(_myReactions)..add(type.dbValue);
      }
    });
    await ref
        .read(socialFeedRepositoryProvider)
        .toggleReaction(widget.item.id, type);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    return 'há ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final timeAgo = _timeAgo(item.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniAvatar(url: item.userAvatarUrl, name: item.userName ?? '?'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.userName ?? 'Usuário',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Text(timeAgo, style: AppTextStyles.labelMedium),
                  ],
                ),
                const SizedBox(height: 6),
                FeedEventContent(item: item),
                const SizedBox(height: 10),
                if (_reactionsLoaded)
                  ReactionsBar(
                    myReactions: _myReactions,
                    summary: item.reactionsSummary,
                    onToggle: _toggleReaction,
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onLikeToggle,
                      child: Row(
                        children: [
                          Icon(
                            item.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: item.likedByMe
                                ? AppColors.error
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text('${item.likesCount}',
                              style: AppTextStyles.labelMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.showComments
                          ? () => _showComments(context)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text('${item.commentsCount}',
                              style: AppTextStyles.labelMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(feedId: widget.item.id),
    );
  }
}

// ── Sheet de comentários ──────────────────────────────────────────────────────

class _CommentsSheet extends ConsumerStatefulWidget {
  final String feedId;
  const _CommentsSheet({required this.feedId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  List<FeedComment>? _comments;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ref
        .read(socialFeedRepositoryProvider)
        .fetchComments(widget.feedId);
    if (mounted) setState(() => _comments = data);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(socialFeedRepositoryProvider).addComment(
            feedId: widget.feedId,
            content: text,
          );
      _ctrl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final comments = _comments;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.comment_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Comentários',
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: cs.onSurface)),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: comments == null
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? Center(
                        child: Text('Seja o primeiro a comentar!',
                            style: AppTextStyles.bodyMedium),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) =>
                            _CommentTile(comment: comments[i]),
                      ),
          ),
          // Campo de envio
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escrever comentário...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
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

class _CommentTile extends StatelessWidget {
  final FeedComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = DateTime.now().difference(comment.createdAt);
    final timeAgo = diff.inMinutes < 60
        ? 'há ${diff.inMinutes}min'
        : diff.inHours < 24
            ? 'há ${diff.inHours}h'
            : 'há ${diff.inDays}d';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniAvatar(
            url: comment.userAvatarUrl,
            name: comment.userName ?? '?',
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Usuário',
                      style: AppTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo,
                        style: AppTextStyles.labelMedium
                            .copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
