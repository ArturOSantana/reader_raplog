import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/reading_session.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../../theme/lumen_theme.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Impressão de leitura',
            style: ReadLogType.bookTitle(size: 16)),
      ),
      body: _done
          ? const _SuccessView()
          : _CheckinForm(
              mood: _mood,
              reviewController: _reviewController,
              loading: _loading,
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
  final void Function(SessionMood) onMoodSelected;
  final VoidCallback onConfirm;

  const _CheckinForm({
    required this.mood,
    required this.reviewController,
    required this.loading,
    required this.onMoodSelected,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Text('Como foi a sessão?',
              style: ReadLogType.bookTitle(size: 22)),
          const SizedBox(height: 6),
          Text(
            'Seu check-in já foi registrado automaticamente.\nAdicione uma impressão se quiser compartilhar.',
            style: ReadLogType.authorName(color: ReadLogColors.inkMuted),
          ),
          const Divider(height: 40),

          // ── Mood (opcional) ────────────────────────────────────────────
          Text('Humor da sessão',
              style: ReadLogType.kicker(
                  color: ReadLogColors.inkMuted, size: 11)),
          const SizedBox(height: 2),
          Text('Opcional',
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkGhost, size: 12)),
          const SizedBox(height: 16),
          // Seleção por palavra — sem emoji nem card colorido
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SessionMood.values.map((m) {
              final selected = mood == m;
              return GestureDetector(
                onTap: () => onMoodSelected(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? ReadLogColors.ink
                          : ReadLogColors.inkGhost,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    m.label,
                    style: ReadLogType.authorName(
                      color: selected
                          ? ReadLogColors.ink
                          : ReadLogColors.inkMuted,
                      size: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 40),

          // ── Mini resenha (opcional) ────────────────────────────────────
          Text('Impressão rápida',
              style: ReadLogType.kicker(
                  color: ReadLogColors.inkMuted, size: 11)),
          const SizedBox(height: 2),
          Text('Opcional — máx. 500 caracteres',
              style: ReadLogType.authorName(
                  color: ReadLogColors.inkGhost, size: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: reviewController,
            maxLines: 4,
            maxLength: 500,
            style: ReadLogType.authorName(size: 14),
            decoration: InputDecoration(
              hintText:
                  '"Hoje finalmente entendi a motivação do personagem."',
              hintStyle: ReadLogType.authorName(
                  color: ReadLogColors.inkGhost, size: 13),
              contentPadding: const EdgeInsets.all(14),
              counterStyle: ReadLogType.mono(
                  size: 11, color: ReadLogColors.inkGhost),
            ),
          ),
          const SizedBox(height: 32),

          // ── Botão de salvar ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onConfirm,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar impressão'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: loading ? null : onConfirm,
              child: Text(
                'Pular',
                style: ReadLogType.authorName(
                    color: ReadLogColors.inkMuted, size: 13),
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
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Impressão salva.',
                style: ReadLogType.bookTitle(size: 22)),
            const SizedBox(height: 8),
            Text(
              'Sua sessão e impressão foram registradas.',
              textAlign: TextAlign.center,
              style: ReadLogType.authorName(color: ReadLogColors.inkMuted),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Voltar ao clube',
                  style: ReadLogType.authorName(size: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
