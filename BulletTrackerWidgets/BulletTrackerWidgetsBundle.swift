//
//  BulletTrackerWidgetsBundle.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//
//  SwiftData migration (bt-0002 Wave 4): the widget process opens its own
//  `ModelContext` from `DataStore.shared` (which is in both targets and points at
//  the same App-Group SQLite store as the main app). `CompleteHabitIntent` runs
//  async with a fresh per-perform context; the timeline provider builds one per
//  load. CloudKit mirroring lives inside `DataStore.shared`'s `ModelContainer`,
//  so no explicit `CloudKit` import is needed here.
//
//  bt-0011: the widget mirrors the app's Today row — `[tile] name ▪▪▫▪▪▫◻` —
//  using the shared `DaySquare` / `HabitIconTile` / `AppTheme`, scores with
//  `HabitWinRule` (a slip is not a win), uses text styles + `@ScaledMetric`,
//  and marks its coloured parts `.widgetAccentable()` for the tinted / clear
//  Home Screen styles.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Widget Entry

struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    /// The seven days ending today, oldest first.
    let days: [Date]
    let habits: [WidgetHabit]
    let positiveDone: Int
    let positiveTotal: Int
    let avoidanceTotal: Int
    let slips: Int

    var isEmpty: Bool { habits.isEmpty }
    var clean: Int { avoidanceTotal - slips }

    var progress: Double {
        guard positiveTotal > 0 else { return 0 }
        return Double(positiveDone) / Double(positiveTotal)
    }

    /// "5 of 8 done · 3 clean" — same wording as the app's Today header.
    var summaryText: String {
        if positiveTotal == 0 && avoidanceTotal == 0 { return "No habits today" }
        var parts: [String] = []
        if positiveTotal > 0 {
            parts.append(positiveDone == positiveTotal ? "All \(positiveTotal) done" : "\(positiveDone) of \(positiveTotal) done")
        }
        if avoidanceTotal > 0 {
            parts.append(slips == 0 ? "\(clean) clean" : "\(slips) slip\(slips == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Widget Habit Model

struct WidgetHabit: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let style: CompletionStyle
    /// Raw completion state per day in `HabitWidgetEntry.days` (0 = not logged).
    let weekStates: [Int]
    /// Whether that day may be logged (after the habit's start date).
    let weekEditable: [Bool]

    var todayState: Int { weekStates.last ?? 0 }
    var isNegativeHabit: Bool { style == .avoidance }
}

// MARK: - Complete Habit Intent

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as completed")

    @Parameter(title: "Habit ID")
    var habitID: String

    @Parameter(title: "Habit Name")
    var habitName: String

    init() {
        self.habitID = ""
        self.habitName = ""
    }

    init(habitID: String, habitName: String) {
        self.habitID = habitID
        self.habitName = habitName
    }

    func perform() async throws -> some IntentResult {
        let context = ModelContext(DataStore.shared)
        toggleHabitCompletion(habitID: habitID, in: context)
        return .result()
    }

    /// Same rules as the app's Today row: simple toggles, multi-state cycles
    /// success → partial → tried → clear, avoidance toggles "slipped" (`.failure`).
    private func toggleHabitCompletion(habitID: String, in context: ModelContext) {
        guard let habitUUID = UUID(uuidString: habitID) else { return }

        // Habit-fetch stays the in-Swift filter over the habit set (small N,
        // dodges `#Predicate`-on-optional-UUID; same rationale Wave 3a noted).
        let allHabits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = allHabits.first(where: { $0.id == habitUUID }) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let optHabitUUID: UUID? = habitUUID
        var entryDescriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == optHabitUUID && entry.date >= today && entry.date < tomorrow
            }
        )
        entryDescriptor.fetchLimit = 1
        let existingEntry = (try? context.fetch(entryDescriptor))?.first

        let current = existingEntry.map { Int($0.effectiveCompletionState.rawValue) } ?? 0
        let next = nextState(after: current, style: habit.completionStyle)

        if let entry = existingEntry {
            if next == 0 {
                context.delete(entry)
            } else {
                entry.completionState = CompletionState(rawValue: Int16(next)) ?? .success
            }
        } else if next != 0 {
            let newEntry = HabitEntry(date: today, completionState: CompletionState(rawValue: Int16(next)) ?? .success, habit: habit)
            context.insert(newEntry)
        }

        try? context.save()

        let appGroupDefaults = UserDefaults(suiteName: "group.db23.Bullet-Tracker")
        appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: "lastWidgetUpdate")
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }

    private func nextState(after current: Int, style: CompletionStyle) -> Int {
        switch style {
        case .avoidance: return current == 0 ? 3 : 0
        case .simple: return current == 0 ? 1 : 0
        case .multiState:
            switch current {
            case 0: return 1
            case 1: return 2
            case 2: return 3
            default: return 0
            }
        }
    }
}

// MARK: - Timeline Provider

struct HabitWidgetProvider: TimelineProvider {
    private let calendar = Calendar.current

    func placeholder(in context: Context) -> HabitWidgetEntry {
        Self.sampleEntry()
    }

