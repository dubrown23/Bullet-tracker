//
//  HabitStatsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct HabitStatsView: View {
    let habits: [Habit]
    @State private var selectedTimeframe: Timeframe = .month
    @State private var showAsFraction: Bool = false // Toggle for display format
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        
        var id: String { self.rawValue }
        
        // Get start date for the timeframe
        func getStartDate(from endDate: Date = Date()) -> Date {
            let calendar = Calendar.current
            
            switch self {
            case .week:
                // Get the start of the last 7 days (natural week)
                return calendar.date(byAdding: .weekOfYear, value: -1, to: endDate)!
                
            case .month:
                // Get start of the current month
                var components = calendar.dateComponents([.year, .month], from: endDate)
                return calendar.date(from: components)!
                
            case .quarter:
                // Get start date for the quarter (3 months back)
                return calendar.date(byAdding: .month, value: -3, to: endDate)!
            }
        }
        
        // Get a descriptive string for the timeframe
        func getDescription(for date: Date = Date()) -> String {
            let calendar = Calendar.current
            let startDate = getStartDate(from: date)
            let dateFormatter = DateFormatter()
            
            switch self {
            case .week:
                dateFormatter.dateFormat = "MMM d"
                return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: date))"
                
            case .month:
                dateFormatter.dateFormat = "MMMM"
                return dateFormatter.string(from: date)
                
            case .quarter:
                dateFormatter.dateFormat = "MMM d"
                let endDateStr = dateFormatter.string(from: date)
                let startDateStr = dateFormatter.string(from: startDate)
                return "\(startDateStr) - \(endDateStr)"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedTimeframe.getDescription())
                    .font(.headline)
                
                Spacer()
                
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Display format toggle
            Toggle(isOn: $showAsFraction) {
                Text("Show as fractions")
                    .font(.subheadline)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.blue))
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
}

// Enhanced habit progress view that shows multiple states
struct EnhancedHabitProgressView: View {
    @ObservedObject var habit: Habit
    let timeframe: HabitStatsView.Timeframe
    let showAsFraction: Bool
    
    @State private var successRate: Double = 0
    @State private var partialRate: Double = 0
    @State private var failureRate: Double = 0
    @State private var useMultipleStates: Bool = false
    
    // Tracking actual counts for fraction display
    @State private var successCount: Int = 0
    @State private var partialCount: Int = 0
    @State private var failureCount: Int = 0
    @State private var totalDays: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name ?? "")
                .font(.subheadline)
                .bold()
            
            if useMultipleStates {
                // Multi-state progress bar
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Success portion
                    if successRate > 0 {
                        Rectangle()
                            .fill(Color(hex: habit.color ?? "#007AFF"))
                            .frame(width: max(4, CGFloat(successRate) * 200), height: 8)
                            .cornerRadius(4)
                    }
                    
                    // Partial portion (stacked after success)
                    if partialRate > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: max(4, CGFloat(partialRate) * 200), height: 8)
                            .offset(x: successRate > 0 ? max(4, CGFloat(successRate) * 200) : 0)
                            .cornerRadius(4)
                    }
                    
                    // Failure portion (stacked after partial and success)
                    if failureRate > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: max(4, CGFloat(failureRate) * 200), height: 8)
                            .offset(x: (successRate > 0 ? max(4, CGFloat(successRate) * 200) : 0) +
                                      (partialRate > 0 ? max(4, CGFloat(partialRate) * 200) : 0))
                            .cornerRadius(4)
                    }
                }
                .frame(width: 200)
                
                // State breakdown
                HStack(spacing: 10) {
                    if successRate > 0 {
                        StateIndicator(
                            color: Color(hex: habit.color ?? "#007AFF"),
                            label: "Success",
                            value: successCount,
                            total: totalDays,
                            percentage: Int(successRate * 100),
                            showAsFraction: showAsFraction
                        )
                    }
                    
                    if partialRate > 0 {
                        StateIndicator(
                            color: .orange,
                            label: "Partial",
                            value: partialCount,
                            total: totalDays,
                            percentage: Int(partialRate * 100),
                            showAsFraction: showAsFraction
                        )
                    }
                    
                    if failureRate > 0 {
                        StateIndicator(
                            color: .red,
                            label: "Attempted",
                            value: failureCount,
                            total: totalDays,
                            percentage: Int(failureRate * 100),
                            showAsFraction: showAsFraction
                        )
                    }
                    
                    Spacer()
                }
            } else {
                // Simple progress bar for non-multi-state habits
                HStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color(hex: habit.color ?? "#007AFF"))
                            .frame(width: max(4, CGFloat(successRate) * 200), height: 8)
                            .cornerRadius(4)
                    }
                    .frame(width: 200)
                    
                    if showAsFraction {
                        Text("\(successCount)/\(totalDays)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Int(successRate * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
            loadStats()
        }
        .onChange(of: timeframe) { _ in
            loadStats()
        }
        .onChange(of: showAsFraction) { _ in
            // No need to reload stats, just update the view
        }
    }
    
    private func loadStats() {
        // Get start and end dates based on the selected timeframe
        let endDate = Date()
        let startDate = timeframe.getStartDate(from: endDate)
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date <= %@",
                                         habit, startDate as NSDate, endDate as NSDate)
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let entries = try context.fetch(fetchRequest)
            
            // Count days the habit should have been performed in this timeframe
            totalDays = 0
            var currentDate = startDate
            
            while currentDate <= endDate {
                if shouldPerformHabit(habit, on: currentDate) {
                    totalDays += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // If no expected days, avoid division by zero
            guard totalDays > 0 else {
                successRate = 0
                partialRate = 0
                failureRate = 0
                successCount = 0
                partialCount = 0
                failureCount = 0
                return
            }
            
            // Count each state type
            successCount = 0
            partialCount = 0
            failureCount = 0
            
            for entry in entries {
                if useMultipleStates {
                    let stateValue = entry.value(forKey: "completionState") as? Int ?? 1
                    
                    switch stateValue {
                    case 1:
                        successCount += 1
                    case 2:
                        partialCount += 1
                    case 3:
                        failureCount += 1
                    default:
                        break
                    }
                } else if entry.completed {
                    successCount += 1
                }
            }
            
            // Calculate rates
            successRate = Double(successCount) / Double(totalDays)
            partialRate = Double(partialCount) / Double(totalDays)
            failureRate = Double(failureCount) / Double(totalDays)
            
        } catch {
            print("Error loading habit statistics: \(error)")
        }
    }
    
    // Helper property for calendar to avoid repetition
    private var calendar: Calendar {
        return Calendar.current
    }
    
    // Helper method to determine if a habit should be performed on a given date
    private func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date) // 1 is Sunday, 7 is Saturday
        
        switch habit.frequency {
        case "daily":
            return true
            
        case "weekdays":
            // Weekdays are 2-6 (Monday-Friday)
            return weekday >= 2 && weekday <= 6
            
        case "weekends":
            // Weekends are 1 and 7 (Sunday and Saturday)
            return weekday == 1 || weekday == 7
            
        case "weekly":
            // Assume the habit should be done on the same day of the week as it was started
            if let startDate = habit.startDate {
                let startWeekday = calendar.component(.weekday, from: startDate)
                return weekday == startWeekday
            }
            return false
            
        case "custom":
            // Custom days format: "1,3,5" for Sun, Tue, Thu
            let customDays = habit.customDays?.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            return customDays.contains(weekday)
            
        default:
            return false
        }
    }
}

// Helper view for displaying state indicators
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
            
            if showAsFraction {
                Text("\(label): \(value)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(label): \(percentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
