import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../data/inspiration_quotes.dart';

/// Card de "Inspiração do Dia" exibido como bottom-sheet ou dialog in-app.
///
/// Layout:
///   título contextual (emoji + rótulo)
///   ─────────────────────────────
///   "frase entre aspas"
///   — Autor (se houver)
///   ─────────────────────────────
///   subtítulo opcional (ex.: "20 dias consecutivos")
class InspirationCard extends StatelessWidget {
  final InspirationQuote quote;

  /// Título principal exibido acima da linha — ex.: "Ofensiva mantida!"
  final String title;

  /// Subtítulo opcional — ex.: "20 dias consecutivos"
  final String? subtitle;

  /// Texto de encerramento — ex.: "Continue assim."
  final String? closing;

  const InspirationCard({
    super.key,
    required this.quote,
    required this.title,
    this.subtitle,
    this.closing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: ReadLogColors.ink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Faixa lateral — lombada
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6,
              decoration: const BoxDecoration(
                color: ReadLogColors.brass,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ────────────────────────────────────────────────
                Text(
                  title,
                  style: ReadLogType.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: ReadLogColors.brass,
                  ).copyWith(letterSpacing: 1.2),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: ReadLogType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: ReadLogColors.cream,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Divisória ─────────────────────────────────────────────
                _DashedLine(color: ReadLogColors.cream.withValues(alpha: 0.15)),

                const SizedBox(height: 16),

                // ── Frase ─────────────────────────────────────────────────
                Text(
                  '\u201c${quote.quote}\u201d',
                  style: ReadLogType.display(
                    size: 15,
                    weight: FontWeight.w400,
                    italic: true,
                    color: ReadLogColors.cream,
                  ).copyWith(height: 1.55),
                ),

                if (quote.author != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '— ${quote.author}',
                    style: ReadLogType.mono(
                      size: 11,
                      color: ReadLogColors.cream.withValues(alpha: 0.5),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Divisória ─────────────────────────────────────────────
                _DashedLine(color: ReadLogColors.cream.withValues(alpha: 0.15)),

                if (closing != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    closing!,
                    style: ReadLogType.mono(
                      size: 11,
                      color: ReadLogColors.brassLight,
                    ).copyWith(letterSpacing: 0.6),
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

// ── Bottom-sheet wrapper ──────────────────────────────────────────────────────

/// Exibe um [InspirationCard] como bottom-sheet com botão de fechar.
class InspirationBottomSheet extends StatelessWidget {
  final InspirationQuote quote;
  final String title;
  final String? subtitle;
  final String? closing;

  const InspirationBottomSheet({
    super.key,
    required this.quote,
    required this.title,
    this.subtitle,
    this.closing,
  });

  /// Abre o bottom-sheet de forma estática.
  static void show(
    BuildContext context, {
    required InspirationQuote quote,
    required String title,
    String? subtitle,
    String? closing,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReadLogColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InspirationBottomSheet(
        quote: quote,
        title: title,
        subtitle: subtitle,
        closing: closing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alça
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: ReadLogColors.cream.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            InspirationCard(
              quote: quote,
              title: title,
              subtitle: subtitle,
              closing: closing,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: ReadLogColors.brassLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Continuar lendo',
                  style: ReadLogType.mono(
                    size: 13,
                    weight: FontWeight.w600,
                    color: ReadLogColors.brassLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(color: color), size: const Size(double.infinity, 1));
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), paint);
      x += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