    /// Sample data for the gallery placeholder and the previews.
    static func sampleEntry() -> HabitWidgetEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return HabitWidgetEntry(
            date: Date(),
            days: days,
            habits: [
                WidgetHabit(id: UUID(), name: "Workout", icon: "figure.run", color: AppTheme.accentHex, style: .simple,
                            weekStates: [1, 1, 0, 1, 1, 0, 1], weekEditable: Array(repeating: true, count: 7)),
                WidgetHabit(id: UUID(), name: "Read", icon: "book.fill", color: "#5856D6", style: .simple,
                            weekStates: [1, 1, 1, 1, 1, 1, 0], weekEditable: Array(repeating: true, count: 7)),
                WidgetHabit(id: UUID(), name: "Alcohol", icon: "wineglass.fill", color: "#FF2D55", style: .avoidance,
                            weekStates: [0, 0, 3, 0, 0, 0, 0], weekEditable: Array(repeating: true, count: 7))
            ],
            positiveDone: 1, positiveTotal: 2, avoidanceTotal: 1, slips: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> ()) {
        let entry = loadEntry()
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        let nextRefresh: Date
        if hour >= 6 && hour < 23 {
            nextRefresh = now.addingTimeInterval(15 * 60)
        } else {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 6
            components.minute = 0
            if hour >= 23, let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 6
                components.minute = 0
            }
            nextRefresh = calendar.date(from: components) ?? now.addingTimeInterval(3600)
        }

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    // MARK: Data

    /// The seven days ending today, oldest first.
    private func weekDays() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private func loadEntry() -> HabitWidgetEntry {
        // Per-load context tied to this thread — SwiftData doesn't need the old
        // `context.perform { ... }` queue confinement Core Data required.
        let context = ModelContext(DataStore.shared)
        let days = weekDays()
        let today = days.last ?? calendar.startOfDay(for: Date())
        let habits = fetchTodaysHabits(in: context, today: today)
        let statesByHabit = fetchWeekStates(for: habits, days: days, in: context)

        var positiveDone = 0, positiveTotal = 0, avoidanceTotal = 0, slips = 0

        let widgetHabits: [WidgetHabit] = habits.map { habit in
            let id = habit.id ?? UUID()
            let states = statesByHabit[id] ?? Array(repeating: 0, count: days.count)
            let editable = days.map { day in
                guard let start = habit.startDate else { return true }
                return calendar.startOfDay(for: day) >= calendar.startOfDay(for: start)
            }

            let todayState = CompletionState(rawValue: Int16(states.last ?? 0))
            if habit.completionStyle == .avoidance {
                avoidanceTotal += 1
                if HabitWinRule.isLogged(state: todayState) { slips += 1 }
            } else {
                positiveTotal += 1
                if HabitWinRule.isWin(style: habit.completionStyle, state: todayState, isFuture: false) { positiveDone += 1 }
            }

            return WidgetHabit(
                id: id,
                name: habit.name ?? "Unnamed",
                icon: habit.icon ?? "circle",
                color: habit.color ?? AppTheme.accentHex,
                style: habit.completionStyle,
                weekStates: states,
                weekEditable: editable
            )
        }

        return HabitWidgetEntry(
            date: Date(),
            days: days,
            habits: widgetHabits,
            positiveDone: positiveDone,
            positiveTotal: positiveTotal,
            avoidanceTotal: avoidanceTotal,
            slips: slips
        )
    }

    private func fetchTodaysHabits(in context: ModelContext, today: Date) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)]
        )
        let allHabits = (try? context.fetch(descriptor)) ?? []
        return allHabits.filter {
            HabitFrequency.shouldTrack(
                frequency: $0.frequency,
                on: today,
                customDays: $0.customDays,
                startDate: $0.startDate
            )
        }
    }

    /// One indexed fetch over the 7-day window, partitioned by habit in Swift
    /// (same shape as the app's `HabitStore.allEntriesByDay`).
    private func fetchWeekStates(for habits: [Habit], days: [Date], in context: ModelContext) -> [UUID: [Int]] {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return [:] }

        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in entry.date >= first && entry.date < end }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        let wanted = Set(habits.compactMap { $0.id })

        var byHabitAndDay: [UUID: [Date: Int]] = [:]
        for entry in entries {
            guard let id = entry.habit?.id, wanted.contains(id) else { continue }
            byHabitAndDay[id, default: [:]][calendar.startOfDay(for: entry.date)] = Int(entry.effectiveCompletionState.rawValue)
        }

        var result: [UUID: [Int]] = [:]
        for id in wanted {
            let perDay = byHabitAndDay[id] ?? [:]
            result[id] = days.map { perDay[calendar.startOfDay(for: $0)] ?? 0 }
        }
        return result
    }
}

// MARK: - Main Widget View

