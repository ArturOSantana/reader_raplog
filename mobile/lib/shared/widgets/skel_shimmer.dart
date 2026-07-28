/// Widgets de skeleton / shimmer reutilizáveis.
///
/// Uso básico:
///   SkelShimmer(child: SkelBox(height: 80, width: double.infinity))
///
/// Pré-sets prontos:
///   SkelShimmer.listTile()   — linha de lista genérica
///   SkelShimmer.card()       — card retangular
///   SkelShimmer.text(lines)  — bloco de texto
library;

import 'package:flutter/material.dart';
import '../../theme/readlog_theme.dart';

// ── Motor do shimmer ──────────────────────────────────────────────────────────

class _ShimmerGradient extends StatefulWidget {
  final Widget child;

  const _ShimmerGradient({required this.child});

  @override
  State<_ShimmerGradient> createState() => _ShimmerGradientState();

  static _ShimmerGradientState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ShimmerGradientState>();
}

class _ShimmerGradientState extends State<_ShimmerGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _animValue => _ctrl.value;

  void addListener(VoidCallback cb) => _ctrl.addListener(cb);
  void removeListener(VoidCallback cb) => _ctrl.removeListener(cb);

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── SkelBox: peça atômica ─────────────────────────────────────────────────────

class SkelBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const SkelBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });

  @override
  State<SkelBox> createState() => _SkelBoxState();
}

class _SkelBoxState extends State<SkelBox> {
  _ShimmerGradientState? _shimmer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shimmer?.removeListener(_rebuild);
    _shimmer = _ShimmerGradient.of(context);
    _shimmer?.addListener(_rebuild);
  }

  @override
  void dispose() {
    _shimmer?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = isDark
        ? ReadLogColors.inkAlt
        : ReadLogColors.paperAlt;
    final highlight = isDark
        ? ReadLogColors.ink.withValues(alpha: 0.0)
        : ReadLogColors.cream;

    final t = _shimmer?._animValue ?? 0.0;

    // Gradient viaja da esquerda para a direita
    final shimmerGradient = LinearGradient(
      colors: [base, highlight, base],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(-1.5 + t * 3, 0),
      end: Alignment(-0.5 + t * 3, 0),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = widget.width ?? constraints.maxWidth;
        return Container(
          width: w,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: shimmerGradient,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// ── SkelShimmer: wrapper que injeta o motor ───────────────────────────────────

class SkelShimmer extends StatelessWidget {
  final Widget child;

  const SkelShimmer({super.key, required this.child});

  /// Uma linha de lista com ícone + título + subtítulo.
  factory SkelShimmer.listTile() => SkelShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SkelBox(width: 40, height: 40, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkelBox(height: 13, width: double.infinity),
                    const SizedBox(height: 6),
                    SkelBox(height: 11, width: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                ),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      _ShimmerGradient(child: child);
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
class SkelScreenList extends StatelessWidget {
  final int count;

  const SkelScreenList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        for (var i = 0; i < count; i++) SkelShimmer.listTile(),
      ],
    );
  }
}
