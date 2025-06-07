//
//  HabitStatsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct HabitStatsView: View {
    // MARK: - Properties
    
    let habits: [Habit]
    
    // MARK: - State Properties
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var showAsFraction: Bool = false
    
    // MARK: - Supporting Types
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        
        var id: String { self.rawValue }
        
        /// Get start date for the timeframe
        func getStartDate(from endDate: Date = Date()) -> Date {
            let calendar = Calendar.current
            
            switch self {
            case .week:
                return calendar.date(byAdding: .weekOfYear, value: -1, to: endDate)!
                
            case .month:
                let components = calendar.dateComponents([.year, .month], from: endDate)
                return calendar.date(from: components)!
                
            case .quarter:
                return calendar.date(byAdding: .month, value: -3, to: endDate)!
            }
        }
        
        /// Get a descriptive string for the timeframe
        func getDescription(for date: Date = Date()) -> String {
            let startDate = getStartDate(from: date)
            
            switch self {
            case .week:
                return DateFormatters.shortDateFormatter.string(from: startDate) + " - " + DateFormatters.shortDateFormatter.string(from: date)
                
            case .month:
                return DateFormatters.monthFormatter.string(from: date)
                
            case .quarter:
                let endDateStr = DateFormatters.shortDateFormatter.string(from: date)
                let startDateStr = DateFormatters.shortDateFormatter.string(from: startDate)
                return "\(startDateStr) - \(endDateStr)"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            
            Toggle(isOn: $showAsFraction) {
                Text("Show as fractions")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .padding(.vertical, 4)
            
            ForEach(habits) { habit in
                EnhancedHabitProgressView(
                    habit: habit,
                    timeframe: selectedTimeframe,
                    showAsFraction: showAsFraction
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text(selectedTimeframe.getDescription())
                .font(.headline)
            
            Spacer()
            
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(Timeframe.allCases) { timeframe in
                    Text(timeframe.rawValue).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }
}

// MARK: - Date Formatters

private struct DateFormatters {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
}

// MARK: - Enhanced Habit Progress View

struct EnhancedHabitProgressView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    let timeframe: HabitStatsView.Timeframe
    let showAsFraction: Bool
    
    // MARK: - State Properties
    
    @State private var stats = HabitStats()
    
    // MARK: - Supporting Types
    
    struct HabitStats {
        var successRate: Double = 0
        var partialRate: Double = 0
        var failureRate: Double = 0
        var successCount: Int = 0
        var partialCount: Int = 0
        var failureCount: Int = 0
        var totalDays: Int = 0
        var useMultipleStates: Bool = false
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name ?? "")
                .font(.subheadline)
                .bold()
            
            if stats.useMultipleStates {
                multiStateProgressView
            } else {
                simpleProgressView
            }
        }
        .onAppear {
            loadStats()
        }
        .onChange(of: timeframe) { _, _ in
            loadStats()
        }
    }
    
    // MARK: - View Components
    
    private var multiStateProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Multi-state progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                HStack(spacing: 0) {
                    if stats.successRate > 0 {
                        Rectangle()
                            .fill(Color(hex: habit.color ?? "#007AFF"))
                            .frame(width: max(4, CGFloat(stats.successRate) * 200), height: 8)
                    }
                    
                    if stats.partialRate > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: max(4, CGFloat(stats.partialRate) * 200), height: 8)
                    }
                    
                    if stats.failureRate > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: max(4, CGFloat(stats.failureRate) * 200), height: 8)
                    }
                }
                .cornerRadius(4)
            }
            .frame(width: 200)
            
            // State breakdown
            HStack(spacing: 10) {
                if stats.successRate > 0 {
                    StateIndicator(
                        color: Color(hex: habit.color ?? "#007AFF"),
                        label: "Success",
                        value: stats.successCount,
                        total: stats.totalDays,
                        percentage: Int(stats.successRate * 100),
                        showAsFraction: showAsFraction
                    )
                }
                
                if stats.partialRate > 0 {
                    StateIndicator(
                        color: .orange,
                        label: "Partial",
                        value: stats.partialCount,
                        total: stats.totalDays,
                        percentage: Int(stats.partialRate * 100),
                        showAsFraction: showAsFraction
                    )
                }
                
                if stats.failureRate > 0 {
                    StateIndicator(
                        color: .red,
                        label: "Attempted",
                        value: stats.failureCount,
                        total: stats.totalDays,
                        percentage: Int(stats.failureRate * 100),
                        showAsFraction: showAsFraction
                    )
                }
                
                Spacer()
            }
        }
    }
    
    private var simpleProgressView: some View {
        HStack {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color(hex: habit.color ?? "#007AFF"))
                    .frame(width: max(4, CGFloat(stats.successRate) * 200), height: 8)
                    .cornerRadius(4)
            }
            .frame(width: 200)
            
            Text(statText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statText: String {
        if showAsFraction {
            return "\(stats.successCount)/\(stats.totalDays)"
        } else {
            return "\(Int(stats.successRate * 100))%"
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStats() {
        stats.useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
        
        let endDate = Date()
        let startDate = timeframe.getStartDate(from: endDate)
        
        // Calculate expected days more efficiently
        stats.totalDays = calculateExpectedDays(from: startDate, to: endDate)
        
        guard stats.totalDays > 0 else {
            resetStats()
            return
        }
        
        // Fetch entries
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date <= %@",
            habit, startDate as NSDate, endDate as NSDate
        )
        
        do {
            let entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            calculateStats(from: entries)
        } catch {
            resetStats()
        }
    }
    
    private func calculateExpectedDays(from startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        let totalDays = (components.day ?? 0) + 1
        
        // For daily habits, return total days
        if habit.frequency == "daily" {
            return totalDays
        }
        
        // For other frequencies, count specific days
        var count = 0
        let startWeekday = calendar.component(.weekday, from: habit.startDate ?? Date())
        let customDays = parseCustomDays()
        
        // Use dateInterval for more efficient iteration
        guard let interval = calendar.dateInterval(of: .day, for: startDate) else { return 0 }
        var currentDate = interval.start
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            switch habit.frequency {
            case "weekdays":
                if (2...6).contains(weekday) { count += 1 }
            case "weekends":
                if weekday == 1 || weekday == 7 { count += 1 }
            case "weekly":
                if weekday == startWeekday { count += 1 }
            case "custom":
                if customDays.contains(weekday) { count += 1 }
            default:
                break
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return count
    }
    
    private func parseCustomDays() -> Set<Int> {
        guard let customDaysString = habit.customDays else { return [] }
        
        return Set(customDaysString
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
    }
    
    private func calculateStats(from entries: [HabitEntry]) {
        var successCount = 0
        var partialCount = 0
        var failureCount = 0
        
        for entry in entries {
            if stats.useMultipleStates {
                switch entry.value(forKey: "completionState") as? Int ?? 1 {
                case 1: successCount += 1
                case 2: partialCount += 1
                case 3: failureCount += 1
                default: break
                }
            } else if entry.completed {
                successCount += 1
            }
        }
        
        let total = Double(stats.totalDays)
        stats.successCount = successCount
        stats.partialCount = partialCount
        stats.failureCount = failureCount
        stats.successRate = Double(successCount) / total
        stats.partialRate = Double(partialCount) / total
        stats.failureRate = Double(failureCount) / total
    }
    
    private func resetStats() {
        stats = HabitStats()
    }
}

// MARK: - State Indicator

struct StateIndicator: View {
    let color: Color
    let label: String
    let value: Int
    let total: Int
    let percentage: Int
    let showAsFraction: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var displayText: String {
        if showAsFraction {
            return "\(label): \(value)/\(total)"
        } else {
            return "\(label): \(percentage)%"
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit1 = Habit(context: context)
    habit1.name = "Morning Exercise"
    habit1.color = "#34C759"
    habit1.frequency = "daily"
    
    let habit2 = Habit(context: context)
    habit2.name = "Reading"
    habit2.color = "#007AFF"
    habit2.frequency = "daily"
    habit2.setValue(true, forKey: "useMultipleStates")
    
    return HabitStatsView(habits: [habit1, habit2])
        .padding()
}