struct HabitWidgetView: View {
    let entry: HabitWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            if entry.isEmpty {
                emptyStateView
            } else {
                switch widgetFamily {
                case .systemSmall:
                    SmallHabitWidget(entry: entry)
                case .systemLarge:
                    HabitGridWidget(entry: entry, maxRows: 8, showsSummary: true)
                default:
                    HabitGridWidget(entry: entry, maxRows: 4, showsSummary: false)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Habits Today")
                .font(.headline)
            Text("Open the app to add habits")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small: count ring + clean/slip line

struct SmallHabitWidget: View {
    let entry: HabitWidgetEntry
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(
                        entry.progress >= 1.0 ? AppTheme.success : AppTheme.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()

                VStack(spacing: 0) {
                    Text("\(entry.positiveDone)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    Text("of \(entry.positiveTotal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)

            if entry.avoidanceTotal > 0 {
                Text(entry.slips == 0 ? "\(entry.clean) clean" : "\(entry.slips) slip\(entry.slips == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.slips == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(AppTheme.failed))
            } else {
                Text(entry.progress >= 1.0 ? "All done" : "\(entry.positiveTotal - entry.positiveDone) to go")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(entry.summaryText)")
    }
}

// MARK: - Medium / Large: the Today rows

struct HabitGridWidget: View {
    let entry: HabitWidgetEntry
    let maxRows: Int
    let showsSummary: Bool

    @ScaledMetric(relativeTo: .caption) private var squareSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var tileSize: CGFloat = 22

    private var slotWidth: CGFloat { squareSize + 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsSummary {
                Text(entry.summaryText)
                    .font(.headline)
                    .padding(.bottom, 2)
            }

            // Weekday letters over the squares.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(entry.days, id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .frame(width: slotWidth)
                }
            }
            .accessibilityHidden(true)

            ForEach(entry.habits.prefix(maxRows)) { habit in
                WidgetHabitRow(habit: habit, days: entry.days, squareSize: squareSize, slotWidth: slotWidth, tileSize: tileSize)
            }

            if entry.habits.count > maxRows {
                Text("+\(entry.habits.count - maxRows) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Row

struct WidgetHabitRow: View {
    let habit: WidgetHabit
    let days: [Date]
    let squareSize: CGFloat
    let slotWidth: CGFloat
    let tileSize: CGFloat

    private var habitColor: Color { Color(hex: habit.color) }
    private var isTodayLogged: Bool { habit.todayState != 0 }

    var body: some View {
        HStack(spacing: 8) {
            HabitIconTile(systemImage: habit.icon, colorHex: habit.color, size: tileSize, font: .caption)
                .widgetAccentable()

            Text(habit.name)
                .font(.caption)
                .foregroundStyle(isTodayLogged && !habit.isNegativeHabit ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, _ in
                    let isToday = index == days.count - 1
                    if isToday {
                        Button(intent: CompleteHabitIntent(habitID: habit.id.uuidString, habitName: habit.name)) {
                            square(at: index, isToday: true)
                                .frame(width: slotWidth, height: slotWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(habit.name)
                        .accessibilityValue(todayAccessibilityValue)
                    } else {
                        square(at: index, isToday: false)
                            .frame(width: slotWidth)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func square(at index: Int, isToday: Bool) -> some View {
        let state = habit.weekStates[index]
        let editable = habit.weekEditable[index]
        let isCleanAvoidanceWin = habit.isNegativeHabit && state == 0 && !isToday && editable

        Group {
            if isCleanAvoidanceWin {
                DaySquare(size: squareSize, style: .filled(habitColor))
            } else if state != 0 {
                DaySquare(size: squareSize, style: .filled(color(forState: state))) {
                    if isToday {
                        Image(systemName: symbol(forState: state))
                            .font(.system(size: squareSize * 0.55, weight: .bold))
                            .foregroundStyle(AppTheme.readableForeground(onHex: hex(forState: state)))
                    }
                }
            } else if isToday {
                DaySquare(size: squareSize, style: .outlined(habitColor))
            } else {
                DaySquare(size: squareSize, style: .empty)
            }
        }
        .opacity(editable ? 1 : 0.35)
        .widgetAccentable(state != 0 || isCleanAvoidanceWin)
    }

    private func hex(forState state: Int) -> String {
        if habit.isNegativeHabit { return AppTheme.failedHex }
        if habit.style != .multiState { return habit.color }
        switch state {
        case 2: return AppTheme.partialHex
        case 3: return AppTheme.failedHex
        default: return AppTheme.successHex
        }
    }

    private func color(forState state: Int) -> Color { Color(hex: hex(forState: state)) }

    private func symbol(forState state: Int) -> String {
        if habit.isNegativeHabit { return "xmark" }
        switch state {
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark"
        default: return "checkmark"
        }
    }

    private var todayAccessibilityValue: String {
        if habit.isNegativeHabit { return isTodayLogged ? "Slipped today" : "Clean so far" }
        switch habit.todayState {
        case 0: return "Not done"
        case 2: return "Partial"
        case 3: return "Tried"
        default: return "Done"
        }
    }
}

// MARK: - Widget Configuration

struct HabitTrackerWidget: Widget {
    let kind: String = "HabitTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Habits")
        .description("Your week at a glance. Tap today's square to log a habit.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetProvider.sampleEntry()
}

#Preview("Large", as: .systemLarge) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetProvider.sampleEntry()
}

// MARK: - Bundle

@main
struct BulletTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HabitTrackerWidget()
    }
}
