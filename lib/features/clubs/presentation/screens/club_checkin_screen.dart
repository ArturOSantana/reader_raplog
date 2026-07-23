import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela de impressão de leitura — permite ao leitor registrar mood e
/// mini_review opcionais na sessão mais recente concluída.
///
/// O check-in em si já foi gerado automaticamente pelo trigger
/// [auto_checkin_after_session] ao finalizar a sessão — esta tela é
/// apenas o espaço opcional para compartilhar a experiência.
class ClubCheckinScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  /// Sessão mais recente concluída, se existir (para atualizar mood/mini_review).
  final String? latestSessionId;

  const ClubCheckinScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.latestSessionId,
  });

  @override
  ConsumerState<ClubCheckinScreen> createState() => _ClubCheckinScreenState();
}

class _ClubCheckinScreenState extends ConsumerState<ClubCheckinScreen> {
  SessionMood? _mood;
  final _reviewController = TextEditingController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final hasMood = _mood != null;
    final hasReview = _reviewController.text.trim().isNotEmpty;

    // Sem nada para salvar, fecha direto
    if (!hasMood && !hasReview) {
      setState(() => _done = true);
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.latestSessionId != null) {
        await ref.read(supabaseClientProvider).from('reading_sessions').update({
          if (hasMood) 'mood': _mood!.dbValue,
          if (hasReview) 'mini_review': _reviewController.text.trim(),
        }).eq('id', widget.latestSessionId!);
      }
      setState(() {
        _loading = false;
        _done = true;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar impressão: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.offWhite,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.offWhite,
        elevation: 0,
        title: Text(
            'Impressão de leitura',
            style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
          ),
      ),
      body: _done
          ? _SuccessView(surfaceColor: surfaceColor, borderColor: borderColor)
          : _CheckinForm(
              mood: _mood,
              reviewController: _reviewController,
              loading: _loading,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              cs: cs,
              onMoodSelected: (m) => setState(() => _mood = m),
              onConfirm: _confirm,
            ),
    );
  }
}

// ── Formulário de check-in ────────────────────────────────────────────────────

class _CheckinForm extends StatelessWidget {
  final SessionMood? mood;
  final TextEditingController reviewController;
  final bool loading;
  final Color surfaceColor;
  final Color borderColor;
  final ColorScheme cs;
  final void Function(SessionMood) onMoodSelected;
  final VoidCallback onConfirm;

  const _CheckinForm({
    required this.mood,
    required this.reviewController,
    required this.loading,
    required this.surfaceColor,
    required this.borderColor,
    required this.cs,
    required this.onMoodSelected,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warmGold.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.warmGold.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_stories_outlined, size: 40, color: AppColors.warmGold),
                const SizedBox(height: 10),
                Text(
                  'Como foi a sessão?',
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: cs.onSurface, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seu check-in já foi registrado automaticamente.\nAdicione uma impressão se quiser compartilhar!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Mood (opcional) ────────────────────────────────────────────
          Text(
            'Humor da sessão',
            style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Opcional',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: SessionMood.values.map((m) {
              final selected = mood == m;
              return GestureDetector(
                onTap: () => onMoodSelected(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.warmGold.withValues(alpha: 0.15)
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.warmGold
                          : borderColor,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(
                        m.label,
                        style: AppTextStyles.labelMedium
                            .copyWith(fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // ── Mini resenha (opcional) ────────────────────────────────────
          Text(
            'Impressão rápida',
            style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Opcional — máx. 500 caracteres',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: reviewController,
              maxLines: 4,
              maxLength: 500,
              style: AppTextStyles.bodyLarge.copyWith(
                  color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: '"Hoje finalmente entendi a motivação do personagem."',
                hintStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
                counterStyle: AppTextStyles.labelMedium,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Botão de salvar ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: loading ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmGold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Salvar impressão',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onConfirm,
              child: Text(
                'Pular',
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tela de sucesso ───────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;

  const _SuccessView(
      {required this.surfaceColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 44, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            Text(
                'Impressão salva!',
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sua sessão e impressão foram registradas.\nA ofensiva coletiva do clube continua!',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar ao clube'),
            ),
          ],
        ),
      ),
    );
  }
}
