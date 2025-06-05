//
//  FutureEntryParser.swift
//  Bullet Tracker
//
//  Created on June 4, 2025
//

import Foundation

class FutureEntryParser {
    
    // MARK: - Public Methods
    
    /// Parses a text string for @mention date formats and returns clean text with extracted date
    /// - Parameters:
    ///   - text: The input text containing potential @mention
    ///   - referenceDate: The date to use as reference for parsing (defaults to current date)
    /// - Returns: Tuple containing clean text (without @mention) and parsed scheduled date if found
    static func parseFutureDate(from text: String, referenceDate: Date = Date()) -> (cleanText: String, scheduledDate: Date?) {
        // Find first @mention in the text
        guard let atRange = text.range(of: "@") else {
            return (text, nil)
        }
        
        // Extract the mention starting from @ symbol
        let mentionStart = text.distance(from: text.startIndex, to: atRange.lowerBound)
        let afterAt = String(text[atRange.upperBound...])
        
        // Find where the mention ends (space, punctuation, or end of string)
        let mentionEndIndex = afterAt.firstIndex(where: { char in
            char.isWhitespace || char.isPunctuation || char.isNewline
        }) ?? afterAt.endIndex
        
        let mention = String(afterAt[..<mentionEndIndex]).lowercased()
        
        // Parse the mention
        let parsedDate = parseMention(mention, referenceDate: referenceDate)
        
        // If we successfully parsed a date, remove the @mention from text
        if let date = parsedDate {
            let mentionRange = text.index(text.startIndex, offsetBy: mentionStart)..<text.index(text.startIndex, offsetBy: mentionStart + 1 + mention.count)
            var cleanText = text
            cleanText.removeSubrange(mentionRange)
            
            // Clean up any double spaces that might result
            cleanText = cleanText.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            return (cleanText, date)
        }
        
        // If parsing failed, return original text with nil date
        return (text, nil)
    }
    
    // MARK: - Private Methods
    
    private static func parseMention(_ mention: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        let currentYear = components.year!
        let currentMonth = components.month!
        
        // Try different parsing strategies
        
        // 1. Full date with year: @12/25/2025 or @12-25-2025
        if let date = parseFullDate(mention, currentYear: currentYear) {
            return date
        }
        
        // 2. Month and day: @dec-25 or @12-25 or @december-25
        if let date = parseMonthDay(mention, currentYear: currentYear, currentMonth: currentMonth, referenceDate: referenceDate) {
            return date
        }
        
        // 3. Month with year: @dec-2025 or @december-2025
        if let date = parseMonthYear(mention) {
            return date
        }
        
        // 4. Just month: @december or @dec or @12
        if let date = parseMonthOnly(mention, currentYear: currentYear, currentMonth: currentMonth, referenceDate: referenceDate) {
            return date
        }
        
        return nil
    }
    
    private static func parseFullDate(_ mention: String, currentYear: Int) -> Date? {
        // Try formats like 12/25/2025 or 12-25-2025
        let patterns = [
            #"^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$"#,  // MM/DD/YYYY or MM-DD-YYYY
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: mention, range: NSRange(mention.startIndex..., in: mention)) {
                
                let monthStr = String(mention[Range(match.range(at: 1), in: mention)!])
                let dayStr = String(mention[Range(match.range(at: 2), in: mention)!])
                let yearStr = String(mention[Range(match.range(at: 3), in: mention)!])
                
                if let month = Int(monthStr), let day = Int(dayStr), let year = Int(yearStr) {
                    return createDate(year: year, month: month, day: day)
                }
            }
        }
        
