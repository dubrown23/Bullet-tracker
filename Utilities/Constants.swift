//
//  Constants.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import Foundation
import SwiftUI
// MARK: - Debug Logging

/// Logs messages only in DEBUG builds — compiles to nothing in Release
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

// MARK: - Habit Frequency

/// Represents how often a habit should be tracked
enum HabitFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekends
    case weekly
    case custom
    
    var id: String { self.rawValue }
    
    /// User-friendly display name for the frequency picker
    var displayName: String {
        switch self {
        case .daily: return "Every Day"
        case .weekdays: return "Weekdays Only"
        case .weekends: return "Weekends Only"
        case .weekly: return "Once a Week"
        case .custom: return "Custom Days"
        }
    }
    
    /// Determines if a habit with this frequency should be tracked on a given date
    /// - Parameters:
    ///   - date: The date to check
    ///   - customDays: Comma-separated weekday numbers (1=Sun, 7=Sat) for weekly/custom frequencies
    ///   - startDate: The habit's start date; returns false for dates before this
    /// - Returns: Whether the habit should be tracked on the given date
    static func shouldTrack(frequency: String?, on date: Date, customDays: String?, startDate: Date?) -> Bool {
        if let startDate = startDate, date < startDate {
            return false
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let freq = HabitFrequency(rawValue: frequency ?? HabitFrequency.daily.rawValue) ?? .daily
        
        switch freq {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        case .weekly, .custom:
            if let customDays = customDays, !customDays.isEmpty {
                let days = customDays.components(separatedBy: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                return days.contains(weekday)
            }
            return true
        }
    }
}

// MARK: - Completion State

/// Represents the completion state of a habit entry
enum CompletionState: Int, CaseIterable {
    case none = 0
    case success = 1
    case partial = 2
    case attempted = 3
    
    var color: Color {
        switch self {
        case .none: return .clear
        case .success: return Color(hex: "#4CAF50")
        case .partial: return Color(hex: "#FFB300")
        case .attempted: return Color(hex: "#EF5350")
        }
    }
    
    var icon: String {
        switch self {
        case .none: return ""
        case .success: return "checkmark"
        case .partial: return "circle.lefthalf.filled"
        case .attempted: return "xmark"
        }
    }
}

// MARK: - Entry Type

/// Represents the different types of bullet journal entries
enum EntryType: String, CaseIterable, Identifiable {
    case task
    case event
    case note
    
    // MARK: - Identifiable
    
    var id: String { self.rawValue }
    
    // MARK: - Computed Properties
    
    /// The bullet symbol for this entry type
    var symbol: String {
        switch self {
        case .task: return "•"
        case .event: return "○"
        case .note: return "—"
        }
    }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .task: return "Task"
        case .event: return "Event"
        case .note: return "Note"
        }
    }
}

// MARK: - Task Status

/// Represents the different statuses a task can have
enum TaskStatus: String, CaseIterable, Identifiable {
    case pending
    case completed
    case migrated
    case scheduled
    
    // MARK: - Identifiable
    
    var id: String { self.rawValue }
    
    // MARK: - Computed Properties
    
    /// The symbol representing this task status
    var symbol: String {
        switch self {
        case .pending: return "•"
        case .completed: return "✓"
        case .migrated: return ">"
        case .scheduled: return "<"
        }
    }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .migrated: return "Migrated"
        case .scheduled: return "Scheduled"
        }
    }
}
