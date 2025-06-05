//
//  SpecialEntryTemplates.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
//


//
//  SpecialEntryTemplates.swift
//  Bullet Tracker
//
//  Created on [Current Date]
//  Phase 5: Reviews & Outlooks Implementation
//

import Foundation

struct SpecialEntryTemplates {
    
    // MARK: - Template Types
    
    static let monthlyReviewTemplate = """
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
    
    static let monthlyOutlookTemplate = """
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
    
    // MARK: - Helper Methods
    
    static func template(for type: String) -> String? {
        switch type {
        case "review":
            return monthlyReviewTemplate
        case "outlook":
            return monthlyOutlookTemplate
        default:
            return nil
        }
    }
    
    // MARK: - Title Generation
    
    static func title(for type: String, month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let monthString = formatter.string(from: month)
        
        switch type {
        case "review":
            return "\(monthString) Review"
        case "outlook":
            return "\(monthString) Outlook"
        default:
            return monthString
        }
    }
    
    // MARK: - Month Selection Helpers
    
    static func availableMonths() -> [Date] {
        var months: [Date] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Current month
        if let currentMonth = calendar.dateInterval(of: .month, for: now)?.start {
            months.append(currentMonth)
        }
        
        // Previous 3 months
        for i in 1...3 {
            if let previousMonth = calendar.date(byAdding: .month, value: -i, to: now),
               let monthStart = calendar.dateInterval(of: .month, for: previousMonth)?.start {
                months.append(monthStart)
            }
        }
        
        return months
    }
    
    static func monthDisplayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}