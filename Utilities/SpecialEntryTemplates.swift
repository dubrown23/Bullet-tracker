//
//  SpecialEntryTemplates.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
//

import Foundation

struct SpecialEntryTemplates {
    
    // MARK: - Constants
    
    private enum Constants {
        static let previousMonthsToShow = 3
    }
    
    // MARK: - Entry Types
    
    enum EntryType: String {
        case review
        case outlook
        
        var template: String {
            switch self {
            case .review:
                return """
                ## What went well this month:
                - 
                
                ## Challenges faced:
                - 
                
                ## Habit completion summary:
                - 
                
                ## Key moments to remember:
                - 
                
                ## Lessons learned:
                - 
                """
            case .outlook:
                return """
                ## Main goals for this month:
                - 
                
                ## Important dates:
                - 
                
                ## Habits to focus on:
                - 
                
                ## What I'm looking forward to:
                - 
                
                ## Potential challenges:
                - 
                """
            }
        }
        
        func title(for date: Date) -> String {
            let monthString = SpecialEntryTemplates.monthYearFormatter.string(from: date)
            switch self {
            case .review:
                return "\(monthString) Review"
            case .outlook:
                return "\(monthString) Outlook"
            }
        }
    }
    
    // MARK: - Static Formatters
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // MARK: - Public Methods
    
    static func template(for type: String) -> String? {
        EntryType(rawValue: type)?.template
    }
    
    static func title(for type: String, month: Date) -> String {
        guard let entryType = EntryType(rawValue: type) else {
            return monthDisplayString(for: month)
        }
        return entryType.title(for: month)
    }
    
    static func availableMonths() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        // Generate current month plus previous months
        return (0...Constants.previousMonthsToShow).compactMap { monthsAgo in
            calendar.date(byAdding: .month, value: -monthsAgo, to: now)
                .flatMap { calendar.dateInterval(of: .month, for: $0)?.start }
        }
    }
    
    static func monthDisplayString(for date: Date) -> String {
        monthYearFormatter.string(from: date)
    }
}