        return nil
    }
    
    private static func parseMonthDay(_ mention: String, currentYear: Int, currentMonth: Int, referenceDate: Date) -> Date? {
        // Try formats like dec-25, december-25, 12-25
        
        // First try numeric format (12-25)
        if let regex = try? NSRegularExpression(pattern: #"^(\d{1,2})[/-](\d{1,2})$"#),
           let match = regex.firstMatch(in: mention, range: NSRange(mention.startIndex..., in: mention)) {
            
            let monthStr = String(mention[Range(match.range(at: 1), in: mention)!])
            let dayStr = String(mention[Range(match.range(at: 2), in: mention)!])
            
            if let month = Int(monthStr), let day = Int(dayStr) {
                // Determine year based on next occurrence
                let targetYear = getNextOccurrenceYear(targetMonth: month, currentMonth: currentMonth, currentYear: currentYear, referenceDate: referenceDate)
                return createDate(year: targetYear, month: month, day: day)
            }
        }
        
        // Try month name format (dec-25, december-25)
        let parts = mention.split(separator: "-").map(String.init)
        if parts.count == 2 {
            if let month = parseMonth(parts[0]),
               let day = Int(parts[1]) {
                let targetYear = getNextOccurrenceYear(targetMonth: month, currentMonth: currentMonth, currentYear: currentYear, referenceDate: referenceDate)
                return createDate(year: targetYear, month: month, day: day)
            }
        }
        
        return nil
    }
    
    private static func parseMonthYear(_ mention: String) -> Date? {
        // Try formats like dec-2025 or december-2025
        let parts = mention.split(separator: "-").map(String.init)
        if parts.count == 2 {
            if let month = parseMonth(parts[0]),
               let year = Int(parts[1]) {
                return createDate(year: year, month: month, day: 1)
            }
        }
        
        return nil
    }
    
    private static func parseMonthOnly(_ mention: String, currentYear: Int, currentMonth: Int, referenceDate: Date) -> Date? {
        if let month = parseMonth(mention) {
            let targetYear = getNextOccurrenceYear(targetMonth: month, currentMonth: currentMonth, currentYear: currentYear, referenceDate: referenceDate)
            return createDate(year: targetYear, month: month, day: 1)
        }
        
        return nil
    }
    
    private static func parseMonth(_ text: String) -> Int? {
        // Try numeric first
        if let month = Int(text), month >= 1 && month <= 12 {
            return month
        }
        
        // Month names and abbreviations
        let monthMappings: [String: Int] = [
            // Full names
            "january": 1, "february": 2, "march": 3, "april": 4,
            "may": 5, "june": 6, "july": 7, "august": 8,
            "september": 9, "october": 10, "november": 11, "december": 12,
            
            // Abbreviations (excluding "may" since it's already in full names)
            "jan": 1, "feb": 2, "mar": 3, "apr": 4,
            "jun": 6, "jul": 7, "aug": 8,
            "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
        ]
        
        return monthMappings[text.lowercased()]
    }
    
    private static func getNextOccurrenceYear(targetMonth: Int, currentMonth: Int, currentYear: Int, referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: referenceDate)
        
        // If target month is current month, check if we're past the 1st
        if targetMonth == currentMonth {
            // Since we default to 1st of month, if today is past the 1st, use next year
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
        if let date = calendar.date(from: components),
           calendar.component(.day, from: date) == day { // This check ensures invalid dates like Feb 30 are rejected
            return date
        }
        
        return nil
    }
}

// MARK: - Unit Tests Helper
#if DEBUG
extension FutureEntryParser {
    static func runTests() {
        let testDate = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 4))!
        
        // Test cases
        let tests: [(input: String, expectedClean: String, expectedMonth: Int?, expectedDay: Int?, expectedYear: Int?)] = [
            // Month only
            ("Meeting @december", "Meeting", 12, 1, 2025),
            ("@jan task", "task", 1, 1, 2026), // Next year since Jan < June
            ("@june note", "note", 6, 1, 2025), // Current month, but we're past the 1st, so next year
            
            // Month abbreviations
            ("@dec reminder", "reminder", 12, 1, 2025),
            ("@sept event", "event", 9, 1, 2025),
            
            // Month numbers
            ("@12 birthday", "birthday", 12, 1, 2025),
            ("@3 appointment", "appointment", 3, 1, 2026),
            
            // Month-day combinations
            ("@dec-25 Christmas", "Christmas", 12, 25, 2025),
            ("@12-25 Christmas", "Christmas", 12, 25, 2025),
            ("@december-25 Christmas", "Christmas", 12, 25, 2025),
            
            // Full dates
            ("@12/25/2025 Christmas", "Christmas", 12, 25, 2025),
            ("@3-15-2026 Deadline", "Deadline", 3, 15, 2026),
            
            // Month-year combinations
            ("@dec-2026 Future plan", "Future plan", 12, 1, 2026),
            ("@january-2025 Past event", "Past event", 1, 1, 2025),
            
            // Invalid dates (should return nil)
            ("@feb-30 Invalid", "@feb-30 Invalid", nil, nil, nil),
            ("@13 Invalid month", "@13 Invalid month", nil, nil, nil),
            ("@jnuary Typo", "@jnuary Typo", nil, nil, nil),
            
            // No mention
            ("Regular text", "Regular text", nil, nil, nil),
        ]
        
        for test in tests {
            let result = parseFutureDate(from: test.input, referenceDate: testDate)
            
            print("Input: '\(test.input)'")
            print("Clean: '\(result.cleanText)'")
            
            if let date = result.scheduledDate {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                print("Date: \(components.month!)/\(components.day!)/\(components.year!)")
                
                assert(result.cleanText == test.expectedClean, "Clean text mismatch")
                assert(components.month == test.expectedMonth, "Month mismatch")
                assert(components.day == test.expectedDay, "Day mismatch")
                assert(components.year == test.expectedYear, "Year mismatch")
            } else {
                print("Date: nil")
                assert(test.expectedMonth == nil, "Expected date but got nil")
            }
            print("---")
        }
        
        print("All tests passed! ✅")
    }
}
#endif
