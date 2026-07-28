import 'dart:io';

import 'package:home_widget/home_widget.dart';
import '../../features/inspiration/data/inspiration_quotes.dart';
import 'widget_keys.dart';
import 'widget_updater.dart';

/// Ponto único de atualização de widgets nativos (Android / iOS).
///
/// Nenhuma feature deve chamar [HomeWidget] diretamente —
/// toda atualização passa por aqui.
///
/// Exemplo de uso:
/// ```dart
/// await WidgetManager.updateAll(
///   book: currentBook,
///   streak: 38,
///   dailyGoal: 18,
///   dailyGoalTarget: 30,
///   quote: pick,
/// );
/// ```
abstract final class WidgetManager {
  /// Inicializa o plugin. Deve ser chamado uma vez, antes de [runApp].
  static Future<void> init() async {
    // setAppGroupId é exclusivo do iOS (App Groups).
    // No Android o método não existe e lançaria MissingPluginException.
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(WidgetKeys.iosAppGroup);
    }
  }

  // ── Ofensiva ──────────────────────────────────────────────────────────────

  /// Atualiza apenas os dados de ofensiva e força re-render.
  static Future<void> updateStreak({
    required int streak,
    required int streakRecord,
  }) async {
    await Future.wait([
      WidgetUpdater.save(WidgetKeys.streak, streak),
      WidgetUpdater.save(WidgetKeys.streakRecord, streakRecord),
    ]);
    await WidgetUpdater.updateAll();
  }

  // ── Livro atual ───────────────────────────────────────────────────────────

  /// Atualiza os dados do livro em leitura e força re-render.
  static Future<void> updateCurrentBook({
    required String title,
    String? author,
    required int currentPage,
    required int totalPages,
  }) async {
    final progress =
        totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;
    await Future.wait([
      WidgetUpdater.save(WidgetKeys.currentBookTitle, title),
      WidgetUpdater.save(WidgetKeys.currentBookAuthor, author ?? ''),
      WidgetUpdater.save(WidgetKeys.currentPage, currentPage),
      WidgetUpdater.save(WidgetKeys.totalPages, totalPages),
      WidgetUpdater.save(WidgetKeys.readingProgress, progress),
    ]);
    await WidgetUpdater.updateAll();
  }

  // ── Meta diária ───────────────────────────────────────────────────────────

  /// Atualiza o progresso da meta diária e força re-render.
  static Future<void> updateDailyGoal({
    required int current,
    required int target,
  }) async {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    await Future.wait([
      WidgetUpdater.save(WidgetKeys.dailyGoal, current),
      WidgetUpdater.save(WidgetKeys.dailyGoalTarget, target),
      WidgetUpdater.save(WidgetKeys.dailyGoalProgress, progress),
    ]);
    await WidgetUpdater.updateAll();
  }

  // ── Frase do dia ──────────────────────────────────────────────────────────

  /// Atualiza a frase do dia e força re-render.
  static Future<void> updateQuote(InspirationQuote quote) async {
    await Future.wait([
      WidgetUpdater.save(WidgetKeys.quote, quote.quote),
      WidgetUpdater.save(WidgetKeys.quoteAuthor, quote.author ?? ''),
    ]);
    await WidgetUpdater.updateAll();
  }

  // ── Clube do livro ────────────────────────────────────────────────────────

  /// Atualiza as informações do próximo encontro do clube e força re-render.
  static Future<void> updateClub({
    required String clubName,
    String? bookTitle,
    DateTime? nextMeeting,
  }) async {
    String meetingLabel = '';
    String meetingTime = '';

    if (nextMeeting != null) {
      final now = DateTime.now();
      final diff = nextMeeting.difference(DateTime(now.year, now.month, now.day)).inDays;

      meetingLabel = switch (diff) {
        0 => 'Clube hoje',
        1 => 'Clube amanhã',
        _ => 'Clube em $diff dias',
      };

      final h = nextMeeting.hour.toString().padLeft(2, '0');
      final m = nextMeeting.minute.toString().padLeft(2, '0');
      meetingTime = '$h:$m';
    }

    await Future.wait([
      WidgetUpdater.save(WidgetKeys.clubName, clubName),
      WidgetUpdater.save(WidgetKeys.clubBookTitle, bookTitle ?? ''),
      WidgetUpdater.save(WidgetKeys.clubNextMeeting, meetingLabel),
      WidgetUpdater.save(WidgetKeys.clubNextMeetingTime, meetingTime),
    ]);
    await WidgetUpdater.updateAll();
  }

  // ── Atualização completa ──────────────────────────────────────────────────

  /// Salva todos os dados de uma vez e força um único re-render.
  /// Use quando múltiplos conjuntos de dados mudam simultaneamente
  /// (ex.: ao finalizar uma sessão).
  static Future<void> updateAll({
    String? bookTitle,
    String? bookAuthor,
    int? currentPage,
    int? totalPages,
    int? streak,
    int? streakRecord,
    int? dailyGoal,
    int? dailyGoalTarget,
    InspirationQuote? quote,
    String? clubName,
    String? clubBookTitle,
    DateTime? clubNextMeeting,
  }) async {
    final saves = <Future<void>>[];

    if (bookTitle != null) {
      final cp = currentPage ?? 0;
      final tp = totalPages ?? 0;
      final progress = tp > 0 ? (cp / tp).clamp(0.0, 1.0) : 0.0;
      saves.addAll([
        WidgetUpdater.save(WidgetKeys.currentBookTitle, bookTitle),
        WidgetUpdater.save(WidgetKeys.currentBookAuthor, bookAuthor ?? ''),
        WidgetUpdater.save(WidgetKeys.currentPage, cp),
        WidgetUpdater.save(WidgetKeys.totalPages, tp),
        WidgetUpdater.save(WidgetKeys.readingProgress, progress),
      ]);
    }

    if (streak != null) {
      saves.add(WidgetUpdater.save(WidgetKeys.streak, streak));
    }
    if (streakRecord != null) {
      saves.add(WidgetUpdater.save(WidgetKeys.streakRecord, streakRecord));
    }

    if (dailyGoal != null && dailyGoalTarget != null) {
      final progress =
          dailyGoalTarget > 0 ? (dailyGoal / dailyGoalTarget).clamp(0.0, 1.0) : 0.0;
      saves.addAll([
        WidgetUpdater.save(WidgetKeys.dailyGoal, dailyGoal),
        WidgetUpdater.save(WidgetKeys.dailyGoalTarget, dailyGoalTarget),
        WidgetUpdater.save(WidgetKeys.dailyGoalProgress, progress),
      ]);
    }

    if (quote != null) {
      saves.addAll([
        WidgetUpdater.save(WidgetKeys.quote, quote.quote),
        WidgetUpdater.save(WidgetKeys.quoteAuthor, quote.author ?? ''),
      ]);
    }

    if (clubName != null) {
      String meetingLabel = '';
      String meetingTime = '';
      if (clubNextMeeting != null) {
        final now = DateTime.now();
        final diff =
            clubNextMeeting.difference(DateTime(now.year, now.month, now.day)).inDays;
        meetingLabel = switch (diff) {
          0 => 'Clube hoje',
          1 => 'Clube amanhã',
          _ => 'Clube em $diff dias',
        };
        final h = clubNextMeeting.hour.toString().padLeft(2, '0');
        final m = clubNextMeeting.minute.toString().padLeft(2, '0');
        meetingTime = '$h:$m';
      }
      saves.addAll([
        WidgetUpdater.save(WidgetKeys.clubName, clubName),
        WidgetUpdater.save(WidgetKeys.clubBookTitle, clubBookTitle ?? ''),
        WidgetUpdater.save(WidgetKeys.clubNextMeeting, meetingLabel),
        WidgetUpdater.save(WidgetKeys.clubNextMeetingTime, meetingTime),
      ]);
    }

    if (saves.isNotEmpty) {
      await Future.wait(saves);
    }

    await WidgetUpdater.updateAll();
  }
}
