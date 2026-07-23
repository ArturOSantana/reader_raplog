// ReadLog — Design System
// Identidade "ficha de biblioteca": papel envelhecido, carimbo de tinta,
// réguas de sumário e navegação em lombadas de livro.
//
// Fontes usadas via assets/fonts (já declaradas no pubspec):
//   Display -> Fraunces
//   Corpo   -> IBM Plex Mono
//
// Transições de página fluídas adaptadas a iOS (cupertino) e Android (fade+slide).

import 'package:flutter/material.dart';

/// -------------------- TOKENS --------------------

class ReadLogColors {
  ReadLogColors._();

  static const ink = Color(0xFF17241C); // fundo escuro (capa de livro)
  static const inkAlt = Color(0xFF20301F);
  static const paper = Color(0xFFE9E1CC); // papel envelhecido
  static const paperAlt = Color(0xFFDDD2B4);
  static const paperDeep = Color(0xFFCFC29D);
  static const brass = Color(0xFFB08D4F); // latão — destaque neutro
  static const brassLight = Color(0xFFD2B57C);
  static const stamp = Color(0xFF9C3B29); // vermelho carimbo — único acento "quente"
  static const sage = Color(0xFF6F8768); // verde sálvia — estados secundários
  static const cream = Color(0xFFF4EEDD);
  static const charcoal = Color(0xFF241C14); // texto principal sobre papel
}

class ReadLogType {
  ReadLogType._();

  static TextTheme textTheme(Color onSurface) => TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 15,
          height: 1.5,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 14,
          height: 1.5,
          color: onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 12,
          color: onSurface.withValues(alpha: 0.7),
        ),
        labelSmall: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 11,
          letterSpacing: 0.6,
          color: onSurface,
        ),
      );

  /// Usar para números grandes: timer de sessão, contagem de páginas, XP.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontFamilyFallback: const ['Courier New', 'monospace'],
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color? color,
    bool italic = false,
  }) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}

/// -------------------- THEME --------------------

class ReadLogTheme {
  ReadLogTheme._();

  /// Transições de página fluídas — slide suave em todas as plataformas.
  static final _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux: const _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: const _FadeSlidePageTransitionsBuilder(),
    },
  );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ReadLogColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: ReadLogColors.stamp,
        secondary: ReadLogColors.brass,
        surface: ReadLogColors.paper,
        onSurface: ReadLogColors.charcoal,
      ),
      textTheme: ReadLogType.textTheme(ReadLogColors.charcoal),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: ReadLogColors.paper,
        foregroundColor: ReadLogColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            ReadLogType.display(size: 19, color: ReadLogColors.charcoal),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ReadLogColors.stamp,
          foregroundColor: ReadLogColors.cream,
          textStyle: ReadLogType.mono(size: 13, weight: FontWeight.w600),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ReadLogColors.stamp,
          foregroundColor: ReadLogColors.cream,
          textStyle: ReadLogType.mono(size: 13, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3)),
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: ReadLogColors.cream,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ReadLogColors.cream,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: ReadLogColors.paperDeep),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: ReadLogColors.paperDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              const BorderSide(color: ReadLogColors.brass, width: 2),
        ),
        labelStyle: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 12,
            color: ReadLogColors.charcoal.withValues(alpha: 0.6)),
        hintStyle: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 12,
            color: ReadLogColors.charcoal.withValues(alpha: 0.4)),
        suffixStyle: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 14,
            color: ReadLogColors.charcoal),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ReadLogColors.brass,
        selectionColor: ReadLogColors.brass.withValues(alpha: 0.3),
        selectionHandleColor: ReadLogColors.brass,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ReadLogColors.ink,
      colorScheme: base.colorScheme.copyWith(
        primary: ReadLogColors.stamp,
        secondary: ReadLogColors.brassLight,
        surface: ReadLogColors.inkAlt,
        onSurface: ReadLogColors.cream,
        outline: ReadLogColors.cream.withValues(alpha: 0.2),
      ),
      textTheme: ReadLogType.textTheme(ReadLogColors.cream),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: ReadLogColors.ink,
        foregroundColor: ReadLogColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            ReadLogType.display(size: 19, color: ReadLogColors.cream),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ReadLogColors.stamp,
          foregroundColor: ReadLogColors.cream,
          textStyle: ReadLogType.mono(size: 13, weight: FontWeight.w600),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ReadLogColors.stamp,
          foregroundColor: ReadLogColors.cream,
          textStyle: ReadLogType.mono(size: 13, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3)),
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: ReadLogColors.inkAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: ReadLogColors.cream.withValues(alpha: 0.12),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ReadLogColors.inkAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
              color: ReadLogColors.cream.withValues(alpha: 0.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
              color: ReadLogColors.cream.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              const BorderSide(color: ReadLogColors.brassLight, width: 2),
        ),
        labelStyle: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 13,
            color: ReadLogColors.cream.withValues(alpha: 0.75)),
        floatingLabelStyle: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 12,
            color: ReadLogColors.brassLight),
        hintStyle: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 13,
            color: ReadLogColors.cream.withValues(alpha: 0.5)),
        suffixStyle: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 14,
            color: ReadLogColors.cream),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ReadLogColors.brassLight,
        selectionColor: ReadLogColors.brassLight.withValues(alpha: 0.3),
        selectionHandleColor: ReadLogColors.brassLight,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReadLogColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ReadLogColors.inkAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ReadLogColors.cream.withValues(alpha: 0.65),
        textColor: ReadLogColors.cream,
      ),
    );
  }
}

