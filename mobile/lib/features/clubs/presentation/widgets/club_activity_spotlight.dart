import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/club_extras.dart';
import '../../../../shared/providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClubActivitySpotlight
//
// Mostra quem está mais ativo no clube em dois recortes:
//   • Livro atual  — "mais ativo nessa leitura"  (period: current_book)
//   • All-time     — "mais ativo no clube"        (period: all)
//
// Critério: sessions (presença/engajamento, não volume de páginas).
// Sem posição numérica para além do top-3 — visual de atividade, não ranking.
// ─────────────────────────────────────────────────────────────────────────────

class ClubActivitySpotlight extends ConsumerStatefulWidget {
  final String clubId;
  final bool hasCurrentBook;

  const ClubActivitySpotlight({
    super.key,
    required this.clubId,
    this.hasCurrentBook = false,
  });

  @override
  ConsumerState<ClubActivitySpotlight> createState() =>
      _ClubActivitySpotlightState();
}

class _ClubActivitySpotlightState extends ConsumerState<ClubActivitySpotlight> {
  // 'current_book' só aparece se o clube tiver livro ativo
  late String _period;

  @override
  void initState() {
    super.initState();
    _period = widget.hasCurrentBook ? 'current_book' : 'all';
  }

  @override
  Widget build(BuildContext context) {
    final rankingAsync =
        ref.watch(clubRankingProvider((widget.clubId, _period)));

    return rankingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        // Oculta se só tem 1 membro (sem comparação possível)
        if (entries.length == 1) return const SizedBox.shrink();
        return _SpotlightBody(
          clubId: widget.clubId,
          entries: entries,
          period: _period,
          hasCurrentBook: widget.hasCurrentBook,
          onPeriodChanged: widget.hasCurrentBook
              ? (p) => setState(() => _period = p)
              : null,
        );
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SpotlightBody extends StatelessWidget {
  final String clubId;
  final List<ClubRankingEntry> entries;
  final String period;
  final bool hasCurrentBook;
  final void Function(String)? onPeriodChanged;

  const _SpotlightBody({
    required this.clubId,
    required this.entries,
    required this.period,
    required this.hasCurrentBook,
    this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).take(5).toList(); // máx. 5 extras

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho + toggle ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'MAIS ATIVOS',
              style: LumenType.mono(
                size: 10,
                color: LumenColors.inkMuted,
              ).copyWith(letterSpacing: 1.4),
            ),
            if (hasCurrentBook && onPeriodChanged != null)
              _PeriodToggle(
                current: period,
                onChanged: onPeriodChanged!,
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Subtítulo descritivo
        Text(
          period == 'current_book'
              ? 'Nessa leitura'
              : 'No clube, desde sempre',
          style: LumenType.mono(
            size: 11,
            color: LumenColors.inkGhost,
          ),
        ),
        const SizedBox(height: 14),

        // ── Top 3 com destaque ─────────────────────────────────────────
        ...top3.asMap().entries.map((e) => _TopRow(
              entry: e.value,
              index: e.key,
              isFirst: e.key == 0,
            )),

        // ── Demais membros (sem posição) ───────────────────────────────
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: LumenColors.hairline),
          const SizedBox(height: 6),
          ...rest.map((e) => _RestRow(entry: e)),
        ],
      ],
    );
  }
}

// ── Toggle período ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _PeriodToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleLabel(
          label: 'Livro',
          selected: current == 'current_book',
          onTap: () => onChanged('current_book'),
        ),
        const SizedBox(width: 12),
        _ToggleLabel(
          label: 'Clube',
          selected: current == 'all',
          onTap: () => onChanged('all'),
        ),
      ],
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: LumenType.mono(
          size: 11,
          color: selected ? LumenColors.ink : LumenColors.inkGhost,
          weight: selected ? FontWeight.w600 : FontWeight.w400,
        ).copyWith(
          decoration: selected ? TextDecoration.underline : null,
          decorationColor: LumenColors.inkMuted,
        ),
      ),
    );
  }
}

// ── Linha Top 3 ───────────────────────────────────────────────────────────────

class _TopRow extends StatelessWidget {
  final ClubRankingEntry entry;
  final int index;
  final bool isFirst;

  const _TopRow({
    required this.entry,
    required this.index,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final sessionLabel = entry.totalSessions == 1
        ? '1 sessão'
        : '${entry.totalSessions} sessões';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Marcador: ponto cheio para 1º, linha para os demais
              SizedBox(
                width: 14,
                child: isFirst
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: LumenColors.read,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: LumenColors.inkGhost,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
              Text(
                entry.userName ?? 'Leitor',
                style: LumenType.mono(
                  size: 13,
                  color: isFirst ? LumenColors.ink : LumenColors.inkMuted,
                  weight: isFirst ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
          Text(
            sessionLabel,
            style: LumenType.mono(
              size: 11,
              color: LumenColors.inkGhost,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Linha restante (sem destaque) ─────────────────────────────────────────────

class _RestRow extends StatelessWidget {
  final ClubRankingEntry entry;

  const _RestRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            entry.userName ?? 'Leitor',
            style: LumenType.mono(
              size: 12,
              color: LumenColors.inkGhost,
            ),
          ),
          Text(
            '${entry.totalSessions} sessões',
            style: LumenType.mono(
              size: 11,
              color: LumenColors.inkGhost,
            ),
          ),
        ],
      ),
    );
  }
}
