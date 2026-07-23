import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _readingNowProvider =
    StreamProvider.family<List<ClubReadingNowEntry>, String>((ref, clubId) {
  // Dispara imediatamente e depois a cada 30 s
  return Stream.fromFuture(
          ref.read(bookClubRepositoryProvider).fetchReadingNow(clubId))
      .asyncExpand((initial) async* {
    yield initial;
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield await ref
          .read(bookClubRepositoryProvider)
          .fetchReadingNow(clubId);
    }
  });
});

// Reações efêmeras via Supabase Realtime Broadcast (não gravam no banco)
final _roomReactionsProvider =
    StateProvider.family<List<_RoomReaction>, String>((ref, clubId) => []);

// ── Model interno de reação efêmera ───────────────────────────────────────────

class _RoomReaction {
  final String emoji;
  final String fromName;
  final DateTime at;
  _RoomReaction({required this.emoji, required this.fromName})
      : at = DateTime.now();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubReadingRoomScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  const ClubReadingRoomScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<ClubReadingRoomScreen> createState() =>
      _ClubReadingRoomScreenState();
}

class _ClubReadingRoomScreenState
    extends ConsumerState<ClubReadingRoomScreen> {
  late final RealtimeChannel _channel;
  Timer? _reactionCleaner;

  static const _reactionOptions = ['❤️', '☕', '📚', '🔥'];

  @override
  void initState() {
    super.initState();
    _joinChannel();
    // Remove reações antigas após 4 s para manter UI limpa
    _reactionCleaner = Timer.periodic(const Duration(seconds: 2), (_) {
      final reactions =
          ref.read(_roomReactionsProvider(widget.clubId).notifier);
      final now = DateTime.now();
      reactions.state = reactions.state
          .where((r) => now.difference(r.at).inSeconds < 4)
          .toList();
    });
  }

  @override
  void dispose() {
    _reactionCleaner?.cancel();
    _channel.unsubscribe();
    super.dispose();
  }

  void _joinChannel() {
    final client = ref.read(supabaseClientProvider);
    final me = client.auth.currentUser;

    _channel = client
        .channel('reading_room:${widget.clubId}')
        .onPresenceSync((_) {})
        .onBroadcast(
          event: 'reaction',
          callback: (payload) {
            // Ignora as próprias reações (já mostradas localmente)
            if (payload['user_id'] == me?.id) return;
            final reaction = _RoomReaction(
              emoji: payload['emoji'] as String,
              fromName: payload['name'] as String? ?? '…',
            );
            ref
                .read(_roomReactionsProvider(widget.clubId).notifier)
                .state = [
              ...ref.read(_roomReactionsProvider(widget.clubId)),
              reaction,
            ];
          },
        )
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _channel.track({
          'user_id': me?.id,
          'name': me?.userMetadata?['name'] ?? 'Leitor',
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _sendReaction(String emoji) {
    final me = ref.read(supabaseClientProvider).auth.currentUser;
    final name = me?.userMetadata?['name'] as String? ?? 'Você';

    // Broadcast efêmero — não insere no banco
    _channel.sendBroadcastMessage(
      event: 'reaction',
      payload: {
        'emoji': emoji,
        'name': name,
        'user_id': me?.id,
      },
    );

    // Exibe localmente imediatamente
    ref.read(_roomReactionsProvider(widget.clubId).notifier).state = [
      ...ref.read(_roomReactionsProvider(widget.clubId)),
      _RoomReaction(emoji: emoji, fromName: 'Você'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final readingAsync = ref.watch(_readingNowProvider(widget.clubId));
    final reactions = ref.watch(_roomReactionsProvider(widget.clubId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📖 Sala de Leitura',
              style: AppTextStyles.titleMedium
                  .copyWith(color: cs.onSurface, fontSize: 16),
            ),
            Text(
              widget.clubName,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // ── Lista de leitores ──────────────────────────────────────────
          readingAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Erro: $e')),
            data: (readers) => readers.isEmpty
                ? _EmptyRoom(surfaceColor: surfaceColor, borderColor: borderColor)
                : _ReadersList(
                    readers: readers,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  ),
          ),

          // ── Reações flutuantes ─────────────────────────────────────────
          if (reactions.isNotEmpty)
            Positioned(
              top: 24,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: reactions
                    .take(5)
                    .map((r) => _FloatingReaction(reaction: r))
                    .toList(),
              ),
            ),

          // ── Barra de reações na parte inferior ────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ReactionBar(
              options: _reactionOptions,
              onReact: _sendReaction,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sala vazia ────────────────────────────────────────────────────────────────

class _EmptyRoom extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;

  const _EmptyRoom({required this.surfaceColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: const Icon(Icons.menu_book_outlined, size: 32,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'Sala silenciosa',
              style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Ninguém está lendo agora.\nAbra um livro e apareça aqui.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de leitores ─────────────────────────────────────────────────────────

class _ReadersList extends StatelessWidget {
  final List<ClubReadingNowEntry> readers;
  final Color surfaceColor;
  final Color borderColor;

  const _ReadersList({
    required this.readers,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${readers.length} ${readers.length == 1 ? 'pessoa lendo' : 'pessoas lendo'} agora',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            itemCount: readers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ReaderCard(
              entry: readers[i],
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              cs: cs,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Card de um leitor ─────────────────────────────────────────────────────────

class _ReaderCard extends StatelessWidget {
  final ClubReadingNowEntry entry;
  final Color surfaceColor;
  final Color borderColor;
  final ColorScheme cs;

  const _ReaderCard({
    required this.entry,
    required this.surfaceColor,
    required this.borderColor,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Avatar + indicador verde
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.forestGreen.withValues(alpha: 0.15),
                backgroundImage: entry.avatarUrl != null
                    ? NetworkImage(entry.avatarUrl!)
                    : null,
                child: entry.avatarUrl == null
                    ? Text(
                        (entry.userName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.forestGreen),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: surfaceColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Nome + tempo + página
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName ?? 'Leitor',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: cs.onSurface, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      entry.elapsedLabel,
                      style: AppTextStyles.labelMedium,
                    ),
                    if (entry.currentPage != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.bookmark_outline,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'pág. ${entry.currentPage}',
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reação flutuante ──────────────────────────────────────────────────────────

class _FloatingReaction extends StatelessWidget {
  final _RoomReaction reaction;

  const _FloatingReaction({required this.reaction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reaction.fromName,
              style: AppTextStyles.labelMedium.copyWith(fontSize: 10)),
          const SizedBox(width: 4),
          Text(reaction.emoji, style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}

// ── Barra de reações ──────────────────────────────────────────────────────────

class _ReactionBar extends StatelessWidget {
  final List<String> options;
  final void Function(String) onReact;
  final Color surfaceColor;
  final Color borderColor;

  const _ReactionBar({
    required this.options,
    required this.onReact,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ambiente silencioso — apenas reações',
            style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options
                .map(
                  (emoji) => GestureDetector(
                    onTap: () => onReact(emoji),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
