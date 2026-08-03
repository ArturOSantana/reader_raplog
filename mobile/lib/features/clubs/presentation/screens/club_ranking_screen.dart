import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClubRankingScreen
//
// Tela de Classificações do clube.
// Duas abas: "Geral do clube" (histórico todo) e "Este livro" (ciclo atual).
// Métrica: dias distintos com ao menos 1 check-in — nunca páginas/minutos.
// Referência de design: lumen-clube-classificacoes.html
// Lógica aprovada: lumen-clube-pontuacao-logica.md
// ─────────────────────────────────────────────────────────────────────────────

class ClubRankingScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final bool hasCurrentBook;
  final DateTime? bookStartedAt;

  const ClubRankingScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.hasCurrentBook = false,
    this.bookStartedAt,
  });

  @override
  ConsumerState<ClubRankingScreen> createState() => _ClubRankingScreenState();
}

class _ClubRankingScreenState extends ConsumerState<ClubRankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // "Este livro" só aparece se o clube tiver livro em leitura
    _tabs = TabController(
      length: widget.hasCurrentBook ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classificações',
              style: LumenType.bookTitle(size: 18, color: theme.colorScheme.onSurface),
            ),
            Text(
              widget.clubName,
              style: LumenType.mono(
                size: 10,
                color: LumenColors.inkMuted,
              ).copyWith(letterSpacing: 0.6),
            ),
          ],
        ),
        bottom: widget.hasCurrentBook
            ? TabBar(
                controller: _tabs,
                labelStyle: LumenType.mono(size: 11, color: LumenColors.ink),
                unselectedLabelStyle:
                    LumenType.mono(size: 11, color: LumenColors.inkMuted),
                labelColor: LumenColors.ink,
                unselectedLabelColor: LumenColors.inkGhost,
                indicatorColor: LumenColors.ink,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 1.5,
                dividerColor: theme.dividerColor,
                tabs: const [
                  Tab(text: 'Geral do clube'),
                  Tab(text: 'Este livro'),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: theme.dividerColor),
              ),
      ),
      body: widget.hasCurrentBook
          ? TabBarView(
              controller: _tabs,
              children: [
                _RankingList(
                  clubId: widget.clubId,
                  scope: 'all',
                  bookStartedAt: null,
                ),
                _RankingList(
                  clubId: widget.clubId,
                  scope: 'current_book',
                  bookStartedAt: widget.bookStartedAt,
                ),
              ],
            )
          : _RankingList(
              clubId: widget.clubId,
              scope: 'all',
              bookStartedAt: null,
            ),
    );
  }
}

// ── Lista de ranking ──────────────────────────────────────────────────────────

class _RankingList extends ConsumerWidget {
  final String clubId;
  final String scope;
  final DateTime? bookStartedAt;

  const _RankingList({
    required this.clubId,
    required this.scope,
    required this.bookStartedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;

    final rankingAsync = ref.watch(clubCheckinRankingProvider((
      clubId: clubId,
      scope: scope,
      bookStartedAt: bookStartedAt,
    )));

    return rankingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (_, __) => const Center(
        child: Text('Não foi possível carregar as classificações.'),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(LumenSpace.huge),
              child: Text(
                'Nenhum check-in registrado ainda.',
                style: LumenType.mono(size: 12, color: LumenColors.inkGhost),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: LumenSpace.lg,
            vertical: LumenSpace.md,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => _RankRow(
            entry: entries[i],
            isCurrentUser: entries[i].userId == currentUserId,
          ),
        );
      },
    );
  }
}

// ── Linha de ranking ──────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final ClubCheckinRankingEntry entry;
  final bool isCurrentUser;

  const _RankRow({required this.entry, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop3 = entry.position <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Posição — Fraunces, top 3 em destaque
          SizedBox(
            width: 22,
            child: Text(
              '${entry.position}',
              style: LumenType.bookTitle(
                size: isTop3 ? 17 : 15,
                weight: isTop3 ? FontWeight.w500 : FontWeight.w400,
                color: isTop3
                    ? theme.colorScheme.onSurface
                    : LumenColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar simples — sem anel, sem cor de posição
          CircleAvatar(
            radius: 16,
            backgroundColor: LumenColors.divider,
            backgroundImage: entry.avatarUrl != null
                ? NetworkImage(entry.avatarUrl!)
                : null,
            child: entry.avatarUrl == null
                ? Text(
                    (entry.userName ?? '?').characters.first.toUpperCase(),
                    style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Nome
          Expanded(
            child: Text(
              isCurrentUser ? 'Você' : (entry.userName ?? 'Leitor'),
              style: LumenType.mono(
                size: 13,
                color: isCurrentUser
                    ? LumenColors.read
                    : theme.colorScheme.onSurface,
                weight: isCurrentUser ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // Pontuação — número bold + label ghost
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${entry.checkinDays} ',
                style: LumenType.mono(
                  size: 12,
                  color: theme.colorScheme.onSurface,
                  weight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: entry.checkinDays == 1 ? 'check-in' : 'check-ins',
                style: LumenType.mono(size: 11, color: LumenColors.inkGhost),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
