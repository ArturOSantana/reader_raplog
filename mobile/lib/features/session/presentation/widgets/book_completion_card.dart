import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';

/// Card capturado como PNG ao finalizar um livro.
/// Segue a identidade "ficha de biblioteca" do ReadLog:
/// fundo ink, tipografia Fraunces + IBM Plex Mono, carimbo de conclusão.
class BookCompletionCard extends StatelessWidget {
  final Book book;
  final int totalMinutes;
  final int totalSessions;
  final String? review;

  const BookCompletionCard({
    super.key,
    required this.book,
    required this.totalMinutes,
    required this.totalSessions,
    this.review,
  });

  String get _timeLabel {
    if (totalMinutes < 60) return '${totalMinutes}min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String get _pagesLabel {
    if (book.totalPages != null) return '${book.totalPages}';
    if (book.currentPage != null) return '${book.currentPage}';
    return '—';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _dateLabel {
    final d = book.endDate ?? DateTime.now();
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fundo: ink com textura de papel sutil ────────────────
          Container(color: LumenColors.ink),

          // ── Faixa lateral esquerda — lombada do livro ─────────────
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: const BoxDecoration(
                color: LumenColors.stamp,
              ),
            ),
          ),

          // ── Marca d'água: borda interna discreta ──────────────────
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: LumenColors.cream.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha superior: badge + marca
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge "Livro concluído" — estilo carimbo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: LumenColors.stamp.withValues(alpha: 0.7)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'LIVRO CONCLUÍDO',
                        style: LumenType.mono(
                          size: 9,
                          weight: FontWeight.w600,
                          color: LumenColors.stamp,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                    ),
                    const Spacer(),
                    // Carimbo de conclusão rotacionado
                    Transform.rotate(
                      angle: -0.12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ReadLog',
                            style: LumenType.display(
                              size: 11,
                              color: LumenColors.brassLight
                                  .withValues(alpha: 0.6),
                            ).copyWith(letterSpacing: 1.6),
                          ),
                          Container(
                            width: 44,
                            height: 1,
                            color:
                                LumenColors.brassLight.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Título
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: LumenType.display(
                    size: 26,
                    weight: FontWeight.w600,
                    color: LumenColors.cream,
                  ).copyWith(height: 1.2),
                ),

                if (book.author != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    book.author!,
                    style: LumenType.mono(
                      size: 12,
                      color: LumenColors.cream.withValues(alpha: 0.5),
                    ),
                  ),
                ],

                // Estrelas
                if (book.rating != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < book.rating!;
                      return Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 18,
                          color: filled
                              ? LumenColors.brass
                              : LumenColors.cream.withValues(alpha: 0.2),
                        ),
                      );
                    }),
                  ),
                ],

                // Resenha — estilo nota de rodapé em itálico
                if (review != null && review!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 2,
                        height: null,
                        color: LumenColors.brass.withValues(alpha: 0.5),
                        margin: const EdgeInsets.only(right: 10),
                      ),
                      Expanded(
                        child: Text(
                          '"$review"',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: LumenType.display(
                            size: 12,
                            weight: FontWeight.w300,
                            italic: true,
                            color:
                                LumenColors.cream.withValues(alpha: 0.65),
                          ).copyWith(height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(),

                // Divisória tracejada — régua de sumário
                _DashedDivider(
                    color: LumenColors.cream.withValues(alpha: 0.15)),
                const SizedBox(height: 18),

                // Estatísticas em réguas de sumário (leader rows)
                _CardLeaderRow(
                  label: 'Tempo de leitura',
                  value: _timeLabel,
                ),
                const SizedBox(height: 6),
                _CardLeaderRow(
                  label: 'Páginas',
                  value: _pagesLabel,
                ),
                const SizedBox(height: 6),
                _CardLeaderRow(
                  label: 'Sessões',
                  value: '$totalSessions',
                ),

                const SizedBox(height: 16),

                // Data — rodapé
                Text(
                  'Concluído em $_dateLabel',
                  style: LumenType.mono(
                    size: 10,
                    color: LumenColors.cream.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha "label ........ valor" ao estilo sumário de livro, para uso interno
/// nos cards PNG (usa cores fixas, independente do tema).
class _CardLeaderRow extends StatelessWidget {
  final String label;
  final String value;

  const _CardLeaderRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: LumenType.mono(
              size: 11,
              color: LumenColors.cream.withValues(alpha: 0.5)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: CustomPaint(
              painter: _DotsPainter(
                  color: LumenColors.cream.withValues(alpha: 0.18)),
              size: const Size(double.infinity, 1),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: LumenType.mono(
            size: 13,
            weight: FontWeight.w600,
            color: LumenColors.brassLight,
          ),
        ),
      ],
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
