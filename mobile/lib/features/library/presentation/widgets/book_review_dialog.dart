import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/providers/providers.dart';
import '../../../session/presentation/widgets/book_completion_card.dart';

/// Abre o bottom sheet de avaliação para livros concluídos.
///
/// Retorna `true` se o usuário salvou e publicou no feed.
Future<bool?> showBookReviewDialog(BuildContext context, Book book) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookReviewSheet(book: book),
  );
}

class _BookReviewSheet extends ConsumerStatefulWidget {
  final Book book;

  const _BookReviewSheet({required this.book});

  @override
  ConsumerState<_BookReviewSheet> createState() => _BookReviewSheetState();
}

class _BookReviewSheetState extends ConsumerState<_BookReviewSheet> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  final _screenshotController = ScreenshotController();
  bool _publishToFeed = true;
  bool _saving = false;

  // Stats de sessão
  int _totalMinutes = 0;
  int _totalSessions = 0;

  @override
  void initState() {
    super.initState();
    _rating = widget.book.rating ?? 0;
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ref
          .read(sessionRepositoryProvider)
          .fetchBookTotalStats(widget.book.id);
      if (mounted) {
        setState(() {
          _totalMinutes = stats['total_minutes'] ?? 0;
          _totalSessions = stats['total_sessions'] ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Salva rating no livro
      await ref
          .read(bookRepositoryProvider)
          .update(widget.book.id, {'rating': _rating > 0 ? _rating : null});

      // Publica no feed social se habilitado
      if (_publishToFeed) {
        await ref.read(socialFeedRepositoryProvider).publishFinishedBook(
              bookTitle: widget.book.title,
              bookAuthor: widget.book.author,
              rating: _rating > 0 ? _rating : null,
              review: _reviewController.text.trim().isNotEmpty
                  ? _reviewController.text.trim()
                  : null,
              readingTimeMinutes: _totalMinutes > 0 ? _totalMinutes : null,
            );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar avaliação: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _shareCard() async {
    try {
      final updatedBook =
          widget.book.copyWith(rating: _rating > 0 ? _rating : null);
      final reviewText = _reviewController.text.trim();
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: BookCompletionCard(
            book: updatedBook,
            totalMinutes: _totalMinutes,
            totalSessions: _totalSessions,
            review: reviewText.isNotEmpty ? reviewText : null,
          ),
        ),
        pixelRatio: 3.0,
      );

      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/readlog_${widget.book.id}.png');
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Terminei de ler ${widget.book.title}!',
          text: 'Acabei de ler "${widget.book.title}"'
              '${widget.book.author != null ? ' de ${widget.book.author}' : ''}'
              '${_rating > 0 ? ' — $_rating/5 estrelas' : ''}'
              '\n\nRegistrado no ReadLog',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar imagem: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedBook =
        widget.book.copyWith(rating: _rating > 0 ? _rating : null);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 8,
          left: 20,
          right: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Text('Avalie sua leitura', style: AppTextStyles.displayMedium),
            const SizedBox(height: 4),
            Text(
              widget.book.title,
              style: AppTextStyles.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            // Estrelas interativas
            Text('Nota', style: AppTextStyles.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 38,
                      color:
                          i < _rating ? AppColors.warmGold : AppColors.border,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Campo de review
            Text('Mini resenha (opcional)', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              maxLength: 280,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'O que você achou do livro?',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.forestGreen, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              style: AppTextStyles.bodyMedium,
            ),

            // Stats de leitura
            if (_totalMinutes > 0) ...[
              const SizedBox(height: 8),
              _StatsRow(minutes: _totalMinutes, sessions: _totalSessions),
            ],

            // Card de preview + botão compartilhar
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Card para redes sociais',
                    style: AppTextStyles.titleMedium),
                TextButton.icon(
                  onPressed: _shareCard,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Compartilhar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 220,
                height: 275,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: BookCompletionCard(
                    book: updatedBook,
                    totalMinutes: _totalMinutes,
                    totalSessions: _totalSessions,
                    review: _reviewController.text.trim().isNotEmpty
                        ? _reviewController.text.trim()
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Toggle: publicar no feed
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                title: Text('Publicar no feed dos amigos',
                    style: AppTextStyles.bodyMedium),
                value: _publishToFeed,
                onChanged: (v) => setState(() => _publishToFeed = v),
                activeTrackColor: AppColors.forestGreen,
              ),
            ),

            const SizedBox(height: 20),

            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar avaliação',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int minutes;
  final int sessions;

  const _StatsRow({required this.minutes, required this.sessions});

  String _timeLabel(int totalMinutes) {
    if (totalMinutes < 60) return '${totalMinutes}min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          label: 'Tempo total: ${_timeLabel(minutes)}',
        ),
        if (sessions > 0)
          _StatChip(
            icon: Icons.auto_stories_outlined,
            label: '$sessions sessões',
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.forestGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.forestGreen),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.forestGreen)),
        ],
      ),
    );
  }
}
