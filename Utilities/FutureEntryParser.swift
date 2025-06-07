//
//  FutureEntryParser.swift
//  Bullet Tracker
//
//  Created on June 4, 2025
//

import Foundation

struct FutureEntryParser {
    
    // MARK: - Constants
    
    private static let monthMappings: [String: Int] = [
        // Full names
        "january": 1, "february": 2, "march": 3, "april": 4,
        "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
        // Abbreviations
        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
        "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
    ]
    
    // MARK: - Regular Expressions
    
    private static let fullDateRegex = try! NSRegularExpression(
        pattern: #"^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$"#
    )
    
    private static let monthDayRegex = try! NSRegularExpression(
        pattern: #"^(\d{1,2})[/-](\d{1,2})$"#
    )
    
    // MARK: - Public Methods
    
    /// Parses a text string for @mention date formats and returns clean text with extracted date
    static func parseFutureDate(from text: String, referenceDate: Date = Date()) -> (cleanText: String, scheduledDate: Date?) {
        guard let atRange = text.range(of: "@") else {
            return (text, nil)
        }
        
        let mentionStart = text.distance(from: text.startIndex, to: atRange.lowerBound)
        let afterAt = String(text[atRange.upperBound...])
        
        let mentionEndIndex = afterAt.firstIndex(where: { char in
            char.isWhitespace || char.isPunctuation || char.isNewline
        }) ?? afterAt.endIndex
        
        let mention = String(afterAt[..<mentionEndIndex]).lowercased()
        
        if let date = parseMention(mention, referenceDate: referenceDate) {
            let mentionRange = text.index(text.startIndex, offsetBy: mentionStart)..<text.index(text.startIndex, offsetBy: mentionStart + 1 + mention.count)
            var cleanText = text
            cleanText.removeSubrange(mentionRange)
            cleanText = cleanText
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return (cleanText, date)
        }
        
        return (text, nil)
    }
    
    // MARK: - Private Methods
    
    private static func parseMention(_ mention: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        let currentYear = components.year!
        let currentMonth = components.month!
        
        // Try parsing strategies in order of specificity
        return parseFullDate(mention, currentYear: currentYear)
            ?? parseMonthDay(mention, currentYear: currentYear, currentMonth: currentMonth, referenceDate: referenceDate)
            ?? parseMonthYear(mention)
            ?? parseMonthOnly(mention, currentYear: currentYear, currentMonth: currentMonth, referenceDate: referenceDate)
    }
    
    private static func parseFullDate(_ mention: String, currentYear: Int) -> Date? {
        guard let match = fullDateRegex.firstMatch(
            in: mention,
            range: NSRange(mention.startIndex..., in: mention)
        ) else { return nil }
        
        let monthStr = String(mention[Range(match.range(at: 1), in: mention)!])
        let dayStr = String(mention[Range(match.range(at: 2), in: mention)!])
        let yearStr = String(mention[Range(match.range(at: 3), in: mention)!])
        
        guard let month = Int(monthStr),
              let day = Int(dayStr),
              let year = Int(yearStr) else { return nil }
        
        return createDate(year: year, month: month, day: day)
    }
    
    private static func parseMonthDay(_ mention: String, currentYear: Int, currentMonth: Int, referenceDate: Date) -> Date? {
        // Try numeric format first
        if let match = monthDayRegex.firstMatch(
            in: mention,
            range: NSRange(mention.startIndex..., in: mention)
        ) {
            let monthStr = String(mention[Range(match.range(at: 1), in: mention)!])
            let dayStr = String(mention[Range(match.range(at: 2), in: mention)!])
            
            if let month = Int(monthStr), let day = Int(dayStr) {
                let targetYear = getNextOccurrenceYear(
                    targetMonth: month,
                    currentMonth: currentMonth,
                    currentYear: currentYear,
                    referenceDate: referenceDate
                )
                return createDate(year: targetYear, month: month, day: day)
            }
        }
        
        // Try month name format
        let parts = mention.split(separator: "-").map(String.init)
        guard parts.count == 2,
              let month = parseMonth(parts[0]),
              let day = Int(parts[1]) else { return nil }
        
        let targetYear = getNextOccurrenceYear(
            targetMonth: month,
            currentMonth: currentMonth,
            currentYear: currentYear,
            referenceDate: referenceDate
        )
        return createDate(year: targetYear, month: month, day: day)
    }
    
    private static func parseMonthYear(_ mention: String) -> Date? {
        let parts = mention.split(separator: "-").map(String.init)
        guard parts.count == 2,
              let month = parseMonth(parts[0]),
              let year = Int(parts[1]) else { return nil }
        
        return createDate(year: year, month: month, day: 1)
    }
    
    private static func parseMonthOnly(_ mention: String, currentYear: Int, currentMonth: Int, referenceDate: Date) -> Date? {
        guard let month = parseMonth(mention) else { return nil }
        
        let targetYear = getNextOccurrenceYear(
            targetMonth: month,
            currentMonth: currentMonth,
            currentYear: currentYear,
            referenceDate: referenceDate
        )
        return createDate(year: targetYear, month: month, day: 1)
    }
    
    private static func parseMonth(_ text: String) -> Int? {
        // Try numeric first
        if let month = Int(text), (1...12).contains(month) {
            return month
        }
        
        return monthMappings[text.lowercased()]
    }
    
    private static func getNextOccurrenceYear(targetMonth: Int, currentMonth: Int, currentYear: Int, referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: referenceDate)
        
        // If target month is current month, check if we're past the 1st
        if targetMonth == currentMonth {
            return currentDay > 1 ? currentYear + 1 : currentYear
        }
        
        // If target month is before current month, it's next year
        return targetMonth < currentMonth ? currentYear + 1 : currentYear
    }
    
    private static func createDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        let calendar = Calendar.current
        
        // Validate the date components
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else {
            return nil
        }
        
        return date
    }
}
