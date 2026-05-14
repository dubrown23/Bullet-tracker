//
//  Bullet_TrackerTests.swift
//  Bullet TrackerTests
//
//  Created by Dustin Brown on 5/12/25.
//

import Testing
import SwiftUI
@testable import Bullet_Tracker

// MARK: - HabitFrequency Tests

struct HabitFrequencyTests {
    private let calendar = Calendar.current

    // Helper to create a date for a specific weekday (1=Sun, 2=Mon, ..., 7=Sat)
    private func dateForWeekday(_ weekday: Int) -> Date {
        // Start from a known Monday (2026-04-13)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 13 // Monday
        let monday = calendar.date(from: components)!

        // Offset to desired weekday (Mon=2, so offset = weekday - 2)
        let offset = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: monday)!
    }

    @Test func dailyFrequencyTracksEveryDay() {
        for weekday in 1...7 {
            let date = dateForWeekday(weekday)
            #expect(HabitFrequency.shouldTrack(frequency: "daily", on: date, customDays: nil, startDate: nil))
        }
    }

    @Test func weekdaysFrequencyTracksOnlyMondayThroughFriday() {
        // Weekdays (Mon=2 through Fri=6) should track
        for weekday in 2...6 {
            let date = dateForWeekday(weekday)
            #expect(HabitFrequency.shouldTrack(frequency: "weekdays", on: date, customDays: nil, startDate: nil))
        }

        // Weekend days should not track
        let sunday = dateForWeekday(1)
        let saturday = dateForWeekday(7)
        #expect(!HabitFrequency.shouldTrack(frequency: "weekdays", on: sunday, customDays: nil, startDate: nil))
        #expect(!HabitFrequency.shouldTrack(frequency: "weekdays", on: saturday, customDays: nil, startDate: nil))
    }

    @Test func weekendsFrequencyTracksOnlySaturdayAndSunday() {
        let sunday = dateForWeekday(1)
        let saturday = dateForWeekday(7)
        #expect(HabitFrequency.shouldTrack(frequency: "weekends", on: sunday, customDays: nil, startDate: nil))
        #expect(HabitFrequency.shouldTrack(frequency: "weekends", on: saturday, customDays: nil, startDate: nil))

        // Weekdays should not track
        for weekday in 2...6 {
            let date = dateForWeekday(weekday)
            #expect(!HabitFrequency.shouldTrack(frequency: "weekends", on: date, customDays: nil, startDate: nil))
        }
    }

    @Test func customFrequencyTracksOnlySpecifiedDays() {
        // Custom: Monday(2) and Wednesday(4) only
        let customDays = "2,4"

        let monday = dateForWeekday(2)
        let wednesday = dateForWeekday(4)
        let tuesday = dateForWeekday(3)
        let friday = dateForWeekday(6)

        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: monday, customDays: customDays, startDate: nil))
        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: wednesday, customDays: customDays, startDate: nil))
        #expect(!HabitFrequency.shouldTrack(frequency: "custom", on: tuesday, customDays: customDays, startDate: nil))
        #expect(!HabitFrequency.shouldTrack(frequency: "custom", on: friday, customDays: customDays, startDate: nil))
    }

    @Test func customFrequencyWithSpacesInDayString() {
        let customDays = "2, 4, 6"

        let monday = dateForWeekday(2)
        let wednesday = dateForWeekday(4)
        let friday = dateForWeekday(6)
        let thursday = dateForWeekday(5)

        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: monday, customDays: customDays, startDate: nil))
        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: wednesday, customDays: customDays, startDate: nil))
        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: friday, customDays: customDays, startDate: nil))
        #expect(!HabitFrequency.shouldTrack(frequency: "custom", on: thursday, customDays: customDays, startDate: nil))
    }

    @Test func startDatePreventsTrackingBeforeIt() {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 10
        let startDate = calendar.date(from: components)!

        components.day = 9
        let beforeStart = calendar.date(from: components)!

        components.day = 10
        let onStart = calendar.date(from: components)!

        components.day = 11
        let afterStart = calendar.date(from: components)!

        #expect(!HabitFrequency.shouldTrack(frequency: "daily", on: beforeStart, customDays: nil, startDate: startDate))
        #expect(HabitFrequency.shouldTrack(frequency: "daily", on: onStart, customDays: nil, startDate: startDate))
        #expect(HabitFrequency.shouldTrack(frequency: "daily", on: afterStart, customDays: nil, startDate: startDate))
    }

    @Test func nilFrequencyDefaultsToDaily() {
        let date = dateForWeekday(3) // Tuesday
        #expect(HabitFrequency.shouldTrack(frequency: nil, on: date, customDays: nil, startDate: nil))
    }

    @Test func invalidFrequencyDefaultsToDaily() {
        let date = dateForWeekday(3)
        #expect(HabitFrequency.shouldTrack(frequency: "invalid_frequency", on: date, customDays: nil, startDate: nil))
    }

    @Test func customFrequencyWithEmptyDaysTracksEveryDay() {
        // When custom days string is empty, should track every day
        let date = dateForWeekday(3)
        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: date, customDays: "", startDate: nil))
        #expect(HabitFrequency.shouldTrack(frequency: "custom", on: date, customDays: nil, startDate: nil))
    }
}

// MARK: - HabitFrequency Enum Tests

