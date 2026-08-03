import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _momentConfirmationsProvider =
    FutureProvider.family<int, String>((ref, clubId) {
  return ref
      .read(bookClubRepositoryProvider)
      .getMomentConfirmationsToday(clubId);
});

final _userConfirmedMomentProvider =
    FutureProvider.family<bool, String>((ref, clubId) {
  return ref
      .read(bookClubRepositoryProvider)
      .userConfirmedMomentToday(clubId);
});

// ── Widget: Momento do Clube (linha editorial) ─────────────────────────────────
//
// Inserido na BookClubDetailScreen quando reading_moment_active = true.
// Sem Container colorido, sem FilledButton preenchido, sem ícone Material.
// Conceito: momento coletivo no horário habitual — parte do loop de hábito.

class ClubMomentBanner extends ConsumerWidget {
  final String clubId;
  final String? momentTime;   // ex: "21:00"
  final String? momentLabel;  // ex: "Momento do Livro"

  const ClubMomentBanner({
    super.key,
    required this.clubId,
    this.momentTime,
    this.momentLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmAsync = ref.watch(_momentConfirmationsProvider(clubId));
    final confirmedAsync = ref.watch(_userConfirmedMomentProvider(clubId));

    final confirmCount = confirmAsync.valueOrNull ?? 0;
    final userConfirmed = confirmedAsync.valueOrNull ?? false;

    final muted = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final ink   = isDark ? LumenColors.inkInverse       : LumenColors.ink;

    // Sub-legenda: "Hoje às 21h · 3 confirmações" ou "3 membros confirmaram hoje"
    final String sublabel;
    if (momentTime != null) {
      final suffix = confirmCount == 1 ? '1 confirmação' : '$confirmCount confirmações';
      sublabel = 'Hoje às $momentTime · $suffix';
    } else {
      sublabel = confirmCount == 1
          ? '1 membro confirmou hoje'
          : '$confirmCount membros confirmaram hoje';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Ponto de presença — mesmo vocabulário do ClubPresenceStrip
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8, top: 3),
            decoration: BoxDecoration(
              color: LumenColors.read,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (momentLabel ?? 'Momento do Clube').toUpperCase(),
                  style: LumenType.kicker(size: 10, color: LumenColors.read)
                      .copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: LumenType.mono(size: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // CTA como link textual — sem botão preenchido
          if (!userConfirmed)
            GestureDetector(
              onTap: () async {
                await ref
                    .read(bookClubRepositoryProvider)
                    .confirmReadingMoment(clubId);
                ref.invalidate(_momentConfirmationsProvider(clubId));
                ref.invalidate(_userConfirmedMomentProvider(clubId));
              },
              child: Text(
                'Confirmar leitura',
                style: LumenType.mono(
                  size: 12,
                  color: ink,
                  weight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              'Confirmado.',
              style: LumenType.mono(size: 12, color: muted),
            ),
        ],
      ),
    );
  }
}
