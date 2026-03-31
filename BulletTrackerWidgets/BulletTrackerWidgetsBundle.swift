//
//  BulletTrackerWidgetsBundle.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import WidgetKit
import SwiftUI
import CoreData
import CloudKit
import AppIntents

// MARK: - Widget Entry

struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let isEmpty: Bool
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
        // Use the MAIN app's Core Data manager instead of a separate widget one
        let context = CoreDataManager.shared.container.viewContext

        await context.perform {
            do {
                try self.toggleHabitCompletion(habitID: self.habitID, context: context)
            } catch {
                // Widget toggle error - silent fail
            }
        }

        return .result()
    }
    
    private func toggleHabitCompletion(habitID: String, context: NSManagedObjectContext) throws {
        guard let habitUUID = UUID(uuidString: habitID) else {
            return
        }
        
        // Find the habit
        let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        habitRequest.predicate = NSPredicate(format: "id == %@", habitUUID as CVarArg)
        
        guard let habit = try context.fetch(habitRequest).first else {
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        
        // Find existing entry for today
        let entryRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                           habit,
                                           today as CVarArg,
                                           endOfDay as CVarArg)
        
        let existingEntries = try context.fetch(entryRequest)
        let existingEntry = existingEntries.first
        
        if let entry = existingEntry {
            // Cycle through completion states or delete
            let currentState = Int(entry.completionState)
            let nextState = getNextCompletionState(current: currentState, habit: habit)
            
            if nextState == 0 {
                // Delete the entry
                context.delete(entry)
            } else {
                // Update the state
                entry.completionState = Int16(nextState)
            }
        } else {
            // Create new entry with success state
            let newEntry = HabitEntry(context: context)
            newEntry.id = UUID()
            newEntry.habit = habit
            newEntry.date = today  // Use today (start of day) instead of Date()
            newEntry.completionState = 1 // Success
            newEntry.details = nil
        }
        
        // Save the context
        try context.save()
        
        // Signal to main app that widget made changes
        let appGroupDefaults = UserDefaults(suiteName: "group.db23.Bullet-Tracker")
        appGroupDefaults?.set(Date().timeIntervalSince1970, forKey: "lastWidgetUpdate")
        
        // Reload widget timeline to reflect changes
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }
    
    private func getNextCompletionState(current: Int, habit: Habit) -> Int {
        // For negative habits, only toggle between 0 (none) and 3 (attempted/relapse)
        if habit.isNegativeHabit {
            return current == 0 ? 3 : 0
        }
        
        // For habits without multiple states, toggle between 0 and 1
        if !habit.useMultipleStates {
            return current == 0 ? 1 : 0
        }
        
        // For habits with multiple states, cycle through: 0 -> 1 -> 2 -> 3 -> 0
        switch current {
        case 0: return 1 // None -> Success
        case 1: return 2 // Success -> Partial  
        case 2: return 3 // Partial -> Attempted
        case 3: return 0 // Attempted -> None
        default: return 1 // Fallback to Success
        }
    }
}

// MARK: - Timeline Provider

