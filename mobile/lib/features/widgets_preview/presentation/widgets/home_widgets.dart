// home_widgets.dart — Widgets 1–15 do ReadLog
// Cada classe é um widget individual reutilizável, seguindo o design system
// ReadLog (ReadLogColors / ReadLogType / IBM Plex Mono + Fraunces).

import 'package:flutter/material.dart';
import '../../../../../theme/lumen_theme.dart';

// ── Widget 1: Livro Atual ─────────────────────────────────────────────────────

class CurrentBookWidget extends StatelessWidget {
  final String title;
  final String author;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onTap;

  const CurrentBookWidget({
    super.key,
    required this.title,
    required this.author,
    required this.currentPage,
    required this.totalPages,
    this.onTap,
  });

  double get _progress =>
      totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0;

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).round();
    return _WidgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.menu_book_outlined, label: 'Lendo agora'),
          const SizedBox(height: 10),
          Text(title,
              style: LumenType.display(size: 15, color: LumenColors.cream),
              overflow: TextOverflow.ellipsis),
          Text(author,
              style:
                  LumenType.mono(size: 11, color: LumenColors.brassLight)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 5,
              backgroundColor: LumenColors.cream.withValues(alpha: 0.1),
              color: LumenColors.brass,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('p. $currentPage / $totalPages',
                  style: LumenType.mono(
                      size: 10,
                      color: LumenColors.cream.withValues(alpha: 0.5))),
              Text('$pct%',
                  style: LumenType.mono(
                      size: 10, color: LumenColors.brassLight)),
            ],
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.play_arrow_outlined,
            label: 'Continuar leitura',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

// ── Widget 2: Meta Diária ─────────────────────────────────────────────────────

class DailyGoalWidget extends StatelessWidget {
  final int current;
  final int target;
  final String unit; // 'páginas' | 'minutos'

  const DailyGoalWidget({
    super.key,
    required this.current,
    required this.target,
    required this.unit,
  });

  double get _progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
  bool get _done => current >= target;

