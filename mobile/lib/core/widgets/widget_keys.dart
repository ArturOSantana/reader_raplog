/// Chaves compartilhadas entre Flutter e as camadas nativas (Android / iOS).
///
/// Cada constante deve corresponder exatamente ao nome usado em:
/// - Android: `AppWidgetProvider` / layout XML (via `RemoteViews`)
/// - iOS: `UserDefaults` lido pelo `TimelineProvider`
abstract final class WidgetKeys {
  // ── Livro atual ───────────────────────────────────────────────────────────
  static const currentBookTitle = 'currentBookTitle';
  static const currentBookAuthor = 'currentBookAuthor';
  static const currentPage = 'currentPage';
  static const totalPages = 'totalPages';
  static const readingProgress = 'readingProgress'; // 0.0 – 1.0

  // ── Ofensiva ─────────────────────────────────────────────────────────────
  static const streak = 'streak';
  static const streakRecord = 'streakRecord';

  // ── Meta diária ──────────────────────────────────────────────────────────
  static const dailyGoal = 'dailyGoal';
  static const dailyGoalTarget = 'dailyGoalTarget';
  static const dailyGoalProgress = 'dailyGoalProgress'; // 0.0 – 1.0

  // ── Frase do dia ──────────────────────────────────────────────────────────
  static const quote = 'quote';
  static const quoteAuthor = 'quoteAuthor';

  // ── Clube do livro ────────────────────────────────────────────────────────
  static const clubName = 'clubName';
  static const clubNextMeeting = 'clubNextMeeting';
  static const clubNextMeetingTime = 'clubNextMeetingTime';
  static const clubBookTitle = 'clubBookTitle';

  // ── Android widget IDs ────────────────────────────────────────────────────
  static const androidStreakWidget = 'StreakWidget';
  static const androidCurrentBookWidget = 'CurrentBookWidget';
  static const androidDailyGoalWidget = 'DailyGoalWidget';
  static const androidQuoteWidget = 'QuoteWidget';
  static const androidClubWidget = 'ClubWidget';
  static const androidDashboardWidget = 'ReaderDashboardWidget';

  // ── iOS widget kind IDs ───────────────────────────────────────────────────
  static const iosAppGroup = 'group.com.readlog.readlog';
  static const iosStreakWidget = 'StreakWidget';
  static const iosCurrentBookWidget = 'CurrentBookWidget';
  static const iosDailyGoalWidget = 'DailyGoalWidget';
  static const iosQuoteWidget = 'QuoteWidget';
  static const iosClubWidget = 'ClubWidget';
  static const iosDashboardWidget = 'ReaderDashboardWidget';
}
