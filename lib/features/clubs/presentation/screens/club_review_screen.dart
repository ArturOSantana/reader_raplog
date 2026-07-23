import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_reviews.dart';
import '../../../../shared/providers/providers.dart';

/// Formulário guiado de resenha construtiva.
///
/// Recebe [clubId] e [bookHistoryId] (ciclo de leitura) obrigatórios.
/// Opcionalmente recebe [bookTitle] para exibição e [existing] para pré-preencher
/// ao editar uma resenha já existente.
class ClubReviewScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String bookHistoryId;
  final String bookTitle;
  final ClubReview? existing;

  const ClubReviewScreen({
    super.key,
    required this.clubId,
    required this.bookHistoryId,
    required this.bookTitle,
    this.existing,
  });

  @override
  ConsumerState<ClubReviewScreen> createState() => _ClubReviewScreenState();
}

class _ClubReviewScreenState extends ConsumerState<ClubReviewScreen> {
  final _workedCtrl  = TextEditingController();
  final _didntCtrl   = TextEditingController();

  int _rating               = 0;
  WouldRecommend _recommend = WouldRecommend.yes;
  ReviewSpoilerLevel _spoiler = ReviewSpoilerLevel.none;
  bool _loading             = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _rating     = e.rating;
      _recommend  = e.wouldRecommend;
      _spoiler    = e.spoilerLevel;
      _workedCtrl.text = e.whatWorked ?? '';
      _didntCtrl.text  = e.whatDidnt ?? '';
    }
  }

  @override
  void dispose() {
    _workedCtrl.dispose();
    _didntCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _rating > 0;

  Future<void> _save() async {
    if (!_canSave || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(bookClubRepositoryProvider).submitReview(
            clubId:          widget.clubId,
            bookHistoryId:   widget.bookHistoryId,
            rating:          _rating,
            whatWorked:      _workedCtrl.text.trim().isEmpty
                ? null
                : _workedCtrl.text.trim(),
            whatDidnt:       _didntCtrl.text.trim().isEmpty
                ? null
                : _didntCtrl.text.trim(),
            wouldRecommend:  _recommend,
            spoilerLevel:    _spoiler,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resenha salva!')),
        );
        context.pop(true); // retorna `true` para o caller saber que foi salvo
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Editar resenha' : 'Escrever resenha',
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Salvar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Livro ────────────────────────────────────────────────────────
          Text(
            widget.bookTitle,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // ── Passo 1: Nota ─────────────────────────────────────────────
          _StepHeader(number: 1, label: 'Qual sua nota para o livro?'),
          const SizedBox(height: 12),
          _StarSelector(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 24),

          // ── Passo 2: O que funcionou ──────────────────────────────────
          _StepHeader(
            number: 2,
            label: 'O que funcionou?',
            subtitle: 'Opcional — ex: o ritmo, um personagem, o final...',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _workedCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'O que você mais gostou no livro...',
              counterStyle: AppTextStyles.labelMedium,
            ),
          ),
          const SizedBox(height: 20),

          // ── Passo 3: O que não funcionou ──────────────────────────────
          _StepHeader(
            number: 3,
            label: 'O que não funcionou?',
            subtitle: 'Opcional — ex: ritmo lento, final previsível...',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _didntCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'O que poderia ter sido melhor...',
              counterStyle: AppTextStyles.labelMedium,
            ),
          ),
          const SizedBox(height: 20),

          // ── Passo 4: Recomendaria ─────────────────────────────────────
          _StepHeader(number: 4, label: 'Recomendaria para o clube?'),
          const SizedBox(height: 12),
          _RecommendSelector(
            value: _recommend,
            onChanged: (v) => setState(() => _recommend = v),
          ),
          const SizedBox(height: 24),

          // ── Passo 5: Spoiler ──────────────────────────────────────────
          _StepHeader(
            number: 5,
            label: 'Nível de spoiler',
            subtitle: 'Se sua resenha revelar detalhes, avise os outros.',
          ),
          const SizedBox(height: 12),
          _SpoilerSelector(
            value: _spoiler,
            onChanged: (v) => setState(() => _spoiler = v),
          ),
          const SizedBox(height: 32),

          // ── Botão salvar ──────────────────────────────────────────────
          FilledButton(
            onPressed: _canSave && !_loading ? _save : null,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white),
                  )
                : const Text('Salvar resenha'),
          ),
          if (!_canSave)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selecione uma nota para continuar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Cabeçalho de etapa ────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int number;
  final String label;
  final String? subtitle;

  const _StepHeader({
    required this.number,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.forestGreen,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.titleMedium),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              subtitle!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Seletor de estrelas ───────────────────────────────────────────────────────

class _StarSelector extends StatelessWidget {
  final int value; // 0 = não selecionado
  final ValueChanged<int> onChanged;

  const _StarSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 36,
              color: filled ? AppColors.warmGold : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}

// ── Seletor de recomendação ───────────────────────────────────────────────────

class _RecommendSelector extends StatelessWidget {
  final WouldRecommend value;
  final ValueChanged<WouldRecommend> onChanged;

  const _RecommendSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WouldRecommend.values.map((opt) {
        final isSelected = opt == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forestGreen.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.forestGreen
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isSelected
                        ? AppColors.forestGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Seletor de spoiler ────────────────────────────────────────────────────────

class _SpoilerSelector extends StatelessWidget {
  final ReviewSpoilerLevel value;
  final ValueChanged<ReviewSpoilerLevel> onChanged;

  const _SpoilerSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ReviewSpoilerLevel.values.map((opt) {
        final isSelected = opt == value;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.forestGreen.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.forestGreen : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected
                      ? AppColors.forestGreen
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  opt.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.forestGreen
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