  @override
  Widget build(BuildContext context) {
    final remaining = (target - current).clamp(0, target);
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.flag_outlined, label: 'Meta de Hoje'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 5,
              backgroundColor: LumenColors.cream.withValues(alpha: 0.1),
              color: _done ? LumenColors.sage : LumenColors.brass,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$current / $target $unit',
            style: LumenType.mono(size: 14, color: LumenColors.cream),
          ),
          const SizedBox(height: 2),
          Text(
            _done ? 'Meta atingida!' : 'Faltam $remaining $unit',
            style: LumenType.mono(
                size: 11,
                color: _done
                    ? LumenColors.sage
                    : LumenColors.cream.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Widget 3: Ofensiva ────────────────────────────────────────────────────────

class StreakWidget extends StatelessWidget {
  final int days;
  final String? motivationalText;

  const StreakWidget({super.key, required this.days, this.motivationalText});

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(
              icon: Icons.local_fire_department_outlined, label: 'Ofensiva'),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Text(
                  '$days',
                  style: LumenType.display(
                      size: 48, color: LumenColors.stamp),
                ),
                Text(
                  days == 1 ? 'dia consecutivo' : 'dias consecutivos',
                  style: LumenType.mono(
                      size: 12,
                      color: LumenColors.cream.withValues(alpha: 0.6)),
                ),
                if (motivationalText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"$motivationalText"',
                    style: LumenType.display(
                      size: 12,
                      color: LumenColors.brassLight,
                      italic: true,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget 4: Próximo Encontro ────────────────────────────────────────────────

class NextMeetingWidget extends StatelessWidget {
  final String clubName;
  final String bookTitle;
  final DateTime scheduledAt;
  final VoidCallback? onTap;

  const NextMeetingWidget({
    super.key,
    required this.clubName,
    required this.bookTitle,
    required this.scheduledAt,
    this.onTap,
  });

  String get _dayLabel {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    return '${_weekday(scheduledAt.weekday)}, em $diff dias';
  }

  static String _weekday(int w) => const [
        '',
        'Seg',
        'Ter',
        'Qua',
        'Qui',
        'Sex',
        'Sáb',
        'Dom',
      ][w];

  @override
  Widget build(BuildContext context) {
    final hour =
        '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
    return _WidgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(
              icon: Icons.groups_outlined, label: 'Clube do Livro'),
          const SizedBox(height: 10),
          Text(clubName,
              style: LumenType.display(size: 14, color: LumenColors.cream),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(bookTitle,
              style: LumenType.mono(
                  size: 12, color: LumenColors.brassLight),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_outlined,
                  size: 13, color: LumenColors.sage),
              const SizedBox(width: 4),
              Text('$_dayLabel · $hour',
                  style: LumenType.mono(
                      size: 11, color: LumenColors.sage)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget 5: Calendário ──────────────────────────────────────────────────────

class CalendarWidget extends StatelessWidget {
  final bool goalDone;
  final String? clubMeetingTime;
  final String? reminder;

  const CalendarWidget({
    super.key,
    required this.goalDone,
    this.clubMeetingTime,
    this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.calendar_today_outlined, label: 'Hoje'),
          const SizedBox(height: 10),
          _CalRow(
            icon: goalDone
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            label: 'Meta diária',
            done: goalDone,
          ),
          if (clubMeetingTime != null) ...[
            const SizedBox(height: 6),
            _CalRow(
              icon: Icons.groups_outlined,
              label: clubMeetingTime!,
              accent: true,
            ),
          ],
          if (reminder != null) ...[
            const SizedBox(height: 6),
            _CalRow(icon: Icons.notifications_outlined, label: reminder!),
          ],
        ],
      ),
    );
  }
}

class _CalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool accent;

  const _CalRow({
    required this.icon,
    required this.label,
    this.done = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? LumenColors.sage
        : accent
            ? LumenColors.brassLight
            : LumenColors.cream.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: LumenType.mono(size: 12, color: color)),
      ],
    );
  }
}

// ── Widget 6: Tempo de Leitura ────────────────────────────────────────────────

class ReadingTimeWidget extends StatelessWidget {
  final int totalMinutes;
  final int pages;

  const ReadingTimeWidget({
    super.key,
    required this.totalMinutes,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final label = h > 0 ? '${h}h ${m}min' : '${m}min';
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.timer_outlined, label: 'Hoje'),
          const SizedBox(height: 14),
          Text(label,
              style:
                  LumenType.display(size: 28, color: LumenColors.cream)),
          const SizedBox(height: 4),
          Text('$pages páginas lidas',
              style: LumenType.mono(
                  size: 12,
                  color: LumenColors.cream.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

// ── Widget 7: Frase do Dia ────────────────────────────────────────────────────

class QuoteWidget extends StatelessWidget {
  final String quote;
  final String author;

  const QuoteWidget({super.key, required this.quote, required this.author});

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(
              icon: Icons.format_quote_outlined, label: 'Frase do Dia'),
          const SizedBox(height: 12),
          Text(
            '"$quote"',
            style: LumenType.display(
                size: 13,
                color: LumenColors.cream.withValues(alpha: 0.9),
                italic: true),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— $author',
              style: LumenType.mono(
                  size: 11, color: LumenColors.brassLight),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget 8: Continue de Onde Parou ─────────────────────────────────────────

class ContinueReadingWidget extends StatelessWidget {
  final String title;
  final int page;
  final VoidCallback? onTap;

  const ContinueReadingWidget({
    super.key,
    required this.title,
    required this.page,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(
              icon: Icons.play_circle_outline, label: 'Continue lendo'),
          const SizedBox(height: 10),
          Text(title,
              style: LumenType.display(size: 15, color: LumenColors.cream),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Página $page',
              style: LumenType.mono(
                  size: 11,
                  color: LumenColors.cream.withValues(alpha: 0.55))),
          const SizedBox(height: 10),
          _ActionButton(
              icon: Icons.arrow_forward_outlined, label: 'Abrir', onTap: onTap),
        ],
      ),
    );
  }
}

// ── Widget 9: Biblioteca ──────────────────────────────────────────────────────

class LibraryStatsWidget extends StatelessWidget {
  final int reading;
  final int wantToRead;
  final int read;

  const LibraryStatsWidget({
    super.key,
    required this.reading,
    required this.wantToRead,
    required this.read,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(
              icon: Icons.library_books_outlined, label: 'Biblioteca'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BigStat(value: '$reading', label: 'Lendo'),
              _BigStat(value: '$wantToRead', label: 'Quero'),
              _BigStat(value: '$read', label: 'Lidos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;

  const _BigStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: LumenType.display(size: 26, color: LumenColors.cream)),
        Text(label,
            style: LumenType.mono(
                size: 10,
                color: LumenColors.cream.withValues(alpha: 0.5))),
      ],
    );
  }
}

// ── Widget 10: Amigos ─────────────────────────────────────────────────────────

class FriendEvent {
  final String name;
  final String action;
  final String bookTitle;
  final String type; // 'finished' | 'started' | 'streak'

  const FriendEvent({
    required this.name,
    required this.action,
    required this.bookTitle,
    required this.type,
  });
}

class FriendsActivityWidget extends StatelessWidget {
  final List<FriendEvent> events;

  const FriendsActivityWidget({super.key, required this.events});

  static IconData _iconForEvent(String type) {
    switch (type) {
      case 'finished':
        return Icons.check_circle_outline;
      case 'started':
        return Icons.play_arrow_outlined;
      case 'streak':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.auto_stories_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.people_outline, label: 'Amigos'),
          const SizedBox(height: 10),
          ...events.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(_iconForEvent(e.type),
                        size: 14, color: LumenColors.sage),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                              text: '${e.name} ',
                              style: LumenType.mono(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: LumenColors.cream)),
                          TextSpan(
                              text: '${e.action} ',
                              style: LumenType.mono(
                                  size: 11,
                                  color: LumenColors.cream
                                      .withValues(alpha: 0.6))),
                          TextSpan(
                              text: e.bookTitle,
                              style: LumenType.mono(
                                  size: 11,
                                  color: LumenColors.brassLight)),
                        ]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Widget 11: Clube ──────────────────────────────────────────────────────────

class ClubProgressWidget extends StatelessWidget {
  final String clubName;
  final String bookTitle;
  final double progress; // 0..1
  final String? nextMeetingLabel;
  final VoidCallback? onTap;

  const ClubProgressWidget({
    super.key,
    required this.clubName,
    required this.bookTitle,
    required this.progress,
    this.nextMeetingLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return _WidgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WidgetHeader(icon: Icons.groups_2_outlined, label: clubName),
          const SizedBox(height: 10),
          Text(bookTitle,
              style: LumenType.display(size: 14, color: LumenColors.cream),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: LumenColors.cream.withValues(alpha: 0.1),
              color: LumenColors.brass,
            ),
          ),
          const SizedBox(height: 4),
          Text('$pct% do clube',
              style: LumenType.mono(
                  size: 10,
                  color: LumenColors.cream.withValues(alpha: 0.5))),
          if (nextMeetingLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    size: 12, color: LumenColors.sage),
                const SizedBox(width: 4),
                Text(nextMeetingLabel!,
                    style: LumenType.mono(
                        size: 10, color: LumenColors.sage)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget 12: Sessão Rápida ──────────────────────────────────────────────────

class QuickSessionWidget extends StatelessWidget {
  final String? bookTitle;
  final VoidCallback? onTap;

  const QuickSessionWidget({super.key, this.bookTitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.play_circle_filled,
              size: 48, color: LumenColors.brass),
          const SizedBox(height: 10),
          Text(
            bookTitle != null ? bookTitle! : 'Iniciar leitura',
            style: LumenType.display(size: 14, color: LumenColors.cream),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('Toque para começar',
              style: LumenType.mono(
                  size: 10,
                  color: LumenColors.cream.withValues(alpha: 0.45))),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Widget 13: Heatmap ────────────────────────────────────────────────────────

class HeatmapWidget extends StatelessWidget {
  /// Lista de booleanos: true = leu naquele dia. Mais antigo primeiro. 14–28 itens.
  final List<bool> days;

  const HeatmapWidget({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WidgetHeader(icon: Icons.grid_view_outlined, label: 'Histórico'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: days.map((read) {
              return Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: read
                      ? LumenColors.sage.withValues(alpha: 0.8)
                      : LumenColors.cream.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Widget 14: Conquista ──────────────────────────────────────────────────────

class AchievementWidget extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final bool isNew;

  const AchievementWidget({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        children: [
          if (isNew) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: LumenColors.stamp.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text('NOVO SELO',
                  style: LumenType.mono(
                      size: 9,
                      weight: FontWeight.w600,
                      color: LumenColors.stamp)),
            ),
            const SizedBox(height: 8),
          ],
          Icon(icon, size: 40, color: LumenColors.brass),
          const SizedBox(height: 8),
          Text(name,
              style: LumenType.display(size: 15, color: LumenColors.cream),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(description,
              style: LumenType.mono(
                  size: 11,
                  color: LumenColors.cream.withValues(alpha: 0.6)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Widget 15: Countdown ──────────────────────────────────────────────────────

class CountdownWidget extends StatelessWidget {
  final String eventName;
  final DateTime eventDate;
  final VoidCallback? onTap;

  const CountdownWidget({
    super.key,
    required this.eventName,
    required this.eventDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final diff = eventDate.difference(DateTime.now());
    final days = diff.inDays;
    final hours = diff.inHours % 24;

    return _WidgetCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          const Icon(Icons.event_outlined,
              size: 24, color: LumenColors.brassLight),
          const SizedBox(height: 8),
          Text(
            days > 0 ? '$days' : '$hours',
            style: LumenType.display(size: 40, color: LumenColors.cream),
          ),
          Text(
            days > 0
                ? (days == 1 ? 'dia' : 'dias')
                : (hours == 1 ? 'hora' : 'horas'),
            style: LumenType.mono(
                size: 11,
                color: LumenColors.cream.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          Text('para',
              style: LumenType.mono(
                  size: 10,
                  color: LumenColors.cream.withValues(alpha: 0.4))),
          const SizedBox(height: 2),
          Text(eventName,
              style:
                  LumenType.mono(size: 12, color: LumenColors.brassLight),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Helpers internos compartilhados ───────────────────────────────────────────

class _WidgetCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _WidgetCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LumenColors.ink,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: LumenColors.cream.withValues(alpha: 0.12)),
        ),
        child: child,
      ),
    );
  }
}

class _WidgetHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WidgetHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: LumenColors.brassLight),
        const SizedBox(width: 6),
        Text(label,
            style: LumenType.mono(
                size: 11,
                weight: FontWeight.w600,
                color: LumenColors.brassLight)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: LumenColors.brass.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
          border:
              Border.all(color: LumenColors.brass.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: LumenColors.brass),
            const SizedBox(width: 6),
            Text(label,
                style: LumenType.mono(size: 11, color: LumenColors.brass)),
          ],
        ),
      ),
    );
  }
}
