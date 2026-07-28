// widgets_preview_screen.dart — Galeria de widgets do ReadLog
// Exibe todos os 15 widgets + o Painel do Leitor com dados de exemplo.

import 'package:flutter/material.dart';
import '../../../../theme/readlog_theme.dart';
import '../widgets/home_widgets.dart';
import '../widgets/reader_panel_widget.dart';

class WidgetsPreviewScreen extends StatelessWidget {
  const WidgetsPreviewScreen({super.key});

  // ── Dados de exemplo ──────────────────────────────────────────────────────
  static final _meeting =
      DateTime.now().add(const Duration(days: 1, hours: 3));
  static final _countdown =
      DateTime.now().add(const Duration(days: 3, hours: 7));
  static final _heatmap = [
    true,  false, true,  true,  true,  true,  false,
    true,  true,  true,  false, true,  true,  true,
    false, true,  true,  true,  true,  false, true,
    true,  true,  false, true,  true,  true,  true,
  ];
  static final _friendEvents = [
    const FriendEvent(
        name: 'Lucas',
        action: 'terminou',
        bookTitle: '1984',
        type: 'finished'),
    const FriendEvent(
        name: 'Maria',
        action: 'começou',
        bookTitle: 'O Hobbit',
        type: 'started'),
    const FriendEvent(
        name: 'Pedro',
        action: 'ofensiva de',
        bookTitle: '38 dias',
        type: 'streak'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReadLogColors.inkAlt,
      appBar: AppBar(
        backgroundColor: ReadLogColors.ink,
        foregroundColor: ReadLogColors.cream,
        title: Text(
          'Widgets',
          style: ReadLogType.display(size: 18, color: ReadLogColors.brassLight),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: ReadLogColors.cream.withValues(alpha: 0.1)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Painel do Leitor ─────────────────────────────────────────
          _Section(label: 'Painel do Leitor', tag: 'destaque'),
          ReaderPanelWidget(
            bookTitle: 'O Hobbit',
            bookAuthor: 'J.R.R. Tolkien',
            currentPage: 182,
            totalPages: 320,
            streakDays: 38,
            todayPages: 18,
            goalPages: 30,
            nextMeetingLabel: 'Clube amanhã às 20h',
            quote: 'Começar é de todos; perseverar é dos santos.',
            quoteAuthor: 'São Josemaria Escrivá',
          ),

          // ── W1: Livro Atual ──────────────────────────────────────────
          const _Section(label: 'W1 · Livro Atual'),
          CurrentBookWidget(
            title: 'Hábitos Atômicos',
            author: 'James Clear',
            currentPage: 182,
            totalPages: 320,
          ),

          // ── W2: Meta Diária ──────────────────────────────────────────
          const _Section(label: 'W2 · Meta Diária'),
          const DailyGoalWidget(
            current: 18,
            target: 30,
            unit: 'páginas',
          ),

          // ── W3: Ofensiva ─────────────────────────────────────────────
          const _Section(label: 'W3 · Ofensiva'),
          const StreakWidget(
            days: 43,
            motivationalText: 'Continue firme.',
          ),

          // ── W4: Próximo Encontro ─────────────────────────────────────
          const _Section(label: 'W4 · Próximo Encontro'),
          NextMeetingWidget(
            clubName: 'Clube dos Hobits',
            bookTitle: 'O Hobbit',
            scheduledAt: _meeting,
          ),

          // ── W5: Calendário ───────────────────────────────────────────
          const _Section(label: 'W5 · Calendário'),
          const CalendarWidget(
            goalDone: true,
            clubMeetingTime: 'Clube às 20h',
            reminder: 'Ler Capítulo 6',
          ),

          // ── W6: Tempo de Leitura ─────────────────────────────────────
          const _Section(label: 'W6 · Tempo de Leitura'),
          const ReadingTimeWidget(
            totalMinutes: 52,
            pages: 28,
          ),

          // ── W7: Frase do Dia ─────────────────────────────────────────
          const _Section(label: 'W7 · Frase do Dia'),
          const QuoteWidget(
            quote: 'Somos aquilo que fazemos repetidamente.',
            author: 'Aristóteles',
          ),

          // ── W8: Continue de Onde Parou ───────────────────────────────
          const _Section(label: 'W8 · Continue de Onde Parou'),
          ContinueReadingWidget(
            title: 'O Hobbit',
            page: 154,
          ),

          // ── W9: Biblioteca ───────────────────────────────────────────
          const _Section(label: 'W9 · Biblioteca'),
          const LibraryStatsWidget(
            reading: 3,
            wantToRead: 28,
            read: 54,
          ),

          // ── W10: Amigos ──────────────────────────────────────────────
          const _Section(label: 'W10 · Amigos'),
          FriendsActivityWidget(events: _friendEvents),

          // ── W11: Clube ───────────────────────────────────────────────
          const _Section(label: 'W11 · Clube'),
          const ClubProgressWidget(
            clubName: 'Clube dos Hobits',
            bookTitle: 'O Hobbit',
            progress: 0.45,
            nextMeetingLabel: 'Sábado às 19h',
          ),

          // ── W12: Sessão Rápida ───────────────────────────────────────
          const _Section(label: 'W12 · Sessão Rápida'),
          const QuickSessionWidget(bookTitle: 'O Hobbit'),

          // ── W13: Heatmap ─────────────────────────────────────────────
          const _Section(label: 'W13 · Heatmap'),
          HeatmapWidget(days: _heatmap),

          // ── W14: Conquista ───────────────────────────────────────────
          const _Section(label: 'W14 · Conquista'),
          const AchievementWidget(
            name: '100 Horas',
            description: 'Cem horas de leitura registradas',
            icon: Icons.emoji_events_outlined,
            isNew: true,
          ),

          // ── W15: Countdown ───────────────────────────────────────────
          const _Section(label: 'W15 · Countdown'),
          CountdownWidget(
            eventName: 'Clube do Livro',
            eventDate: _countdown,
          ),
        ],
      ),
    );
  }
}

// ── Separador de seção ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final String? tag;

  const _Section({required this.label, this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: ReadLogType.mono(
                  size: 10,
                  weight: FontWeight.w600,
                  color: ReadLogColors.cream.withValues(alpha: 0.4)),
            ),
          ),
          if (tag != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ReadLogColors.brass.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: ReadLogColors.brass.withValues(alpha: 0.4)),
              ),
              child: Text(
                tag!.toUpperCase(),
                style: ReadLogType.mono(
                    size: 9,
                    weight: FontWeight.w600,
                    color: ReadLogColors.brassLight),
              ),
            ),
        ],
      ),
    );
  }
}
