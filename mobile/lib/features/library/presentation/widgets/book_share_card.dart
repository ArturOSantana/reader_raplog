import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';

/// Card PNG de compartilhamento de livro.
/// Visual "ficha de catálogo": fundo paper envelhecido, aba lateral colorida
/// por status, tipografia Fraunces + IBM Plex Mono, progresso em stamp.
class BookShareCard extends StatelessWidget {
  final Book book;

  const BookShareCard({super.key, required this.book});

  Color get _tabColor {
    switch (book.status) {
      case BookStatus.reading:
        return LumenColors.brass;
      case BookStatus.wantToRead:
        return LumenColors.sage;
      case BookStatus.read:
        return LumenColors.stamp;
      case BookStatus.abandoned:
        return LumenColors.charcoal.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (book.currentPage != null && book.totalPages != null)
        ? (book.currentPage! / book.totalPages!).clamp(0.0, 1.0)
        : null;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 360,
        child: Stack(
          children: [
            // ── Fundo paper ─────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: LumenColors.paper,
              ),
            ),

            // ── Aba lateral colorida por status ──────────────────────
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 8, color: _tabColor),
            ),

            // ── Conteúdo ─────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: capa + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CoverBox(book: book),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        _tabColor.withValues(alpha: 0.7)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                book.status.label.toUpperCase(),
                                style: LumenType.mono(
                                  size: 8,
                                  weight: FontWeight.w600,
                                  color: _tabColor,
                                ).copyWith(letterSpacing: 1.2),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Título
                            Text(
                              book.title,
                              style: LumenType.display(
                                size: 17,
                                weight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark ? LumenColors.inkInverse : LumenColors.charcoal,
                              ).copyWith(height: 1.25),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (book.author != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                book.author!,
                                style: LumenType.mono(
                                  size: 11,
                                  color: LumenColors.charcoal
                                      .withValues(alpha: 0.5),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            // Estrelas
                            if (book.rating != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(5, (i) {
                                  final filled = i < book.rating!;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Icon(
                                      filled
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 15,
                                      color: filled
                                          ? LumenColors.brass
                                          : LumenColors.charcoal
                                              .withValues(alpha: 0.2),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Barra de progresso com régua de sumário
                  if (progress != null) ...[
                    const SizedBox(height: 18),
                    _ProgressSection(
                      current: book.currentPage!,
                      total: book.totalPages!,
                      progress: progress,
                    ),
                  ],

                  // Rodapé
                  const SizedBox(height: 18),
                  _DashedDivider(
                      color: LumenColors.charcoal.withValues(alpha: 0.15)),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ReadLog',
                        style: LumenType.display(
                          size: 12,
                          color: LumenColors.brass,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                      Text(
                        _today(),
                        style: LumenType.mono(
                          size: 10,
                          color: LumenColors.charcoal
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _today() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
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
        color: LumenColors.paperDeep,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
            color: LumenColors.charcoal.withValues(alpha: 0.12)),
      ),
      child: book.coverUrl != null && book.coverUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: Image.network(
                book.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _FallbackCover(),
              ),
            )
          : const _FallbackCover(),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_outlined,
        color: LumenColors.charcoal.withValues(alpha: 0.3),
        size: 28,
      ),
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
        // Régua de sumário
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Progresso',
              style: LumenType.mono(
                size: 10,
                color: LumenColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: CustomPaint(
                  painter: _DotsPainter(
                      color: LumenColors.charcoal.withValues(alpha: 0.18)),
                  size: const Size(double.infinity, 1),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$current / $total · $percent%',
              style: LumenType.mono(
                size: 11,
                weight: FontWeight.w600,
                color: LumenColors.charcoal.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: LumenColors.paperDeep,
            color: LumenColors.stamp,
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotsPainter(color: color),
      size: const Size(double.infinity, 1),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 2, 0), paint);
      x += 5;
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.color != color;
}
