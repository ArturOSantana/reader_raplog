/// Widgets de skeleton / shimmer reutilizáveis.
///
/// Filosofia editorial:
///   Sem gradiente branco ("brilho plástico") — o grain já está sob tudo.
///   O skeleton pulsa de opacidade (0.55 → 0.30) na cadência LumenMotion.skelPulse
///   (1800 ms), mais lenta que animações de UI para não competir com o grain.
///
/// Uso básico:
///   SkelBox(height: 80, width: double.infinity)
///
/// Composições prontas:
///   SkelShimmer.listTile()   — linha de lista genérica
///   SkelShimmer.card()       — card retangular
///   SkelShimmer.text(lines)  — bloco de texto
library;

import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';

// ── SkelBox: peça atômica ─────────────────────────────────────────────────────
//
// Pulsa entre opacidade 0.55 e 0.30 com staggering por índice opcional.
// A cor base é paper-deep (light) ou canvas-elevated (dark) — sem branco.

class SkelBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  /// Atraso inicial para staggering: 80 ms × índice recomendado
  final Duration delay;

  const SkelBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
    this.delay = Duration.zero,
  });

  @override
  State<SkelBox> createState() => _SkelBoxState();
}

class _SkelBoxState extends State<SkelBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: LumenMotion.skelPulse,
    );

    _opacity = Tween<double>(begin: 0.55, end: 0.30).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    // Staggering: aguarda o delay antes de iniciar
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? LumenColors.canvasElevated   // #222220
        : LumenColors.surfaceSubtle;   // #ECEAE9

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _opacity.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── SkelShimmer: compatibilidade com usos existentes ─────────────────────────
//
// Mantém a API anterior (SkelShimmer.listTile(), .card(), .text())
// mas remove o motor de gradient — agora usa SkelBox com pulse.

class SkelShimmer extends StatelessWidget {
  final Widget child;

  const SkelShimmer({super.key, required this.child});

  /// Uma linha de lista com ícone + título + subtítulo.
  factory SkelShimmer.listTile() => const SkelShimmer(
        child: _SkelListTile(delay: Duration.zero),
      );

  /// Um card de altura fixa.
  factory SkelShimmer.card({double height = 100}) => SkelShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SkelBox(height: height, radius: 6),
        ),
      );

  /// Bloco de [lines] linhas de texto.
  factory SkelShimmer.text({int lines = 3}) => SkelShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < lines; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                SkelBox(
                  height: 13,
                  width: i == lines - 1 ? 200 : double.infinity,
                  delay: Duration(milliseconds: i * 80),
                ),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => child;
}

// ── Tile interno ─────────────────────────────────────────────────────────────

class _SkelListTile extends StatelessWidget {
  final Duration delay;
  const _SkelListTile({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SkelBox(width: 40, height: 40, radius: 20, delay: delay),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkelBox(
                  height: 13,
                  width: double.infinity,
                  delay: delay + const Duration(milliseconds: 80),
                ),
                const SizedBox(height: 6),
                SkelBox(
                  height: 11,
                  width: 140,
                  delay: delay + const Duration(milliseconds: 160),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SkelList: lista de N skeletons ────────────────────────────────────────────

/// Atalho para exibir uma lista de skeletons durante o carregamento.
///
/// [builder] recebe o índice e retorna um widget envolto pelo [SkelShimmer].
class SkelList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) builder;

  const SkelList({
    super.key,
    this.itemCount = 5,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (_, i) => SkelShimmer(child: builder(i)),
    );
  }
}

// ── SkelScreen: loading de tela inteira ───────────────────────────────────────

/// Placeholder de carregamento para telas que mostram uma lista de tiles.
///
/// Staggering automático: cada tile atrasa 80 ms × índice.
class SkelScreenList extends StatelessWidget {
  final int count;

  const SkelScreenList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        for (var i = 0; i < count; i++)
          _SkelListTile(delay: Duration(milliseconds: i * 80)),
      ],
    );
  }
}
