import WidgetKit
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Helpers: leitura do App Group compartilhado com o app Flutter
// ─────────────────────────────────────────────────────────────────────────────

private let appGroupId = "group.com.readlog.readlog"

private func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
}

private func string(_ key: String, fallback: String = "") -> String {
    sharedDefaults()?.string(forKey: key) ?? fallback
}

private func integer(_ key: String, fallback: Int = 0) -> Int {
    sharedDefaults()?.integer(forKey: key) ?? fallback
}

private func float(_ key: String, fallback: Double = 0) -> Double {
    sharedDefaults()?.double(forKey: key) ?? fallback
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Ofensiva Widget
// ─────────────────────────────────────────────────────────────────────────────

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 7)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, streak: integer("streak")))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakEntry(date: .now, streak: integer("streak"))
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: family == .systemSmall ? 32 : 40))
            Text("\(entry.streak)")
                .font(.system(size: family == .systemSmall ? 28 : 36, weight: .bold))
                .foregroundColor(.primary)
            Text("dias")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Ofensiva")
        .description("Mostra sua sequência de dias lendo.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Livro Atual Widget
// ─────────────────────────────────────────────────────────────────────────────

struct CurrentBookEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let progress: Double
}

struct CurrentBookProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentBookEntry {
        CurrentBookEntry(date: .now, title: "O Hobbit", author: "J.R.R. Tolkien", currentPage: 182, totalPages: 320, progress: 0.56)
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentBookEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentBookEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [makeEntry()], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> CurrentBookEntry {
        CurrentBookEntry(
            date: .now,
            title: string("currentBookTitle", fallback: "—"),
            author: string("currentBookAuthor"),
            currentPage: integer("currentPage"),
            totalPages: integer("totalPages"),
            progress: float("readingProgress")
        )
    }
}

