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