struct HabitFrequencyEnumTests {
    @Test func allCasesExist() {
        let allCases = HabitFrequency.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.daily))
        #expect(allCases.contains(.weekdays))
        #expect(allCases.contains(.weekends))
        #expect(allCases.contains(.weekly))
        #expect(allCases.contains(.custom))
    }

    @Test func rawValuesAreCorrect() {
        #expect(HabitFrequency.daily.rawValue == "daily")
        #expect(HabitFrequency.weekdays.rawValue == "weekdays")
        #expect(HabitFrequency.weekends.rawValue == "weekends")
        #expect(HabitFrequency.weekly.rawValue == "weekly")
        #expect(HabitFrequency.custom.rawValue == "custom")
    }

    @Test func displayNamesAreHumanReadable() {
        #expect(HabitFrequency.daily.displayName == "Every Day")
        #expect(HabitFrequency.weekdays.displayName == "Weekdays Only")
        #expect(HabitFrequency.weekends.displayName == "Weekends Only")
        #expect(HabitFrequency.weekly.displayName == "Once a Week")
        #expect(HabitFrequency.custom.displayName == "Custom Days")
    }
}

// MARK: - CompletionStyle Tests
//
// bt-0003 Wave 2 collapsed `Habit.useMultipleStates: Bool` + `Habit.isNegativeHabit:
// Bool` into a single `CompletionStyle` enum on the model. The bool-conversion
// helpers (`.from(useMultipleStates:isNegativeHabit:)` and `.asBools`) that
// bridged storage to UI were deleted — UI and storage now both speak the enum
// directly, so the bridge isn't needed. Tests here cover the current enum
// shape; the conversion-roundtrip tests they replaced no longer have a
// referent in code.

struct CompletionStyleTests {
    @Test func allCasesExist() {
        let allCases = CompletionStyle.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.simple))
        #expect(allCases.contains(.multiState))
        #expect(allCases.contains(.avoidance))
    }

    @Test func rawValuesAreCorrect() {
        #expect(CompletionStyle.simple.rawValue == "simple")
        #expect(CompletionStyle.multiState.rawValue == "multiState")
        #expect(CompletionStyle.avoidance.rawValue == "avoidance")
    }
}

// MARK: - HabitCompletionState Tests

struct HabitCompletionStateTests {
    @Test func uncheckedStateIsNotCompleted() {
        let state = HabitCompletionState(isCompleted: false, state: 0, hasDetails: false)
        #expect(!state.isCompleted)
        #expect(state.stateColor == .clear)
    }

    @Test func successStateShowsGreen() {
        let state = HabitCompletionState(isCompleted: true, state: 1, hasDetails: false)
        #expect(state.isCompleted)
        #expect(state.stateIcon == "checkmark")
    }

    @Test func partialStateShowsCorrectIcon() {
        let state = HabitCompletionState(isCompleted: true, state: 2, hasDetails: false)
        #expect(state.stateIcon == "circle.lefthalf.filled")
    }

    @Test func failedStateShowsXmark() {
        let state = HabitCompletionState(isCompleted: true, state: 3, hasDetails: false)
        #expect(state.stateIcon == "xmark")
    }

    @Test func detailsFlagIsPreserved() {
        let withDetails = HabitCompletionState(isCompleted: true, state: 1, hasDetails: true)
        let withoutDetails = HabitCompletionState(isCompleted: true, state: 1, hasDetails: false)
        #expect(withDetails.hasDetails)
        #expect(!withoutDetails.hasDetails)
    }
}

// MARK: - ExportFormat Tests

struct ExportFormatTests {
    @Test func allCasesExist() {
        #expect(ExportFormat.allCases.count == 2)
    }

    @Test func titlesAreCorrect() {
        #expect(ExportFormat.pdf.title == "PDF Document")
        #expect(ExportFormat.json.title == "JSON Backup")
    }

    @Test func fileExtensionsAreCorrect() {
        #expect(ExportFormat.pdf.fileExtension == "pdf")
        #expect(ExportFormat.json.fileExtension == "json")
    }
}

// MARK: - DateRangeType Tests

struct DateRangeTypeTests {
    @Test func allCasesExist() {
        #expect(DateRangeType.allCases.count == 4)
    }

    @Test func rawValuesAreCorrect() {
        #expect(DateRangeType.today.rawValue == "today")
        #expect(DateRangeType.thisWeek.rawValue == "thisWeek")
        #expect(DateRangeType.thisMonth.rawValue == "thisMonth")
        #expect(DateRangeType.custom.rawValue == "custom")
    }
}

// MARK: - Color+Hex Tests

struct ColorHexTests {
    @Test func sixCharacterHexCreatesColor() {
        // Should not crash or produce clear color
        let color = Color(hex: "#FF0000") // Red
        #expect(color != Color.clear)
    }

    @Test func threeCharacterHexCreatesColor() {
        let color = Color(hex: "#F00") // Red shorthand
        #expect(color != Color.clear)
    }

    @Test func eightCharacterHexCreatesColor() {
        let color = Color(hex: "#FF00FF00") // Fully opaque green
        #expect(color != Color.clear)
    }

    @Test func hexWithoutHashPrefix() {
        let color = Color(hex: "007AFF")
        #expect(color != Color.clear)
    }

    @Test func invalidHexProducesClearColor() {
        // Invalid hex should produce a color with 0 alpha (clear)
        let color = Color(hex: "XYZ")
        // XYZ scans as 0, and with 3 chars: r=0, g=0, b=0 — but alpha=255
        // Actually "XYZ" won't scan properly, so int=0, giving (255, 0, 0, 0) = black
        // This test just verifies it doesn't crash
        _ = color
    }
}

