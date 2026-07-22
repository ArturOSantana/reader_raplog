import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/goal.dart';

/// Card escuro (400×500) capturável como PNG ao atingir uma meta.
/// Segue o mesmo estilo visual do [BookCompletionCard].
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
          // Fundo escuro
          Container(color: const Color(0xFF0F1A14)),

          // Círculo decorativo superior direito
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warmGold.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Círculo decorativo inferior esquerdo
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forestGreen.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Conteúdo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge + marca
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.forestGreen.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppColors.forestGreen.withValues(alpha: 0.7)),
                      ),
                      child: const Text(
                        '🎯  Meta atingida!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7DD4A0),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'ReadLog',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkTextSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Tipo de meta
                Text(
                  goal.type.label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkTextSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),

                // Valor atual em destaque
                Text(
                  '$currentValue',
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: AppColors.darkTextPrimary,
                  ),
                ),

                Text(
                  '${goal.type.unit} $_periodLabel',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: AppColors.darkTextSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Barra de progresso 100 %
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 8,
                    backgroundColor: AppColors.darkBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50)),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meta: ${goal.targetValue} ${goal.type.unit}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const Text(
                      '100 %',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Divisória
                Container(height: 1, color: AppColors.darkBorder),
                const SizedBox(height: 16),

                Text(
                  'Concluída em $_dateLabel',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
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
