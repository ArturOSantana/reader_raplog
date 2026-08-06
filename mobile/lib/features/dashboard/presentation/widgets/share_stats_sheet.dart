import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../theme/lumen_theme.dart';
import 'share_stats_card.dart';

/// Exibe um bottom sheet com o card de estatísticas pronto para compartilhar.
Future<void> showShareStatsSheet({
  required BuildContext context,
  required int streak,
  required int weekMinutes,
  required int weekPages,
  required int monthMinutes,
  required int monthPages,
  required int monthBooks,
  required int totalBooks,
  required String userName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: LumenColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ShareStatsContent(
      streak: streak,
      weekMinutes: weekMinutes,
      weekPages: weekPages,
      monthMinutes: monthMinutes,
      monthPages: monthPages,
      monthBooks: monthBooks,
      totalBooks: totalBooks,
      userName: userName,
    ),
  );
}

class _ShareStatsContent extends StatefulWidget {
  final int streak;
  final int weekMinutes;
  final int weekPages;
  final int monthMinutes;
  final int monthPages;
  final int monthBooks;
  final int totalBooks;
  final String userName;

  const _ShareStatsContent({
    required this.streak,
    required this.weekMinutes,
    required this.weekPages,
    required this.monthMinutes,
    required this.monthPages,
    required this.monthBooks,
    required this.totalBooks,
    required this.userName,
  });

  @override
  State<_ShareStatsContent> createState() => _ShareStatsContentState();
}

class _ShareStatsContentState extends State<_ShareStatsContent> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    // Captura render objects ANTES de qualquer await
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    if (boundary == null) return;

    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/readlog_stats.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.streak} dias de sequência no ReadLog!\n'
              'Esta semana: ${_fmtTime(widget.weekMinutes)} de leitura.\n'
              'Este mês: ${widget.monthBooks} livro${widget.monthBooks == 1 ? '' : 's'} lido${widget.monthBooks == 1 ? '' : 's'}.',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: LumenColors.brassLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Compartilhar estatísticas',
            style: LumenType.display(size: 20, color: LumenColors.cream),
          ),
          const SizedBox(height: 20),

          // Preview do card capturável
          RepaintBoundary(
            key: _repaintKey,
            child: ShareStatsCard(
              streak: widget.streak,
              weekMinutes: widget.weekMinutes,
              weekPages: widget.weekPages,
              monthMinutes: widget.monthMinutes,
              monthPages: widget.monthPages,
              monthBooks: widget.monthBooks,
              totalBooks: widget.totalBooks,
              userName: widget.userName,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: LumenColors.cream, strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded),
              label: Text(_sharing ? 'Preparando…' : 'Compartilhar'),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}
