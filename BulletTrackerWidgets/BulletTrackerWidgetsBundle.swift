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
                // Silently handle widget errors
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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today)!
        
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

// MARK: - Widget Core Data Manager

class WidgetCoreDataManager {
    static let shared = WidgetCoreDataManager()
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Bullet_Tracker")
        
        // Configure to use the same App Group container as main app
        if let storeURL = containerURL() {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Widget: Failed to retrieve store description")
            }
            
            description.url = storeURL
            
            // Enable history tracking and remote notifications for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                // Log error appropriately in production
            }
        }
        
        // Use the same merge policy as main app
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private func containerURL() -> URL? {
        let appGroupID = "group.db23.Bullet-Tracker"
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        return appGroupURL.appendingPathComponent("BulletTracker.sqlite")
    }
    
    private init() {}
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
            // Update timeline at midnight for new day
            let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            let timeline = Timeline(entries: [entry], policy: .after(midnight))
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
        
        let allHabits = try context.fetch(request)
        let today = Date()
        
        // Filter habits that should be tracked today based on frequency
        let todaysHabits = allHabits.filter { habit in
            shouldTrackHabitToday(habit, on: today)
        }
        
        return todaysHabits
    }
    
    private func shouldTrackHabitToday(_ habit: Habit, on date: Date) -> Bool {
        // Check if habit has started
        if let startDate = habit.startDate, date < startDate {
            return false
        }
        
        let weekday = Calendar.current.component(.weekday, from: date)
        let frequency = habit.frequency ?? "daily"
        
        switch frequency {
        case "daily":
            return true
        case "weekdays":
            return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
        case "weekends":
            return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
        case "weekly":
            // Check custom days - Handle String to Data conversion
            guard let customDaysData = habit.customDays else {
                return true // Default to daily if no custom days
            }
            
            // Convert String to Data, then decode to [Int] array
            guard let jsonData = customDaysData.data(using: .utf8),
                  let customDays = try? JSONDecoder().decode([Int].self, from: jsonData) else {
                return true // Default to daily if can't parse
            }
            return customDays.contains(weekday)
        default:
            return true
        }
    }
    
    private func getCompletionState(for habit: Habit) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Try to find today's entry
        if let entries = habit.entries as? Set<HabitEntry> {
            for entry in entries {
                if let entryDate = entry.date,
                   Calendar.current.isDate(entryDate, inSameDayAs: today) {
                    return Int(entry.completionState)
                }
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
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("No Habits Today")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Open app to create habits")
                    .font(.system(size: 14))
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
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        habit.completionState == 0 ? 
                        Color(.systemGray4) : habitColor,
                        lineWidth: habit.completionState == 0 ? 1 : 2
                    )
            )
            .shadow(
                color: Color.black.opacity(0.1),
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
            // Plus icon with iOS-native styling
            Image(systemName: "plus.circle")
                .font(.system(size: iconSize, weight: .light))
                .foregroundColor(.secondary)
            
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
        )
        .frame(height: tileHeight)
    }
    
    // MARK: - Size-Adaptive Properties
    
    private var tileHeight: CGFloat {
        isLarge ? 85 : 70  // Match habit tiles
    }
    
    private var iconSize: CGFloat {
        isLarge ? 30 : 24  // Slightly increased
    }
    
    private var textSize: CGFloat {
        isLarge ? 12 : 10  // Increased
    }
    
    private var textLines: Int {
        isLarge ? 2 : 1
    }
    
    private var iconTextSpacing: CGFloat {
        isLarge ? 10 : 6  // Match habit tiles
    }
    
    private var horizontalPadding: CGFloat {
        isLarge ? 12 : 8  // Match habit tiles
    }
    
    private var verticalPadding: CGFloat {
        isLarge ? 14 : 10  // Match habit tiles
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
