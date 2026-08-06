import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/club_reviews.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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
  final _workedCtrl = TextEditingController();
  final _didntCtrl = TextEditingController();

  int _rating = 0;
  WouldRecommend _recommend = WouldRecommend.yes;
  ReviewSpoilerLevel _spoiler = ReviewSpoilerLevel.none;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _rating = e.rating;
      _recommend = e.wouldRecommend;
      _spoiler = e.spoilerLevel;
      _workedCtrl.text = e.whatWorked ?? '';
      _didntCtrl.text = e.whatDidnt ?? '';
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
            clubId: widget.clubId,
            bookHistoryId: widget.bookHistoryId,
            rating: _rating,
            whatWorked: _workedCtrl.text.trim().isEmpty
                ? null
                : _workedCtrl.text.trim(),
            whatDidnt: _didntCtrl.text.trim().isEmpty
                ? null
                : _didntCtrl.text.trim(),
            wouldRecommend: _recommend,
            spoilerLevel: _spoiler,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resenha salva!')),
        );
        context.pop(true);
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
    return LumenClubTintBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing != null ? 'Editar resenha' : 'Escrever resenha',
            style: LumenType.bookTitle(size: 16),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
          // ── Livro ─────────────────────────────────────────────────────
          Text(
            widget.bookTitle,
            style: LumenType.authorName(
                color: LumenColors.inkMuted, size: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 32),

          // ── Passo 1: Nota ─────────────────────────────────────────────
          Text('Nota', style: LumenType.kicker(
              color: LumenColors.inkMuted, size: 11)),
          const SizedBox(height: 12),
          _RatingSelector(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const Divider(height: 32),

          // ── Passo 2: O que funcionou ──────────────────────────────────
          Text('O que funcionou?',
              style: LumenType.kicker(
                  color: LumenColors.inkMuted, size: 11)),
          Text('Opcional — ex: ritmo, personagem, final…',
              style: LumenType.authorName(
                  color: LumenColors.inkGhost, size: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _workedCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'O que você mais gostou no livro…',
              counterText: '',
            ),
          ),
          const Divider(height: 32),

          // ── Passo 3: O que não funcionou ──────────────────────────────
          Text('O que não funcionou?',
              style: LumenType.kicker(
                  color: LumenColors.inkMuted, size: 11)),
          Text('Opcional — ex: ritmo lento, final previsível…',
              style: LumenType.authorName(
                  color: LumenColors.inkGhost, size: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _didntCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'O que poderia ter sido melhor…',
              counterText: '',
            ),
          ),
          const Divider(height: 32),

          // ── Passo 4: Recomendaria ─────────────────────────────────────
          Text('Recomendaria para o clube?',
              style: LumenType.kicker(
                  color: LumenColors.inkMuted, size: 11)),
          const SizedBox(height: 12),
          _RecommendSelector(
            value: _recommend,
            onChanged: (v) => setState(() => _recommend = v),
          ),
          const Divider(height: 32),

          // ── Passo 5: Spoiler ──────────────────────────────────────────
          Text('Nível de spoiler',
              style: LumenType.kicker(
                  color: LumenColors.inkMuted, size: 11)),
          Text('Se sua resenha revelar detalhes, avise os outros.',
              style: LumenType.authorName(
                  color: LumenColors.inkGhost, size: 12)),
          const SizedBox(height: 12),
          _SpoilerSelector(
            value: _spoiler,
            onChanged: (v) => setState(() => _spoiler = v),
          ),
          const SizedBox(height: 32),

          // ── Botão salvar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave && !_loading ? _save : null,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar resenha'),
            ),
          ),
          if (!_canSave)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selecione uma nota para continuar.',
                textAlign: TextAlign.center,
                style: LumenType.authorName(
                    color: LumenColors.inkMuted, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seletor de nota numérica ──────────────────────────────────────────────────

class _RatingSelector extends StatelessWidget {
  final int value; // 0 = não selecionado
  final ValueChanged<int> onChanged;

  const _RatingSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '${i + 1}',
              style: LumenType.bookTitle(
                size: 22,
                color: filled ? LumenColors.ink : LumenColors.inkGhost,
              ),
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
    return Column(
      children: WouldRecommend.values.map((opt) {
        final isSelected = opt == value;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  isSelected ? '●' : '○',
                  style: LumenType.mono(
                    size: 14,
                    color: isSelected
                        ? LumenColors.ink
                        : LumenColors.inkGhost,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  opt.label,
                  style: LumenType.authorName(
                    size: 14,
                    color: isSelected
                        ? LumenColors.ink
                        : LumenColors.inkMuted,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  isSelected ? '●' : '○',
                  style: LumenType.mono(
                    size: 14,
                    color: isSelected
                        ? LumenColors.ink
                        : LumenColors.inkGhost,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  opt.label,
                  style: LumenType.authorName(
                    size: 14,
                    color: isSelected
                        ? LumenColors.ink
                        : LumenColors.inkMuted,
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