struct CurrentBookWidgetView: View {
    let entry: CurrentBookEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(family == .systemSmall ? 2 : 1)
            if family != .systemSmall, !entry.author.isEmpty {
                Text(entry.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if entry.totalPages > 0 {
                Text("Página \(entry.currentPage) de \(entry.totalPages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if entry.currentPage > 0 {
                Text("Página \(entry.currentPage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: entry.progress)
                .tint(Color.blue)
            Text("\(Int(entry.progress * 100))%")
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

struct CurrentBookWidget: Widget {
    let kind = "CurrentBookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentBookProvider()) { entry in
            CurrentBookWidgetView(entry: entry)
        }
        .configurationDisplayName("Livro Atual")
        .description("Mostra o livro que você está lendo agora.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Meta Diária Widget
// ─────────────────────────────────────────────────────────────────────────────

struct DailyGoalEntry: TimelineEntry {
    let date: Date
    let current: Int
    let target: Int
    let progress: Double
}

struct DailyGoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyGoalEntry {
        DailyGoalEntry(date: .now, current: 18, target: 30, progress: 0.6)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyGoalEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyGoalEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [makeEntry()], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> DailyGoalEntry {
        DailyGoalEntry(
            date: .now,
            current: integer("dailyGoal"),
            target: integer("dailyGoalTarget"),
            progress: float("dailyGoalProgress")
        )
    }
}

struct DailyGoalWidgetView: View {
    let entry: DailyGoalEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 8) {
            if family != .systemSmall {
                Text("Meta diária")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(entry.current) / \(entry.target)")
                .font(.system(size: family == .systemSmall ? 18 : 22, weight: .bold))
            Text("páginas")
                .font(.caption2)
                .foregroundColor(.secondary)
            ProgressView(value: entry.progress)
                .tint(Color.blue)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

struct DailyGoalWidget: Widget {
    let kind = "DailyGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyGoalProvider()) { entry in
            DailyGoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Meta Diária")
        .description("Mostra seu progresso de leitura do dia.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Frase do Dia Widget
// ─────────────────────────────────────────────────────────────────────────────

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
    let author: String
}

struct QuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, quote: "Somos aquilo que fazemos repetidamente.", author: "Aristóteles")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        // Atualiza à meia-noite
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.day! += 1
        components.hour = 0
        components.minute = 0
        let midnight = Calendar.current.date(from: components) ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [makeEntry()], policy: .after(midnight)))
    }

    private func makeEntry() -> QuoteEntry {
        QuoteEntry(
            date: .now,
            quote: string("quote"),
            author: string("quoteAuthor")
        )
    }
}

struct QuoteWidgetView: View {
    let entry: QuoteEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 8) {
            Text(""\(entry.quote)"")
                .font(family == .systemSmall ? .caption : .callout)
                .italic()
                .multilineTextAlignment(.center)
                .lineLimit(family == .systemSmall ? 3 : 5)
            if !entry.author.isEmpty {
                Text(entry.author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

struct QuoteWidget: Widget {
    let kind = "QuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Frase do Dia")
        .description("Uma frase para inspirar sua leitura hoje.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Clube Widget
// ─────────────────────────────────────────────────────────────────────────────

struct ClubEntry: TimelineEntry {
    let date: Date
    let clubName: String
    let bookTitle: String
    let nextMeeting: String
    let meetingTime: String
}

struct ClubProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClubEntry {
        ClubEntry(date: .now, clubName: "Clube do Livro", bookTitle: "O Hobbit", nextMeeting: "Clube amanhã", meetingTime: "20:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (ClubEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClubEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [makeEntry()], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> ClubEntry {
        ClubEntry(
            date: .now,
            clubName: string("clubName", fallback: "Clube do Livro"),
            bookTitle: string("clubBookTitle"),
            nextMeeting: string("clubNextMeeting"),
            meetingTime: string("clubNextMeetingTime")
        )
    }
}

struct ClubWidgetView: View {
    let entry: ClubEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.clubName)
                .font(.headline)
                .lineLimit(1)
            if !entry.bookTitle.isEmpty {
                Text(entry.bookTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if !entry.nextMeeting.isEmpty {
                Text(entry.nextMeeting)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.blue)
            }
            if !entry.meetingTime.isEmpty {
                Text(entry.meetingTime)
                    .font(.title2)
                    .bold()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

struct ClubWidget: Widget {
    let kind = "ClubWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClubProvider()) { entry in
            ClubWidgetView(entry: entry)
        }
        .configurationDisplayName("Clube do Livro")
        .description("Mostra o próximo encontro do seu clube.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Painel do Leitor (Dashboard) Widget
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardEntry: TimelineEntry {
    let date: Date
    let bookTitle: String
    let currentPage: Int
    let totalPages: Int
    let bookProgress: Double
    let streak: Int
    let dailyGoal: Int
    let dailyGoalTarget: Int
    let goalProgress: Double
    let quote: String
    let nextMeeting: String
    let meetingTime: String
}

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: .now, bookTitle: "O Hobbit", currentPage: 182, totalPages: 320, bookProgress: 0.56, streak: 38, dailyGoal: 18, dailyGoalTarget: 30, goalProgress: 0.6, quote: "Somos aquilo que fazemos repetidamente.", nextMeeting: "Clube amanhã", meetingTime: "20:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [makeEntry()], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> DashboardEntry {
        DashboardEntry(
            date: .now,
            bookTitle: string("currentBookTitle", fallback: "—"),
            currentPage: integer("currentPage"),
            totalPages: integer("totalPages"),
            bookProgress: float("readingProgress"),
            streak: integer("streak"),
            dailyGoal: integer("dailyGoal"),
            dailyGoalTarget: integer("dailyGoalTarget"),
            goalProgress: float("dailyGoalProgress"),
            quote: string("quote"),
            nextMeeting: string("clubNextMeeting"),
            meetingTime: string("clubNextMeetingTime")
        )
    }
}

struct DashboardWidgetView: View {
    let entry: DashboardEntry

    private var pagesLabel: String {
        entry.totalPages > 0
            ? "p. \(entry.currentPage)/\(entry.totalPages)"
            : "p. \(entry.currentPage)"
    }

    private var clubLabel: String {
        entry.meetingTime.isEmpty ? entry.nextMeeting : "\(entry.nextMeeting) · \(entry.meetingTime)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Livro + Ofensiva
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.bookTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(pagesLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("🔥")
                        .font(.title3)
                    Text("\(entry.streak)")
                        .font(.caption)
                        .bold()
                }
            }
            ProgressView(value: entry.bookProgress)
                .tint(Color.blue)

            Divider()

            // Meta
            HStack {
                Text("Meta")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.dailyGoal)/\(entry.dailyGoalTarget) pág.")
                    .font(.caption)
                    .bold()
            }
            ProgressView(value: entry.goalProgress)
                .tint(Color.blue)

            Divider()

            // Frase
            if !entry.quote.isEmpty {
                Text(""\(entry.quote)"")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Clube
            if !entry.nextMeeting.isEmpty {
                Text(clubLabel)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

struct ReaderDashboardWidget: Widget {
    let kind = "ReaderDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Painel do Leitor")
        .description("Livro, meta, ofensiva, frase e clube em uma só tela.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Bundle de Widgets
// ─────────────────────────────────────────────────────────────────────────────

@main
struct ReadlogWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        CurrentBookWidget()
        DailyGoalWidget()
        QuoteWidget()
        ClubWidget()
        ReaderDashboardWidget()
    }
}
