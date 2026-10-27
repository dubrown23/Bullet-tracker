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
//  bt-0016: the widget's one job is *log today without opening the app*.
//  Medium = 8 big tappable tiles, large = 12 + the day summary, small = ring.
//  Every habit visible, nothing scrolls, 56pt targets. Scored with
//  `HabitWinRule`; same `AppShape` / `AppTheme` as the app; text styles and
//  `.widgetAccentable()` for the tinted / clear Home Screen styles.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Widget Entry

struct HabitWidgetEntry: TimelineEntry {
    let date: Date
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
    /// Today's raw completion state (0 = not logged, 1 / 2 / 3, 4 = rest).
    let todayState: Int

    var isNegativeHabit: Bool { style == .avoidance }
    var isLogged: Bool { todayState != 0 }
    var isRest: Bool { todayState == Int(CompletionState.rest.rawValue) }
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

        // A widget tap is a hand write (bt-0018): stamp source + edit time so
        // the automatic grader leaves it alone and the cleanup pass keeps it.
        if let entry = existingEntry {
            if next == 0 {
                context.delete(entry)
            } else {
                entry.completionState = CompletionState(rawValue: Int16(next)) ?? .success
                entry.source = .hand
                entry.editedAt = Date()
            }
        } else if next != 0 {
            let newEntry = HabitEntry(date: today, completionState: CompletionState(rawValue: Int16(next)) ?? .success,
                                      habit: habit, source: .hand, editedAt: Date())
            context.insert(newEntry)
        }

        try? context.save()