struct HabitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(
            date: Date(),
            habits: [
                WidgetHabit(id: UUID(), name: "Morning Exercise", icon: "figure.walk", color: "#007AFF", isCompleted: true, completionState: 1, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Reading", icon: "book", color: "#FF9500", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false),
                WidgetHabit(id: UUID(), name: "Meditation", icon: "leaf", color: "#34C759", isCompleted: false, completionState: 0, needsDetails: false, isNegativeHabit: false)
            ],
            isEmpty: false
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            loadHabitsEntry { entry in
                completion(entry)
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> ()) {
        loadHabitsEntry { entry in
            // Smart refresh policy:
            // - During active hours (6am-11pm): refresh every 15 minutes for responsiveness
            // - During sleep hours: refresh at 6am
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)

            let nextRefresh: Date
            if hour >= 6 && hour < 23 {
                // Active hours: refresh in 15 minutes
                nextRefresh = now.addingTimeInterval(15 * 60)
            } else {
                // Sleep hours: refresh at 6am
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 6
                components.minute = 0
                if hour >= 23 {
                    // After 11pm, target tomorrow's 6am
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
    
    // MARK: - Data Loading
    
    private func loadHabitsEntry(completion: @escaping (HabitWidgetEntry) -> Void) {
        let context = CoreDataManager.shared.container.viewContext
        
        context.perform {
            do {
                let habits = try self.fetchTodaysHabits(context: context)
                
                let widgetHabits = habits.map { habit in
                    let completionState = self.getCompletionState(for: habit)
                    
                    return WidgetHabit(
                        id: habit.id ?? UUID(),
                        name: habit.name ?? "Unnamed Habit",
                        icon: habit.icon ?? "checkmark.circle",
                        color: habit.color ?? "#007AFF",
                        isCompleted: completionState > 0,
                        completionState: completionState,
                        needsDetails: habit.useMultipleStates || habit.trackDetails,
                        isNegativeHabit: habit.isNegativeHabit
                    )
                }
                
                let entry = HabitWidgetEntry(
                    date: Date(),
                    habits: Array(widgetHabits.prefix(12)), // Show up to 12 habits for large widget
                    isEmpty: widgetHabits.isEmpty
                )
                
                DispatchQueue.main.async {
                    completion(entry)
                }
            } catch {
                let emptyEntry = HabitWidgetEntry(date: Date(), habits: [], isEmpty: true)
                DispatchQueue.main.async {
                    completion(emptyEntry)
                }
            }
        }
    }
    
    private func fetchTodaysHabits(context: NSManagedObjectContext) throws -> [Habit] {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        // Optimization: prefetch entries relationship for completion checking
        request.relationshipKeyPathsForPrefetching = ["entries"]
        request.returnsObjectsAsFaults = false

        let allHabits = try context.fetch(request)
        let today = Date()

        // Filter habits that should be tracked today based on frequency
        let todaysHabits = allHabits.filter { habit in
            shouldTrackHabitToday(habit, on: today)
        }

        return todaysHabits
    }
    
    private func shouldTrackHabitToday(_ habit: Habit, on date: Date) -> Bool {
        HabitFrequency.shouldTrack(
            frequency: habit.frequency,
            on: date,
            customDays: habit.customDays,
            startDate: habit.startDate
        )
    }
    
    private func getCompletionState(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Try to find today's entry using prefetched entries
        if let entries = habit.entries as? Set<HabitEntry> {
            // Use first(where:) for early exit instead of iterating all
            if let todayEntry = entries.first(where: { entry in
                guard let entryDate = entry.date else { return false }
                return calendar.isDate(entryDate, inSameDayAs: today)
            }) {
                return Int(todayEntry.completionState)
            }
        }

        return 0 // Not completed
    }
}

// MARK: - Widget View

struct HabitWidgetView: View {
    let entry: HabitWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        Group {
            if entry.isEmpty {
                emptyStateView
            } else {
                habitsListView
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    // MARK: - Habits List View
    
    private var habitsListView: some View {
        let columns = gridColumns
        let maxHabits = maxHabitsToShow
        let habitsToShow = Array(entry.habits.prefix(maxHabits))
        
        return LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(habitsToShow) { habit in
                HabitButtonTile(habit: habit, isLarge: widgetFamily == .systemLarge)
            }
            
            // Fill empty spots with placeholder tiles
            let emptySlots = maxHabits - habitsToShow.count
            if emptySlots > 0 {
                ForEach(0..<emptySlots, id: \.self) { _ in
                    EmptyHabitTile(isLarge: widgetFamily == .systemLarge)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }
    
    // MARK: - Layout Configuration
    
    private var gridColumns: [GridItem] {
        switch widgetFamily {
        case .systemMedium:
            return [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        case .systemLarge:
            return [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]
        default:
            return [GridItem(.flexible())]
        }
    }
    
    private var maxHabitsToShow: Int {
        switch widgetFamily {
        case .systemMedium:
            return 6  // 3x2 grid
        case .systemLarge:
            return 12 // 4x3 grid
        default:
            return 6
        }
    }
    
    private var gridSpacing: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 12  // Increased from 8
        default:
            return 8
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 20  // Increased from 16
        default:
            return 12
        }
    }
    
    private var verticalPadding: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 20  // Increased from 16
        default:
            return 10
        }
    }
    
    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text("No Habits Today")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Open app to create habits")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Habit Button Tile

struct HabitButtonTile: View {
    let habit: WidgetHabit
    let isLarge: Bool
    
    init(habit: WidgetHabit, isLarge: Bool = false) {
        self.habit = habit
        self.isLarge = isLarge
    }
    
    var body: some View {
        Button(intent: CompleteHabitIntent(habitID: habit.id.uuidString, habitName: habit.name)) {
            VStack(spacing: iconTextSpacing) {
                // Icon with completion state
                iconWithState
                
                // Habit name - adaptive typography
                Text(habit.name)
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(textLines)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: tileHeight)
    }
    
    // MARK: - Size-Adaptive Properties
    
    private var tileHeight: CGFloat {
        isLarge ? 85 : 70  // Increased from 80
    }
    
    private var iconSize: CGFloat {
        isLarge ? 38 : 32  // Slightly larger from 36
    }
    
    private var iconFontSize: CGFloat {
        isLarge ? 19 : 16  // Increased from 18
    }
    
    private var textSize: CGFloat {
        isLarge ? 14 : 12  // Increased from 13
    }
    
    private var textLines: Int {
        isLarge ? 2 : 1
    }
    
    private var iconTextSpacing: CGFloat {
        isLarge ? 10 : 6  // Increased from 8
    }
    
    private var horizontalPadding: CGFloat {
        isLarge ? 12 : 8  // Increased from 10
    }
    
    private var verticalPadding: CGFloat {
        isLarge ? 14 : 10  // Increased from 12
    }
    
    @ViewBuilder
    private var iconWithState: some View {
        ZStack {
            // Background circle with habit color
            Circle()
                .fill(habitColor.opacity(habit.completionState == 0 ? 0.2 : 0.9))
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    Circle()
                        .strokeBorder(habitColor, lineWidth: 2)
                )
            
            // State-based content
            if habit.completionState == 0 {
                // Show habit icon when not completed
                Image(systemName: habit.icon)
                    .font(.system(size: iconFontSize, weight: .medium))
                    .foregroundColor(habitColor)
            } else {
                completionStateIcon
            }
        }
    }
    
    @ViewBuilder
    private var completionStateIcon: some View {
        if habit.isNegativeHabit && habit.completionState > 0 {
            // For negative habits, show X when completed (failure)
            Image(systemName: "xmark")
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundColor(.white)
        } else {
            // For positive habits, show state-based icons
            switch habit.completionState {
            case 1: // Success
                Image(systemName: "checkmark")
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundColor(.white)
            case 2: // Partial
                Image(systemName: "minus")
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundColor(.white)
            case 3: // Attempted
                Image(systemName: "xmark")
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundColor(.white)
            default:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(habit.completionState > 0 ? habitColor.opacity(0.08) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        habit.completionState == 0 ?
                        Color(.systemGray4) : habitColor,
                        lineWidth: habit.completionState == 0 ? 1 : 2
                    )
            )
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 2,
                x: 0,
                y: 1
            )
    }
    
    private var habitColor: Color {
        Color(hex: habit.color) ?? .blue
    }
}

// MARK: - Empty Habit Tile

struct EmptyHabitTile: View {
    let isLarge: Bool

    init(isLarge: Bool = false) {
        self.isLarge = isLarge
    }

    var body: some View {
        VStack(spacing: iconTextSpacing) {
            // Plus icon with circular background to match app style
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: iconBackgroundSize, height: iconBackgroundSize)

                Image(systemName: "plus")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // "Add Habit" text
            Text("Add Habit")
                .font(.system(size: textSize, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(textLines)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
                .shadow(
                    color: Color.black.opacity(0.02),
                    radius: 1,
                    x: 0,
                    y: 1
                )
        )
        .frame(height: tileHeight)
    }
    
    // MARK: - Size-Adaptive Properties

    private var tileHeight: CGFloat {
        isLarge ? 85 : 70
    }

    private var iconBackgroundSize: CGFloat {
        isLarge ? 32 : 26
    }

    private var iconSize: CGFloat {
        isLarge ? 14 : 12
    }

    private var textSize: CGFloat {
        isLarge ? 12 : 10
    }

    private var textLines: Int {
        isLarge ? 2 : 1
    }

    private var iconTextSpacing: CGFloat {
        isLarge ? 10 : 6
    }

    private var horizontalPadding: CGFloat {
        isLarge ? 12 : 8
    }

    private var verticalPadding: CGFloat {
        isLarge ? 14 : 10
    }
}

// MARK: - Habit Tracker Widget

struct HabitTrackerWidget: Widget {
    let kind: String = "HabitTrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // Transparent background to meet iOS requirements while staying clean
                    Color.clear
                }
        }
        .configurationDisplayName("Today's Habits")
        .description("Track your daily habits right from your home screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Bundle

@main
struct BulletTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HabitTrackerWidget()
    }
}
