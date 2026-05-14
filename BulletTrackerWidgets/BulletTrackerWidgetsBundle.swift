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

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Widget Entry

struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let completedCount: Int
    let totalCount: Int
    let isEmpty: Bool

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

// MARK: - Widget Habit Model

struct WidgetHabit: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let isCompleted: Bool
    let completionState: Int
    let needsDetails: Bool
    let isNegativeHabit: Bool
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

    private func toggleHabitCompletion(habitID: String, in context: ModelContext) {
        guard let habitUUID = UUID(uuidString: habitID) else { return }

        // Habit-fetch stays the in-Swift filter over the habit set (small N,
        // dodges `#Predicate`-on-optional-UUID; same rationale Wave 3a noted).
        let allHabits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = allHabits.first(where: { $0.id == habitUUID }) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // Today-entry lookup is an indexed `#Predicate` fetch over the date
        // range (Wave 4) — `habit.entries` walk faulted the whole relationship.
        let optHabitUUID: UUID? = habitUUID
        var entryDescriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == optHabitUUID && entry.date >= today && entry.date < tomorrow
            }
        )
        entryDescriptor.fetchLimit = 1
        let existingEntry = (try? context.fetch(entryDescriptor))?.first

        if let entry = existingEntry {
            let nextState = getNextCompletionState(current: Int(entry.completionState.rawValue), habit: habit)
            if nextState == 0 {
                context.delete(entry)
            } else {
                entry.completionState = CompletionState(rawValue: Int16(nextState)) ?? .success
            }
        } else {
            let newEntry = HabitEntry(date: today, completionState: .success, habit: habit)
            context.insert(newEntry)
        }

        try? context.save()

        let appGroupDefaults = UserDefaults(suiteName: "group.db23.Bullet-Tracker")
        appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: "lastWidgetUpdate")
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }

    private func getNextCompletionState(current: Int, habit: Habit) -> Int {
        if habit.completionStyle == .avoidance { return current == 0 ? 3 : 0 }
        if habit.completionStyle != .multiState { return current == 0 ? 1 : 0 }
        switch current {
        case 0: return 1
        case 1: return 2
        case 2: return 3
        case 3: return 0
        default: return 1
        }
    }
}

// MARK: - Timeline Provider

struct HabitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(
            date: Date(),
            habits: [
                WidgetHabit(id: UUID(), name: "Exercise", icon: "figure.walk", color: "#007AFF", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Reading", icon: "book", color: "#FF9500", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Meditate", icon: "leaf", color: "#34C759", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Journal", icon: "pencil.line", color: "#AF52DE", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Water", icon: "drop", color: "#5AC8FA", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false)
            ],
            completedCount: 2,
            totalCount: 5,
            isEmpty: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            loadHabitsEntry { entry in completion(entry) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> ()) {
        loadHabitsEntry { entry in
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)

            let nextRefresh: Date
            if hour >= 6 && hour < 23 {
                nextRefresh = now.addingTimeInterval(15 * 60)
            } else {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 6
                components.minute = 0
                if hour >= 23 {
                    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                        components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                        components.hour = 6
                        components.minute = 0
                    }
                }
                nextRefresh = calendar.date(from: components) ?? now.addingTimeInterval(3600)
            }

            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    private func loadHabitsEntry(completion: @escaping (HabitWidgetEntry) -> Void) {
        // Per-load context tied to this thread — SwiftData doesn't need the old
        // `context.perform { ... }` queue confinement Core Data required.
        let context = ModelContext(DataStore.shared)
        let habits = fetchTodaysHabits(in: context)

        let widgetHabits = habits.map { habit in
            let state = getCompletionState(for: habit, in: context)
            return WidgetHabit(
                id: habit.id ?? UUID(),
                name: habit.name ?? "Unnamed",
                icon: habit.icon ?? "checkmark.circle",
                color: habit.color ?? "#007AFF",
                isCompleted: state > 0,
                completionState: state,
                needsDetails: habit.completionStyle == .multiState || habit.detailKind != nil,
                isNegativeHabit: habit.completionStyle == .avoidance
            )
        }

        let completed = widgetHabits.filter(\.isCompleted).count
        let entry = HabitWidgetEntry(
            date: Date(),
            habits: widgetHabits,
            completedCount: completed,
            totalCount: widgetHabits.count,
            isEmpty: widgetHabits.isEmpty
        )

        completion(entry)
    }

    private func fetchTodaysHabits(in context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.order), SortDescriptor(\.name)]
        )
        let allHabits = (try? context.fetch(descriptor)) ?? []
        let today = Date()
        return allHabits.filter {
            HabitFrequency.shouldTrack(
                frequency: $0.frequency,
                on: today,
                customDays: $0.customDays,
                startDate: $0.startDate
            )
        }
    }

    private func getCompletionState(for habit: Habit, in context: ModelContext) -> Int {
        guard let habitID = habit.id else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // Wave 4: indexed `#Predicate` fetch instead of walking
        // `habit.entries`. With N habits on the widget timeline that walk used
        // to fault each habit's full entry history; this is index-backed and
        // limit-1 per habit.
        var descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == habitID && entry.date >= today && entry.date < tomorrow
            }
        )
        descriptor.fetchLimit = 1
        guard let todayEntry = (try? context.fetch(descriptor))?.first else { return 0 }
        return Int(todayEntry.completionState.rawValue)
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
                    LargeHabitWidget(entry: entry)
                default:
                    MediumHabitWidget(entry: entry)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Habits Today")
                .font(.system(size: 14, weight: .semibold))
            Text("Open app to add habits")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget: Progress Ring + Mini Habit Dots