/// -------------------- TRANSIÇÃO: FADE + SLIDE --------------------
///
/// Slide suave de baixo para cima + fade — não usa depreciados.

class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Duração mais curta (220 ms) + curva de saída mais agressiva
    // para dar sensação de resposta imediata ao toque.
    final fast = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(fast),
        child: child,
      ),
    );
  }
}

// ── Duração global de transição ───────────────────────────────────────────────
//
// GoRouter usa MaterialPageRoute internamente; sobrescrevemos a duração via
// extensão que o router chama em `buildPage`.

class ReadLogPageRoute<T> extends MaterialPageRoute<T> {
  ReadLogPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);
}

/// -------------------- WIDGET: STAMP --------------------
///
/// O carimbo de tinta é o único elemento "ousado" da identidade.
/// Usar para: sequência de dias, conquista desbloqueada, livro concluído.
/// Nunca usar em mais de um lugar por tela.

class ReadLogStamp extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double size;
  final double rotationDeg;

  const ReadLogStamp({
    super.key,
    required this.value,
    required this.label,
    this.color = ReadLogColors.stamp,
    this.size = 96,
    this.rotationDeg = -8,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDeg * 3.1415926535 / 180,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _StampPainter(color: color),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: ReadLogType.mono(
                      size: size * 0.27,
                      weight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: ReadLogType.mono(size: size * 0.09, color: color)
                        .copyWith(letterSpacing: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final Color color;
  _StampPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final solidPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Círculo sólido externo
    canvas.drawCircle(center, radius - 1.5, solidPaint);

    // Círculo tracejado interno
    final dashedPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashCount = 32;
    const dashAngle = 2 * 3.1415926535 / dashCount;
    final innerRadius = radius - 9;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final endAngle = startAngle + dashAngle * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        endAngle - startAngle,
        false,
        dashedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// -------------------- WIDGET: LEADER ROW --------------------
///
/// Linha "página inicial ..... 278" — inspirada em sumário de livro.

class ReadLogLeaderRow extends StatelessWidget {
  final String label;
  final String value;

  const ReadLogLeaderRow(
      {super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    const textColor = ReadLogColors.charcoal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: ReadLogType.mono(size: 13, color: textColor)),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CustomPaint(
                painter:
                    _DottedLinePainter(color: textColor.withValues(alpha: 0.35)),
                size: const Size(double.infinity, 1),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: ReadLogType.mono(
                size: 13, weight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 2.0;
    const dashSpace = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// -------------------- WIDGET: SPINE NAV BAR --------------------
///
/// Navegação inferior estilizada como lombadas de livro lado a lado.
/// A aba ativa ganha um "marcador de página" animado (triângulo invertido) no topo.

class ReadLogSpineNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;

  const ReadLogSpineNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.icons = const [
      Icons.home_outlined,
      Icons.menu_book_outlined,
      Icons.timer_outlined,
      Icons.emoji_events_outlined,
      Icons.person_outline,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: EdgeInsets.fromLTRB(6, 6, 6, bottomPadding > 0 ? 0 : 0),
      decoration: BoxDecoration(
        color: ReadLogColors.charcoal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(icons.length, (i) {
              final active = i == currentIndex;
              return Expanded(
                child: _SpineTab(
                  icon: icons[i],
                  active: active,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Tab individual com animação de highlight e marcador.
class _SpineTab extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SpineTab({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Marcador de página animado
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: active ? -6 : -20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: active ? 1.0 : 0.0,
              child: ClipPath(
                clipper: _BookmarkClipper(),
                child: Container(
                  width: 16,
                  height: 12,
                  color: ReadLogColors.stamp,
                ),
              ),
            ),
          ),
          // Fundo animado da aba
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: active
                  ? ReadLogColors.brass
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                key: ValueKey(active),
                size: 20,
                color: active
                    ? ReadLogColors.charcoal
                    : ReadLogColors.cream.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width / 2, size.height * 0.6);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// -------------------- WIDGET: CATALOG CARD --------------------
///
/// Card de livro com "aba" lateral colorida por status.
/// Toque com feedback tátil (ripple via InkWell).

class ReadLogCatalogCard extends StatelessWidget {
  final String title;
  final String author;
  final double progress; // 0..1
  final Color tabColor;
  final VoidCallback? onTap;

  const ReadLogCatalogCard({
    super.key,
    required this.title,
    required this.author,
    required this.progress,
    this.tabColor = ReadLogColors.brass,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: ReadLogColors.paper,
        borderRadius: BorderRadius.circular(3),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          splashColor: tabColor.withValues(alpha: 0.18),
          highlightColor: tabColor.withValues(alpha: 0.10),
          child: Row(
            children: [
              // Aba de status colorida
              Container(
                width: 6,
                height: 64,
                decoration: BoxDecoration(
                  color: tabColor,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(3)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ReadLogType.display(
                            size: 15, color: ReadLogColors.charcoal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author,
                        style: ReadLogType.mono(
                            size: 10,
                            color: ReadLogColors.charcoal.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                            value: value,
                            minHeight: 4,
                            backgroundColor: ReadLogColors.paperDeep,
                            color: ReadLogColors.stamp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: ReadLogColors.paperDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// -------------------- CLUBE: MILESTONE TRACK --------------------
///
/// Trilha de marcos (25/50/75/100%) para o ciclo de leitura do clube.
/// Reaproveita o vocabulário visual da barra de progresso da biblioteca —
/// não usa ícones de "conquista social" genéricos.

class ReadLogMilestoneTrack extends StatelessWidget {
  /// 0 a 4 — quantos marcos já foram concluídos pelo clube.
  final int completedSegments;
  final List<String> labels;

  const ReadLogMilestoneTrack({
    super.key,
    required this.completedSegments,
    this.labels = const ['25%', '50%', '75%', '100%'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(labels.length, (i) {
            final done = i < completedSegments;
            final current = i == completedSegments;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 4),
                height: 7,
                decoration: BoxDecoration(
                  color: done
                      ? ReadLogColors.stamp
                      : current
                          ? ReadLogColors.brass
                          : ReadLogColors.paperDeep,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((l) => Text(
                    l,
                    style: ReadLogType.mono(
                      size: 9.5,
                      color: ReadLogColors.charcoal.withValues(alpha: 0.65),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// -------------------- CLUBE: LIVE CHIP (Sala de Leitura) --------------------
///
/// Selo pulsante para presença ao vivo (Supabase Presence/Broadcast).
/// Não usa ícone de câmera/videochamada — é "ponto de tinta aceso".

class ReadLogLiveChip extends StatefulWidget {
  final String label;
  const ReadLogLiveChip({super.key, required this.label});

  @override
  State<ReadLogLiveChip> createState() => _ReadLogLiveChipState();
}

class _ReadLogLiveChipState extends State<ReadLogLiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ReadLogColors.stamp.withValues(alpha: 0.14),
        border: Border.all(color: ReadLogColors.stamp),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: ReadLogColors.stamp,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label.toUpperCase(),
            style: ReadLogType.mono(size: 9.5, color: const Color(0xFFE8A392))
                .copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

/// -------------------- CLUBE: LEADERBOARD ROW --------------------
///
/// Linha de ranking — usado no leaderboard de apostas e no ranking geral do clube.

class ReadLogLeaderboardRow extends StatelessWidget {
  final int position;
  final String name;
  final String metric; // ex: "82% acerto", "1.240 pág."
  final bool highlight;

  const ReadLogLeaderboardRow({
    super.key,
    required this.position,
    required this.name,
    required this.metric,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: highlight
          ? BoxDecoration(
              color: ReadLogColors.brass.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$position',
              style: ReadLogType.mono(
                size: 12,
                color: ReadLogColors.brass,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: ReadLogType.mono(size: 13, color: ReadLogColors.charcoal),
            ),
          ),
          Text(
            metric,
            style: ReadLogType.mono(
              size: 12,
              weight: FontWeight.w600,
              color: ReadLogColors.stamp,
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------- CLUBE: POLL / BET BAR --------------------
///
/// Barra de opção para votação livre ou lado de aposta. Mesma linguagem
/// visual da barra de progresso da biblioteca — não é um componente novo.

class ReadLogPollBar extends StatelessWidget {
  final String label;
  final double percent; // 0..1
  final Color fillColor;

  const ReadLogPollBar({
    super.key,
    required this.label,
    required this.percent,
    this.fillColor = ReadLogColors.sage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: ReadLogType.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: ReadLogColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ReadLogColors.paperDeep,
              color: fillColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------- NOTIFICAÇÕES: LIST TILE --------------------
///
/// Tile de notificação com borda esquerda stamp para não-lidas.
/// Agrupa ícone + título + subtítulo + timestamp — sem badge genérico.

class ReadLogNotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  const ReadLogNotificationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ReadLogColors.cream,
          borderRadius: BorderRadius.circular(3),
          border: unread
              ? const Border(
                  left: BorderSide(color: ReadLogColors.stamp, width: 3),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ReadLogColors.paperDeep,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: ReadLogColors.charcoal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ReadLogType.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: ReadLogColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: ReadLogType.mono(
                      size: 11,
                      color: ReadLogColors.charcoal.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: ReadLogType.mono(
                      size: 9.5,
                      color: ReadLogColors.charcoal.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
