import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/goal.dart';

/// Card capturado como PNG ao atingir uma meta.
/// Segue a identidade "ficha de biblioteca" do ReadLog.
class GoalAchievementCard extends StatelessWidget {
  final Goal goal;
  final int currentValue;

  const GoalAchievementCard({
    super.key,
    required this.goal,
    required this.currentValue,
  });

  String get _periodLabel {
    switch (goal.period) {
      case GoalPeriod.daily:
        return 'hoje';
      case GoalPeriod.weekly:
        return 'esta semana';
      case GoalPeriod.monthly:
        return 'este mês';
      case GoalPeriod.yearly:
        return 'este ano';
    }
  }

  String get _dateLabel {
    final d = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fundo ink ───────────────────────────────────────────
          Container(color: LumenColors.ink),

          // ── Faixa lateral — cor sage para metas ──────────────────
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              color: LumenColors.sage,
            ),
          ),

          // ── Borda interna discreta ────────────────────────────────
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
                // Header: badge + marca
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: LumenColors.sage.withValues(alpha: 0.7)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'MISSÃO CONCLUÍDA',
                        style: LumenType.mono(
                          size: 9,
                          weight: FontWeight.w600,
                          color: LumenColors.sage,
                        ).copyWith(letterSpacing: 1.4),
                      ),
                    ),
                    const Spacer(),
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
                            color: LumenColors.brassLight
                                .withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Tipo de meta — mono pequeno
                Text(
                  goal.type.label.toUpperCase(),
                  style: LumenType.mono(
                    size: 10,
                    color: LumenColors.sage,
                  ).copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: 10),

                // Valor em destaque — Fraunces grande
                Text(
                  '$currentValue',
                  style: LumenType.display(
                    size: 72,
                    weight: FontWeight.w600,
                    color: LumenColors.cream,
                  ).copyWith(height: 0.9),
                ),

                Text(
                  '${goal.type.unit} $_periodLabel',
                  style: LumenType.mono(
                    size: 14,
                    color: LumenColors.cream.withValues(alpha: 0.55),
                  ),
                ),

                const SizedBox(height: 28),

                // Barra de progresso 100% — stamp
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 5,
                    backgroundColor:
                        LumenColors.cream.withValues(alpha: 0.1),
                    color: LumenColors.stamp,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Missão: ${goal.targetValue} ${goal.type.unit}',
                      style: LumenType.mono(
                        size: 10,
                        color: LumenColors.cream.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      '100%',
                      style: LumenType.mono(
                        size: 10,
                        weight: FontWeight.w600,
                        color: LumenColors.stamp,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Divisória tracejada
                _DashedDivider(
                    color: LumenColors.cream.withValues(alpha: 0.15)),
                const SizedBox(height: 16),

                // Data de conclusão
                Text(
                  'Concluída em $_dateLabel',
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