struct SmallHabitWidget: View {
    let entry: HabitWidgetEntry

    var body: some View {
        VStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(
                        entry.progress >= 1.0 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(entry.completedCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("of \(entry.totalCount)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)

            // Habit color dots — shows each habit's status at a glance
            HStack(spacing: 5) {
                ForEach(entry.habits.prefix(6)) { habit in
                    Circle()
                        .fill(habit.isCompleted
                              ? (Color(hex: habit.color) ?? .blue)
                              : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget: Tappable Habit Circles Row

struct MediumHabitWidget: View {
    let entry: HabitWidgetEntry

    var body: some View {
        VStack(spacing: 10) {
            // Top: progress bar + count
            HStack(spacing: 8) {
                // Thin progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 5)

                        Capsule()
                            .fill(entry.progress >= 1.0 ? Color.green : Color.accentColor)
                            .frame(width: geo.size.width * entry.progress, height: 5)
                    }
                }
                .frame(height: 5)

                Text("\(entry.completedCount)/\(entry.totalCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            // Tappable habit circles
            HStack(spacing: 0) {
                ForEach(entry.habits.prefix(6)) { habit in
                    HabitCircleButton(habit: habit, size: 44, iconSize: 18, showName: true, nameSize: 9)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Large Widget: Header + Grid of Habit Circles

struct LargeHabitWidget: View {
    let entry: HabitWidgetEntry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Habits")
                        .font(.system(size: 15, weight: .bold))
                    Text(entry.progress >= 1.0
                         ? "All done!"
                         : "\(entry.completedCount) of \(entry.totalCount) complete")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Mini ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(
                            entry.progress >= 1.0 ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.completedCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(width: 32, height: 32)
            }

            // Grid of tappable circles
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entry.habits.prefix(8)) { habit in
                    HabitCircleButton(habit: habit, size: 52, iconSize: 22, showName: true, nameSize: 10)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Reusable Habit Circle Button

struct HabitCircleButton: View {
    let habit: WidgetHabit
    let size: CGFloat
    let iconSize: CGFloat
    let showName: Bool
    let nameSize: CGFloat

    private var habitColor: Color {
        Color(hex: habit.color) ?? .blue
    }

    var body: some View {
        Button(intent: CompleteHabitIntent(habitID: habit.id.uuidString, habitName: habit.name)) {
            VStack(spacing: 4) {
                ZStack {
                    if habit.isCompleted {
                        // Filled circle with state color
                        Circle()
                            .fill(stateColor)
                            .frame(width: size, height: size)

                        // State icon overlay
                        Image(systemName: stateIcon)
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        // Ring outline with habit color
                        Circle()
                            .fill(habitColor.opacity(0.1))
                            .frame(width: size, height: size)
                            .overlay(
                                Circle()
                                    .strokeBorder(habitColor.opacity(0.5), lineWidth: 2.5)
                            )

                        // Habit icon
                        Image(systemName: habit.icon)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundStyle(habitColor)
                    }
                }

                if showName {
                    Text(habit.name)
                        .font(.system(size: nameSize, weight: .medium))
                        .foregroundStyle(habit.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var stateColor: Color {
        if habit.isNegativeHabit { return .red }
        switch habit.completionState {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .green
        }
    }

    private var stateIcon: String {
        if habit.isNegativeHabit { return "xmark" }
        switch habit.completionState {
        case 1: return "checkmark"
        case 2: return "minus"
        case 3: return "xmark"
        default: return "checkmark"
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
        .description("Track your daily habits from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetEntry(
        date: Date(),
        habits: [
            WidgetHabit(id: UUID(), name: "Exercise", icon: "figure.walk", color: "#007AFF", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Reading", icon: "book", color: "#FF9500", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Meditate", icon: "leaf", color: "#34C759", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Journal", icon: "pencil.line", color: "#AF52DE", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Water", icon: "drop", color: "#5AC8FA", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false)
        ],
        completedCount: 2,
        totalCount: 5,
        isEmpty: false
    )
}

#Preview("Medium", as: .systemMedium) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetEntry(
        date: Date(),
        habits: [
            WidgetHabit(id: UUID(), name: "Exercise", icon: "figure.walk", color: "#007AFF", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Reading", icon: "book", color: "#FF9500", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Meditate", icon: "leaf", color: "#34C759", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Journal", icon: "pencil.line", color: "#AF52DE", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Water", icon: "drop", color: "#5AC8FA", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false)
        ],
        completedCount: 3,
        totalCount: 5,
        isEmpty: false
    )
}

#Preview("Large", as: .systemLarge) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetEntry(
        date: Date(),
        habits: [
            WidgetHabit(id: UUID(), name: "Exercise", icon: "figure.walk", color: "#007AFF", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Reading", icon: "book", color: "#FF9500", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Meditate", icon: "leaf", color: "#34C759", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Journal", icon: "pencil.line", color: "#AF52DE", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "Water", icon: "drop", color: "#5AC8FA", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
            WidgetHabit(id: UUID(), name: "No Sugar", icon: "xmark.octagon", color: "#FF3B30", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: true)
        ],
        completedCount: 3,
        totalCount: 6,
        isEmpty: false
    )
}

// MARK: - Bundle

@main
struct BulletTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HabitTrackerWidget()
    }
}
