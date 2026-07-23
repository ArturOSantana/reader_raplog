import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
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

// ── Widget: Banner do Momento do Clube ────────────────────────────────────────
// Inserido na BookClubDetailScreen quando reading_moment_active = true.

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmAsync = ref.watch(_momentConfirmationsProvider(clubId));
    final confirmedAsync = ref.watch(_userConfirmedMomentProvider(clubId));

    final confirmCount = confirmAsync.valueOrNull ?? 0;
    final userConfirmed = confirmedAsync.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.forestGreen.withValues(alpha: 0.12)
            : AppColors.forestGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.forestGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 22, color: AppColors.forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  momentLabel ?? 'Momento do Clube',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  momentTime != null
                      ? 'Hoje às $momentTime · $confirmCount ${confirmCount == 1 ? "confirmação" : "confirmações"}'
                      : '$confirmCount ${confirmCount == 1 ? "membro confirmou" : "membros confirmaram"} hoje',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          userConfirmed
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 14, color: AppColors.forestGreen),
                      const SizedBox(width: 4),
                      Text('Confirmado',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestGreen)),
                    ],
                  ),
                )
              : FilledButton(
                  onPressed: () async {
                    await ref
                        .read(bookClubRepositoryProvider)
                        .confirmReadingMoment(clubId);
                    ref.invalidate(_momentConfirmationsProvider(clubId));
                    ref.invalidate(_userConfirmedMomentProvider(clubId));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Confirmar',
                      style: TextStyle(fontSize: 12)),
                ),
        ],
      ),
    );
  }
}