        let appGroupDefaults = UserDefaults(suiteName: "group.db23.Bullet-Tracker")
        appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: "lastWidgetUpdate")
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }

    /// Rest (4) is never reached by tapping; tapping a rest tile clears it.
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

    /// Sample data for the gallery placeholder and the previews — Dustin's
    /// real eleven so the previews show the real density.
    static func sampleEntry() -> HabitWidgetEntry {
        func h(_ name: String, _ icon: String, _ color: String, _ style: CompletionStyle = .simple, _ state: Int = 0) -> WidgetHabit {
            WidgetHabit(id: UUID(), name: name, icon: icon, color: color, style: style, todayState: state)
        }
        let habits = [
            h("Diet", "fork.knife", "#FFCC00", .multiState, 1),
            h("Workout", "figure.run", "#007AFF", .simple, 1),
            h("Sauna", "flame.fill", "#FF2D55"),
            h("Pills", "pills.fill", "#5AC8FA", .simple, 1),
            h("Joovv", "light.strip.2", "#FF2D55"),
            h("Cold Tub", "thermometer.snowflake", "#004080"),
            h("Read", "book.fill", "#53433D"),
            h("Alcohol", "wineglass.fill", "#5856D6", .avoidance),
            h("Weed", "leaf.fill", "#34C759", .avoidance),
            h("Stretch", "figure.cooldown", AppTheme.accentHex),
            h("Sleep", "bed.double.fill", "#2E2B6B")
        ]
        return HabitWidgetEntry(date: Date(), habits: habits, positiveDone: 3, positiveTotal: 9, avoidanceTotal: 2, slips: 0)
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

    private func loadEntry() -> HabitWidgetEntry {
        // Per-load context tied to this thread — SwiftData doesn't need the old
        // `context.perform { ... }` queue confinement Core Data required.
        let context = ModelContext(DataStore.shared)
        let today = calendar.startOfDay(for: Date())
        let habits = fetchTodaysHabits(in: context, today: today)
        let todayStates = fetchTodayStates(for: habits, today: today, in: context)

        var positiveDone = 0, positiveTotal = 0, avoidanceTotal = 0, slips = 0

        let widgetHabits: [WidgetHabit] = habits.map { habit in
            let id = habit.id ?? UUID()
            let state = todayStates[id] ?? 0
            let typed = CompletionState(rawValue: Int16(state))

            if habit.completionStyle == .avoidance {
                avoidanceTotal += 1
                if HabitWinRule.isLogged(state: typed) { slips += 1 }
            } else if HabitWinRule.isNeutral(state: typed) {
                // Rest day: left out of "N of M done", same as the app's header.
            } else {
                positiveTotal += 1
                if HabitWinRule.isWin(style: habit.completionStyle, state: typed, isFuture: false) { positiveDone += 1 }
            }

            return WidgetHabit(
                id: id,
                name: habit.name ?? "Unnamed",
                icon: habit.icon ?? "circle",
                color: habit.color ?? AppTheme.accentHex,
                style: habit.completionStyle,
                todayState: state
            )
        }

        return HabitWidgetEntry(
            date: Date(),
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

    /// One indexed fetch over today's entries, keyed by habit id.
    private func fetchTodayStates(for habits: [Habit], today: Date, in context: ModelContext) -> [UUID: Int] {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [:] }
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in entry.date >= today && entry.date < tomorrow }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        let wanted = Set(habits.compactMap { $0.id })
        var result: [UUID: Int] = [:]
        for entry in entries {
            guard let id = entry.habit?.id, wanted.contains(id) else { continue }
            result[id] = Int(entry.effectiveCompletionState.rawValue)
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
                    HabitTileGridWidget(entry: entry, maxTiles: 12, showsSummary: true)
                default:
                    HabitTileGridWidget(entry: entry, maxTiles: 8, showsSummary: false)
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

// MARK: - Medium / Large: tile grid

struct HabitTileGridWidget: View {
    let entry: HabitWidgetEntry
    let maxTiles: Int
    let showsSummary: Bool

    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 15
    @ScaledMetric(relativeTo: .headline) private var headerHeight: CGFloat = 22

    private let spacing: CGFloat = 8
    private let columnCount = 4

    /// When there are more habits than cells, the last cell becomes a "+N" tile
    /// (the Photos / Mail widget pattern) so the grid never needs a footer.
    private var overflow: Int { max(0, entry.habits.count - maxTiles) }
    private var shownHabits: ArraySlice<WidgetHabit> {
        entry.habits.prefix(overflow > 0 ? maxTiles - 1 : maxTiles)
    }
    private var cellCount: Int { shownHabits.count + (overflow > 0 ? 1 : 0) }
    private var rowCount: Int { max(1, (cellCount + columnCount - 1) / columnCount) }

    var body: some View {
        GeometryReader { geo in
            let tile = tileSize(in: geo.size)
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)

            VStack(alignment: .leading, spacing: spacing) {
                if showsSummary {
                    Text(entry.summaryText)
                        .font(.headline)
                        .foregroundStyle(entry.slips > 0 ? AnyShapeStyle(AppTheme.failed) : AnyShapeStyle(.primary))
                }

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(shownHabits) { habit in
                        HabitTileButton(habit: habit, tileSize: tile)
                    }
                    if overflow > 0 {
                        OverflowTile(count: overflow, tileSize: tile)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    /// Fit the tile to the family: the grid (tiles + name labels + gaps) must
    /// fill the widget without clipping, capped so a two-row medium and a
    /// three-row large both read as the same component.
    private func tileSize(in size: CGSize) -> CGFloat {
        let header = showsSummary ? headerHeight + spacing : 0
        let gridHeight = size.height - header - spacing * CGFloat(rowCount - 1)
        let byHeight = gridHeight / CGFloat(rowCount) - labelHeight - 4
        let byWidth = (size.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        return max(36, min(64, byHeight, byWidth))
    }
}

/// "+N" cell for habits that didn't fit. Tapping it opens the app (default
/// widget tap), which is where the rest of the list lives.
struct OverflowTile: View {
    let count: Int
    let tileSize: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            AppShape.rounded(tileSize)
                .fill(Color(.tertiarySystemFill))
                .frame(width: tileSize, height: tileSize)
                .overlay {
                    Text("+\(count)")
                        .font(.system(size: tileSize * 0.36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) more habits, open the app")
    }
}

// MARK: - Tile

/// One habit, one big tap. Not logged: icon on a tint of the habit colour.
/// Logged: solid state colour, white icon, a small state badge in the corner.
struct HabitTileButton: View {
    let habit: WidgetHabit
    let tileSize: CGFloat

    private var habitColor: Color { Color(hex: habit.color) }

    var body: some View {
        Button(intent: CompleteHabitIntent(habitID: habit.id.uuidString, habitName: habit.name)) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    AppShape.rounded(tileSize)
                        .fill(habit.isLogged ? fillColor : habitColor.opacity(0.14))
                        .frame(width: tileSize, height: tileSize)

                    // Icon scales with the tile so medium and large read the same.
                    Image(systemName: habit.icon)
                        .font(.system(size: tileSize * 0.42, weight: .medium))
                        .foregroundStyle(habit.isLogged ? AppTheme.readableForeground(onHex: fillHex) : habitColor)
                        .frame(width: tileSize, height: tileSize)

                    if habit.isLogged {
                        Image(systemName: badgeSymbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(fillColor)
                            .padding(3)
                            .background(Circle().fill(Color(.systemBackground)))
                            .offset(x: 4, y: 4)
                    }
                }
                .widgetAccentable()

                Text(habit.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isToggle)
    }

    private var fillHex: String {
        if habit.isNegativeHabit { return AppTheme.failedHex }
        if habit.isRest { return AppTheme.restHex }
        if habit.style != .multiState { return habit.color }
        switch habit.todayState {
        case 2: return AppTheme.partialHex
        case 3: return AppTheme.failedHex
        default: return AppTheme.successHex
        }
    }

    private var fillColor: Color { Color(hex: fillHex) }

    private var badgeSymbol: String {
        if habit.isNegativeHabit { return "xmark.circle.fill" }
        switch habit.todayState {
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark.circle.fill"
        case 4: return "zzz"
        default: return "checkmark.circle.fill"
        }
    }

    private var accessibilityValue: String {
        if habit.isNegativeHabit { return habit.isLogged ? "Slipped today" : "Clean so far" }
        switch habit.todayState {
        case 0: return "Not done"
        case 2: return "Partial"
        case 3: return "Tried"
        case 4: return "Rest day"
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
        .description("Tap a habit to log it for today.")
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
