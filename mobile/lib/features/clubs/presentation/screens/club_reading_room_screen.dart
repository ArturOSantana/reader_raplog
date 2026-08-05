import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../theme/lumen_theme.dart';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubReadingRoomScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  /// URL da capa do livro atual — usado para o tint de cor do fundo.
  final String? coverUrl;

  const ClubReadingRoomScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.coverUrl,
  });

  @override
  ConsumerState<ClubReadingRoomScreen> createState() =>
      _ClubReadingRoomScreenState();
}

class _ClubReadingRoomScreenState
    extends ConsumerState<ClubReadingRoomScreen> {
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _joinChannel();
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  void _joinChannel() {
    final client = ref.read(supabaseClientProvider);
    final me = client.auth.currentUser;

    _channel = client
        .channel('reading_room:${widget.clubId}')
        .onPresenceSync((_) {})
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

  @override
  Widget build(BuildContext context) {
    final readingAsync = ref.watch(_readingNowProvider(widget.clubId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ReadLogColors.ink, size: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sala de Leitura',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w600,
              ),
            ),
            Text(
              widget.clubName,
              style: ReadLogType.mono(size: 11, color: ReadLogColors.inkMuted),
            ),
          ],
        ),
      ),
      body: LumenClubTintBackground(
        coverUrl: widget.coverUrl,
        child: readingAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: ReadLogColors.progress),
          ),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (readers) => readers.isEmpty
              ? _EmptyRoom(cs: cs)
              : _ReadersList(readers: readers, clubId: widget.clubId),
        ),
        ),
    );
  }
}

// ── Sala vazia ────────────────────────────────────────────────────────────────

class _EmptyRoom extends StatelessWidget {
  final ColorScheme cs;

  const _EmptyRoom({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '—',
              style: ReadLogType.display(
                size: 42,
                color: ReadLogColors.inkGhost,
                weight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ninguém lendo no momento.',
              style: ReadLogType.mono(
                size: 13,
                color: ReadLogColors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Comece a ler para aparecer aqui.',
              style: ReadLogType.mono(
                size: 11,
                color: ReadLogColors.inkGhost,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de leitores ─────────────────────────────────────────────────────────

class _ReadersList extends ConsumerWidget {
  final List<ClubReadingNowEntry> readers;
  final String clubId;

  const _ReadersList({required this.readers, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(clubCollectiveStatsProvider(clubId));
    final stats = statsAsync.valueOrNull;

    // Total de horas juntos no clube — acumulado disponível no modelo
    String? togetherStat;
    if (stats != null && stats.totalMinutes > 0) {
      final h = stats.minutesToHours;
      togetherStat = '${h}h';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Número grande — protagonismo da presença coletiva
        Text(
          '${readers.length}',
          style: ReadLogType.display(
            size: 52,
            color: ReadLogColors.ink,
            weight: FontWeight.w400,
          ),
        ),
        Text(
          'lendo agora',
          style: ReadLogType.mono(
            size: 11,
            color: ReadLogColors.inkMuted,
          ).copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 32),
        // Lista de presença — separada por Divider, sem card com sombra
        ...readers.expand((r) => [
              _ReaderRow(entry: r),
              const Divider(height: 1, color: ReadLogColors.hairline),
            ]),
        // Stat coletivo — recompensa social que fecha o loop
        if (togetherStat != null) ...[
          const SizedBox(height: 28),
          const Divider(height: 1, color: ReadLogColors.hairline),
          const SizedBox(height: 20),
          Text(
            togetherStat,
            style: ReadLogType.display(
              size: 36,
              color: ReadLogColors.ink,
              weight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'leram juntos no clube',
            style: ReadLogType.mono(
              size: 11,
              color: ReadLogColors.inkMuted,
            ).copyWith(letterSpacing: 0.8),
          ),
        ],
      ],
    );
  }
}

// ── Linha de leitor ───────────────────────────────────────────────────────────

class _ReaderRow extends StatelessWidget {
  final ClubReadingNowEntry entry;

  const _ReaderRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          LumenAvatar(
            name: entry.userName ?? 'Leitor',
            avatarUrl: entry.avatarUrl,
            radius: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.userName ?? 'Leitor',
              style: ReadLogType.display(
                size: 15,
                color: ReadLogColors.ink,
                weight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _elapsed(entry.startedAt),
            style: ReadLogType.mono(
              size: 11,
              color: ReadLogColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _elapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours}h';
  }
}
