//
//  HabitStatsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


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
    @State private var selectedTimeframe: Timeframe = .thirtyDays
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
        case ninetyDays = "90 Days"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress")
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
            
            ForEach(habits) { habit in
                EnhancedHabitProgressView(habit: habit, days: selectedTimeframe.days)
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
    let days: Int
    
    @State private var successRate: Double = 0
    @State private var partialRate: Double = 0
    @State private var failureRate: Double = 0
    @State private var useMultipleStates: Bool = false
    
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
                        StateIndicator(color: Color(hex: habit.color ?? "#007AFF"),
                                      label: "Success",
                                      percentage: Int(successRate * 100))
                    }
                    
                    if partialRate > 0 {
                        StateIndicator(color: .orange,
                                      label: "Partial",
                                      percentage: Int(partialRate * 100))
                    }
                    
                    if failureRate > 0 {
                        StateIndicator(color: .red,
                                      label: "Attempted",
                                      percentage: Int(failureRate * 100))
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
                    
                    Text("\(Int(successRate * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
            loadStats()
        }
    }
    
    private func loadStats() {
        // Get habit entries for the last X days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date <= %@",
                                         habit, startDate as NSDate, endDate as NSDate)
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let entries = try context.fetch(fetchRequest)
            
            // Count days the habit should have been performed
            var totalDays = 0
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
                return
            }
            
            // Count each state type
            var successCount = 0
            var partialCount = 0
            var failureCount = 0
            
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
    
    // Helper method to determine if a habit should be performed on a given date
    private func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
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
    let percentage: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(label): \(percentage)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
