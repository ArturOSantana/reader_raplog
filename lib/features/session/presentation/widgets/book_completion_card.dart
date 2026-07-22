import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';

/// Card bonito que é capturado como PNG e compartilhado ao finalizar um livro.
/// Renderiza em tamanho fixo (1080×1350 virtuais) escalonado para caber na tela.
class BookCompletionCard extends StatelessWidget {
  final Book book;

  /// Total de minutos lidos somando todas as sessões do livro.
  final int totalMinutes;

  /// Número total de sessões de leitura registradas para o livro.
  final int totalSessions;

  /// Resenha escrita pelo usuário (opcional).
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
    if (book.totalPages != null) return '${book.totalPages} págs.';
    if (book.currentPage != null) return '${book.currentPage} págs.';
    return '—';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _dateLabel {
    final d = book.endDate ?? DateTime.now();
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // O card será capturado em 400×500 logical pixels
    return SizedBox(
      width: 400,
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo degradê escuro
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F1A14),
            ),
          ),

          // Detalhe decorativo superior
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forestGreen.withValues(alpha: 0.18),
              ),
            ),
          ),

          // Detalhe decorativo inferior
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warmGold.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Conteúdo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — badge "Livro lido"
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.warmGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.warmGold.withValues(alpha: 0.6)),
                      ),
                      child: const Text(
                        '✓  Livro concluído',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warmGoldLight,
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

                const SizedBox(height: 28),

                // Título do livro
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppColors.darkTextPrimary,
                  ),
                ),

                if (book.author != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    book.author!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],

                // Estrelas
                if (book.rating != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < book.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 20,
                        color: i < book.rating!
                            ? AppColors.warmGold
                            : AppColors.darkBorder,
                      );
                    }),
                  ),
                ],

                // Resenha
                if (review != null && review!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.forestGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '"$review"',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Divisória
                Container(height: 1, color: AppColors.darkBorder),
                const SizedBox(height: 20),

                // Estatísticas em 3 colunas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Stat(label: 'TEMPO', value: _timeLabel),
                    _Stat(label: 'PÁGINAS', value: _pagesLabel),
                    _Stat(label: 'SESSÕES', value: '$totalSessions'),
                  ],
                ),

                const SizedBox(height: 20),

                // Data de conclusão
                Text(
                  'Concluído em $_dateLabel',
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
        ),
      ],
    );
  }
}
