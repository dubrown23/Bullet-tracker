//
//  WidgetEnums.swift
//  BulletTrackerWidgets
//
//  Created for widget compatibility
//

import Foundation

// MARK: - Debug Logging (Widget Target)

@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

// MARK: - Stub Enums for Widget
// Widget-side copies of enums whose main-app versions live in `Utilities/Constants.swift`.
// They duplicate (don't share) because the widget target doesn't pull in the full app file.
// `HabitFrequency.shouldTrack(...)` is the one piece of behavior the widget actually uses —
// keeps the timeline provider's "should this habit show today?" filter inside the extension.

enum HabitFrequency: String, CaseIterable {
    case daily
    case weekdays
    case weekends
    case weekly
    case custom
    
    /// Determines if a habit with this frequency should be tracked on a given date
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

enum EntryType: String, CaseIterable {
    case task = "task"
    case note = "note"
    case event = "event"
}

enum TaskStatus: String, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case cancelled = "cancelled"
}
