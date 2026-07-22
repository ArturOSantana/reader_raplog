import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';

/// Card gerado em memória (via ScreenshotController) para compartilhamento.
/// Sempre renderizado com tema claro, independente do tema do sistema.
class BookShareCard extends StatelessWidget {
  final Book book;

  const BookShareCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final progress = (book.currentPage != null && book.totalPages != null)
        ? (book.currentPage! / book.totalPages!).clamp(0.0, 1.0)
        : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: capa + título + autor
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverBox(book: book),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.author!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFFB8D4C0),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _StatusChip(status: book.status),
                      if (book.rating != null) ...[
                        const SizedBox(height: 8),
                        _StarRow(rating: book.rating!),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Barra de progresso
            if (progress != null) ...[
              const SizedBox(height: 20),
              _ProgressSection(
                current: book.currentPage!,
                total: book.totalPages!,
                progress: progress,
              ),
            ],

            // Rodapé
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2D5442), thickness: 1),
            const SizedBox(height: 10),
            const Text(
              'ReadLog',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warmGoldLight,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverBox extends StatelessWidget {
  final Book book;

  const _CoverBox({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF2D5442),
        borderRadius: BorderRadius.circular(8),
      ),
      child: book.coverUrl != null && book.coverUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                book.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _FallbackCoverIcon(),
              ),
            )
          : const _FallbackCoverIcon(),
    );
  }
}

class _FallbackCoverIcon extends StatelessWidget {
  const _FallbackCoverIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.menu_book_outlined, color: Color(0xFF7FAF95), size: 32),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BookStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warmGold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.warmGoldLight,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;

  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < rating ? AppColors.warmGoldLight : const Color(0xFF4A7A5E),
        );
      }),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final int current;
  final int total;
  final double progress;

  const _ProgressSection({
    required this.current,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progresso',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF8FC4A8),
              ),
            ),
            Text(
              '$current / $total pág. · $percent%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: const Color(0xFF2D5442),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warmGoldLight),
          ),
        ),
      ],
    );
  }
}
