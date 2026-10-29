//
//  Bullet_TrackerTests.swift
//  Bullet TrackerTests
//
//  Created by Dustin Brown on 5/12/25.
//

import Testing
import SwiftUI
import SwiftData
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

    /// A habit created mid-day (startDate carries a time of day) must still be
    /// tracked on that same day when Today asks about start-of-day. bt-0008.
    @Test func startDateWithTimeOfDayStillTracksSameDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 24
        components.hour = 10
        components.minute = 44
        let startDateMidMorning = calendar.date(from: components)!

        let sameDayMidnight = calendar.startOfDay(for: startDateMidMorning)
        let dayBeforeMidnight = calendar.date(byAdding: .day, value: -1, to: sameDayMidnight)!

        #expect(HabitFrequency.shouldTrack(frequency: "daily", on: sameDayMidnight, customDays: nil, startDate: startDateMidMorning))
        #expect(!HabitFrequency.shouldTrack(frequency: "daily", on: dayBeforeMidnight, customDays: nil, startDate: startDateMidMorning))
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

// MARK: - Win Rule Tests (bt-0014)
//
// The single definition of "this day counts", shared by the Today header,
// streaks, completion rates, heatmap and PDF summary.

struct HabitWinRuleTests {
    @Test func simpleHabitWinsWhenChecked() {
        #expect(HabitWinRule.isWin(style: .simple, state: .success, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .simple, state: nil, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .simple, state: .notDone, isFuture: false))
    }

    @Test func multiStateSuccessAndPartialWinButTriedDoesNot() {
        #expect(HabitWinRule.isWin(style: .multiState, state: .success, isFuture: false))
        #expect(HabitWinRule.isWin(style: .multiState, state: .partial, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .multiState, state: .failure, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .multiState, state: nil, isFuture: false))
    }

    /// bt-0024 — an avoidance habit is never a win: a clean day is nothing
    /// (it used to be a win, which read as a 365-day Weed streak).
    @Test func avoidanceIsNeverAWin() {
        #expect(!HabitWinRule.isWin(style: .avoidance, state: nil, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .avoidance, state: .notDone, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .avoidance, state: .failure, isFuture: false))
        #expect(!HabitWinRule.isWin(style: .avoidance, state: nil, isFuture: true))
    }

    @Test func avoidanceIsScoredBySlips() {
        #expect(HabitWinRule.isSlipScored(style: .avoidance))
        #expect(!HabitWinRule.isSlipScored(style: .simple))
        #expect(!HabitWinRule.isSlipScored(style: .multiState))
        #expect(HabitWinRule.isSlip(style: .avoidance, state: .failure))
        // Legacy slips were stored as `.success`; still a slip.
        #expect(HabitWinRule.isSlip(style: .avoidance, state: .success))
        #expect(!HabitWinRule.isSlip(style: .avoidance, state: nil))
        #expect(!HabitWinRule.isSlip(style: .avoidance, state: .notDone))
        // A positive habit's miss is not a slip.
        #expect(!HabitWinRule.isSlip(style: .multiState, state: .failure))
    }

    @Test func loggedMeansAnyNonEmptyState() {
        #expect(!HabitWinRule.isLogged(state: nil))
        #expect(!HabitWinRule.isLogged(state: .notDone))
        #expect(HabitWinRule.isLogged(state: .success))
        #expect(HabitWinRule.isLogged(state: .failure))
        #expect(HabitWinRule.isLogged(state: .rest))
    }

    // bt-0018 — Rest is neutral: logged, not a win, not a miss.
    @Test func restIsNeutralNotAWin() {
        #expect(!HabitWinRule.isWin(style: .multiState, state: .rest, isFuture: false))
        #expect(HabitWinRule.isNeutral(state: .rest))
        #expect(!HabitWinRule.isNeutral(state: .failure))
        #expect(!HabitWinRule.isNeutral(state: nil))
    }
}

// MARK: - Streaks carry through Rest (bt-0018)

struct RestStreakTests {
    private let calendar = Calendar.current
    private let service = HabitCalculationService.shared

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    private func entries(_ states: [Int: CompletionState]) -> [Date: HabitEntry] {
        var result: [Date: HabitEntry] = [:]
        for (offset, state) in states {
            result[day(offset)] = HabitEntry(date: day(offset), completionState: state)
        }
        return result
    }

    @Test func restDayDoesNotBreakOrExtendCurrentStreak() {
        let habit = Habit(name: "Workout", frequency: "daily", completionStyle: .multiState)
        // Done two days ago and yesterday, Rest today → streak 2 (not 0, not 3).
        let withRest = entries([-2: .success, -1: .success, 0: .rest])
        #expect(service.calculateCurrentStreak(for: habit, using: withRest) == 2)
        // Rest in the middle: done, rest, done → 2.
        let restInMiddle = entries([-2: .success, -1: .rest, 0: .success])
        #expect(service.calculateCurrentStreak(for: habit, using: restInMiddle) == 2)
        // Tried today still breaks it.
        let tried = entries([-2: .success, -1: .success, 0: .failure])
        #expect(service.calculateCurrentStreak(for: habit, using: tried) == 0)
    }

    @Test func restDayDropsOutOfCompletionRate() {
        let habit = Habit(name: "Workout", frequency: "daily", completionStyle: .multiState)
        // 4 days: done, done, rest, tried → 2 of 3 scored days.
        let e = entries([-3: .success, -2: .success, -1: .rest, 0: .failure])
        let rate = service.calculateCompletionRate(for: habit, using: e, from: day(-3), to: day(0))
        #expect(rate.completed == 2)
        #expect(rate.expected == 3)
    }

    @Test func bestStreakSkipsRest() {
        let habit = Habit(name: "Workout", frequency: "daily", completionStyle: .multiState)
        let e = entries([-4: .success, -3: .rest, -2: .success, -1: .success, 0: .failure])
        #expect(service.calculateBestStreak(for: habit, using: e, from: day(-4), to: day(0)) == 3)
    }
}

// MARK: - Avoidance scoring (bt-0024)
//
// Only slips get marked. A clean day is nothing: no streak, no win. The rate
// is a slip rate (slip days / scored days), and the overall figure is
// positive habits only.

struct AvoidanceScoringTests {
    private let calendar = Calendar.current
    private let service = HabitCalculationService.shared

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    private func entries(_ states: [Int: CompletionState]) -> [Date: HabitEntry] {
        var result: [Date: HabitEntry] = [:]
        for (offset, state) in states {
            result[day(offset)] = HabitEntry(date: day(offset), completionState: state)
        }
        return result
    }

    /// The bug that surfaced after the bt-0022 wipe: a year of clean days
    /// read as a 365-day streak. Now 0, slip or no slip.
    @Test func avoidanceHasNoStreaks() {
        let weed = Habit(name: "Weed", frequency: "daily", completionStyle: .avoidance)
        #expect(service.calculateCurrentStreak(for: weed, using: [:]) == 0)
        #expect(service.calculateCurrentStreak(for: weed, using: entries([-3: .failure])) == 0)
        #expect(service.calculateBestStreak(for: weed, using: [:], from: day(-30), to: day(0)) == 0)
    }

    @Test func avoidanceRateIsSlipDaysOverScoredDays() {
        let weed = Habit(name: "Weed", frequency: "daily", completionStyle: .avoidance)
        // 10 days, slips on three of them → 3 of 10, 30%.
        let e = entries([-8: .failure, -4: .success, -1: .failure])
        let rate = service.calculateCompletionRate(for: weed, using: e, from: day(-9), to: day(0))
        #expect(rate.completed == 3)
        #expect(rate.expected == 10)
        #expect(abs(rate.rate - 0.3) < 0.0001)
        // No slips → 0%, not 100%.
        let clean = service.calculateCompletionRate(for: weed, using: [:], from: day(-9), to: day(0))
        #expect(clean.completed == 0 && clean.expected == 10 && clean.rate == 0)
    }

    @Test func batchStatsKeepSlipsOutOfTheOverallFigure() {
        let sauna = Habit(name: "Sauna", frequency: "daily", completionStyle: .simple)
        let weed = Habit(name: "Weed", frequency: "daily", completionStyle: .avoidance)
        let saunaID = sauna.id!, weedID = weed.id!
        // Sauna done 2 of 4 days; Weed slipped 1 of 4.
        let all: [UUID: [Date: HabitEntry]] = [
            saunaID: entries([-3: .success, -1: .success]),
            weedID: entries([-2: .failure]),
        ]
        let batch = service.calculateBatchStats(for: [sauna, weed], allEntries: all, from: day(-3), to: day(0))
        let weedStat = batch.habitStats.first { $0.habitId == weedID }!
        let saunaStat = batch.habitStats.first { $0.habitId == saunaID }!
        #expect(weedStat.isSlipRate && weedStat.completedCount == 1 && weedStat.expectedDays == 4 && weedStat.completionRate == 25)
        #expect(!saunaStat.isSlipRate && saunaStat.completionRate == 50)
        // Overall: Sauna only. A slip never lowers it.
        #expect(batch.totalCompleted == 2 && batch.totalExpected == 4)
        #expect(weedStat.currentStreak == 0)
        // The all-habits streak ignores Weed: Sauna done yesterday but not today → 0,
        // and with Sauna done today → 1 regardless of Weed's slip.
        #expect(service.calculateOverallCurrentStreak(for: [sauna, weed], using: all) == 0)
        var withToday = all
        withToday[saunaID] = entries([-1: .success, 0: .success])
        withToday[weedID] = entries([0: .failure])
        #expect(service.calculateOverallCurrentStreak(for: [sauna, weed], using: withToday) == 2)
    }

    /// The Today header and the widget line: a clean day adds nothing, a
    /// slip is said.
    @Test func daySummaryNamesSlipsAndNeverCleanDays() {
        #expect(DaySummary(positiveDone: 5, positiveTotal: 8, avoidanceTotal: 2, slips: 0).text(emptyText: "-") == "5 of 8 done")
        #expect(DaySummary(positiveDone: 5, positiveTotal: 8, avoidanceTotal: 2, slips: 1).text(emptyText: "-") == "5 of 8 done · 1 slip")
        #expect(DaySummary(positiveDone: 8, positiveTotal: 8, avoidanceTotal: 2, slips: 2).text(emptyText: "-") == "All 8 done · 2 slips")
        // Only avoidance habits scheduled and clean: nothing to say.
        #expect(DaySummary(positiveDone: 0, positiveTotal: 0, avoidanceTotal: 2, slips: 0).text(emptyText: "-") == "")
        #expect(DaySummary(positiveDone: 0, positiveTotal: 0, avoidanceTotal: 0, slips: 0).text(emptyText: "-") == "-")
    }
}

// MARK: - Today row (bt-0026)

/// The Reminders-style row: one round control, six quiet dots, two sections.
struct TodayRowTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    /// The subtitle counts the habits you do; the Avoiding trailer says
    /// slips only and never "clean".
    @Test func subtitleIsPositiveOnlyAndTrailerIsSlipsOnly() {
        let threeOfFour = DaySummary(positiveDone: 3, positiveTotal: 4, avoidanceTotal: 2, slips: 1)
        #expect(threeOfFour.positiveText(emptyText: "-") == "3 of 4 done")
        #expect(threeOfFour.slipsText == "1 slipped")
        let allClean = DaySummary(positiveDone: 4, positiveTotal: 4, avoidanceTotal: 2, slips: 0)
        #expect(allClean.positiveText(emptyText: "-") == "All 4 done")
        #expect(allClean.slipsText == nil, "A clean day says nothing — only slips get marked")
        #expect(DaySummary(positiveDone: 0, positiveTotal: 0, avoidanceTotal: 2, slips: 2).slipsText == "2 slipped")
        #expect(DaySummary(positiveDone: 0, positiveTotal: 0, avoidanceTotal: 0, slips: 0).positiveText(emptyText: "-") == "-")
    }

    /// A day's state → palette colour and control symbol, never the habit's colour.
    @Test func dayMarkUsesPaletteColoursAndTheRightSymbol() {
        #expect(DayMark(state: nil, isAvoidance: false) == .empty)
        #expect(DayMark(state: .notDone, isAvoidance: false) == .empty)
        #expect(DayMark(state: .success, isAvoidance: false) == .done)
        #expect(DayMark(state: .partial, isAvoidance: false) == .partial)
        #expect(DayMark(state: .failure, isAvoidance: false) == .missed)
        #expect(DayMark(state: .rest, isAvoidance: false) == .rest)
        // Avoidance: anything logged is a slip (bt-0024).
        #expect(DayMark(state: .failure, isAvoidance: true) == .missed)
        #expect(DayMark(state: .success, isAvoidance: true) == .missed)
        #expect(DayMark(state: nil, isAvoidance: true) == .empty)

        #expect(DayMark.empty.color == nil)
        #expect(DayMark.done.color == AppTheme.success)
        #expect(DayMark.partial.color == AppTheme.partial)
        #expect(DayMark.missed.color == AppTheme.failed)
        #expect(DayMark.rest.color == AppTheme.rest)

        #expect(DayMark.empty.controlSymbol(isAvoidance: false) == "circle")
        #expect(DayMark.empty.controlSymbol(isAvoidance: true) == "circle.slash", "An avoidance habit's empty control must not invite a 'done' tap")
        #expect(DayMark.done.controlSymbol(isAvoidance: false) == "checkmark.circle.fill")
        #expect(DayMark.partial.controlSymbol(isAvoidance: false) == "checkmark.circle.fill")
        #expect(DayMark.missed.controlSymbol(isAvoidance: true) == "xmark.circle.fill")
        #expect(DayMark.rest.controlSymbol(isAvoidance: false) == "moon.circle.fill")

        #expect(DayMark.empty.spokenText(isAvoidance: true) == "Clean so far")
        #expect(DayMark.missed.spokenText(isAvoidance: true) == "Slipped")
        #expect(DayMark.missed.spokenText(isAvoidance: false) == "Tried")
    }

    /// The dots are the six days before the selected day, oldest first; the
    /// selected day itself is the control, not a dot.
    @Test func dotWindowIsTheSixDaysBeforeTheSelectedDay() {
        let forToday = WeekGridMetrics.previousDays(before: day(0), calendar: calendar)
        #expect(forToday.count == 6)
        #expect(forToday.first == day(-6))
        #expect(forToday.last == day(-1))
        #expect(!forToday.contains(day(0)))
        // Stepping back three days moves the whole window with it.
        let forPast = WeekGridMetrics.previousDays(before: day(-3), calendar: calendar)
        #expect(forPast == [day(-9), day(-8), day(-7), day(-6), day(-5), day(-4)])
    }

    /// The list is two sections — the habits you do, then Avoiding — each in
    /// display order.
    @Test @MainActor func sectionsSplitAvoidanceAndKeepOrder() {
        let diet = Habit(name: "Diet", frequency: "daily", completionStyle: .simple)
        let weed = Habit(name: "Weed", frequency: "daily", completionStyle: .avoidance)
        let reading = Habit(name: "Reading", frequency: "daily", completionStyle: .multiState)
        let alcohol = Habit(name: "Alcohol", frequency: "daily", completionStyle: .avoidance)
        let viewModel = TodayViewModel()
        let all = [diet, weed, reading, alcohol]
        #expect(viewModel.positiveHabits(from: all).map(\.name) == ["Diet", "Reading"])
        #expect(viewModel.avoidanceHabits(from: all).map(\.name) == ["Weed", "Alcohol"])
    }

    /// A past day's caption numbers come from the stored `health` block, in
    /// the same words as the engine's live caption.
    @Test func pastDayCaptionReadsTheStoredHealthBlock() {
        let diet = Habit(name: "Diet", frequency: "daily", completionStyle: .simple)
        diet.gradingKind = .diet
        let meals = HealthSnapshot(meals: [.init(id: "a", name: "A", calories: 1_500, protein: 100),
                                           .init(id: "b", name: "B", calories: 606, protein: 18.5)])
        #expect(TodayHabitRowView.numbers(from: meals, habit: diet) == "118 / \(Int(diet.gradingTargets.proteinFloorGrams)) g · 2,106 cal")
        #expect(TodayHabitRowView.numbers(from: HealthSnapshot(), habit: diet) == nil)

        let workout = Habit(name: "Workout", frequency: "daily", completionStyle: .simple)
        workout.gradingKind = .workout
        let session = HealthSnapshot(sessions: [.init(name: "Walk", category: "walking", minutes: 45, sets: 0, start: nil)], steps: 6_120)
        #expect(TodayHabitRowView.numbers(from: session, habit: workout) == "45 min · 6,120 steps")
        #expect(TodayHabitRowView.numbers(from: HealthSnapshot(sessions: [], steps: 3_000), habit: workout) == "3,000 steps")
        #expect(TodayHabitRowView.numbers(from: HealthSnapshot(), habit: workout) == nil)
    }
}

// MARK: - Grading rules (bt-0017 / bt-0018)

struct GradingRuleTests {
    @Test func dietUsesTheHabitsTargets() {
        let defaults = GradingTargets.defaults
        #expect(DietGrade.state(proteinGrams: 190, calories: 2050, targets: defaults) == .success)
        #expect(DietGrade.state(proteinGrams: 190, calories: 1500, targets: defaults) == .partial)
        #expect(DietGrade.state(proteinGrams: 100, calories: 1200, targets: defaults) == .failure)
        #expect(DietGrade.state(proteinGrams: nil, calories: nil, targets: defaults) == .failure)
        // Raise the protein floor to 200 → the same 190 g day is only Partial.
        var raised = defaults
        raised.proteinFloorGrams = 200
        #expect(DietGrade.state(proteinGrams: 190, calories: 2050, targets: raised) == .partial)
    }

    @Test func workoutMinutesThenStepsThenUnknown() {
        let t = GradingTargets.defaults
        #expect(WorkoutGrade.state(minutes: 45, steps: 0, targets: t) == .success)
        #expect(WorkoutGrade.state(minutes: 0, steps: 12_000, targets: t) == .partial)
        #expect(WorkoutGrade.state(minutes: nil, steps: 12_000, targets: t) == .partial)
        #expect(WorkoutGrade.state(minutes: 0, steps: 4_000, targets: t) == .failure)
        // Minutes unknown and steps under target: can't grade → nil, never red.
        #expect(WorkoutGrade.state(minutes: nil, steps: 4_000, targets: t) == nil)
        #expect(WorkoutGrade.state(minutes: nil, steps: nil, targets: t) == nil)
    }

    @Test func todayIsNeverRedUntilItIsOver() {
        #expect(InProgressRule.apply(.failure, isToday: true) == nil)
        #expect(InProgressRule.apply(.failure, isToday: false) == .failure)
        #expect(InProgressRule.apply(.partial, isToday: true) == .partial)
        #expect(InProgressRule.apply(.success, isToday: true) == .success)
        #expect(InProgressRule.apply(nil, isToday: false) == nil)
    }

    @Test func habitTargetsFallBackToDefaultsWhenBlank() {
        let habit = Habit(name: "Diet", completionStyle: .multiState)
        #expect(habit.gradingTargets == GradingTargets.defaults)
        habit.targetProteinGrams = 200
        #expect(habit.gradingTargets.proteinFloorGrams == 200)
        #expect(habit.gradingTargets.calorieFloor == 1900)
    }

    @Test func goLiveDayGatesGradingAndBackToAutomatic() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let habit = Habit(name: "Diet", completionStyle: .multiState)
        #expect(!habit.isAutoGraded)
        #expect(!habit.isWithinGrading(today))
        habit.gradingKind = .diet
        habit.gradingSince = today
        #expect(habit.isAutoGraded)
        #expect(habit.isWithinGrading(today))
        #expect(!habit.isWithinGrading(yesterday))
    }

    @Test func entriesWithoutASourceCountAsHand() {
        let entry = HabitEntry(date: Date(), completionState: .success)
        #expect(entry.source == .hand)
        #expect(!entry.isAutomatic)
        let auto = HabitEntry(date: Date(), completionState: .success, source: .auto)
        #expect(auto.isAutomatic)
    }
}

// MARK: - Store writes + cleanup on an in-memory store (bt-0018)

@MainActor
struct HabitStoreWriteTests {
    private func makeContext() throws -> ModelContext {
        // No CloudKit on the test store: `.automatic` picks up the app's
        // iCloud entitlement, the mirroring setup fails without an account
        // on the simulator, and the first save then throws "No eligible
        // connection available" (seen on the iOS 27.1 runtime, bt-0021).
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func tapStampsHandSourceAndEditTime() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let habit = Habit(name: "Test Diet", frequency: "daily", completionStyle: .multiState)
        context.insert(habit)
        try context.save()

        HabitStore.setCompletion(for: habit, on: today, state: 3, in: context)
        let row = try #require(HabitStore.entry(for: habit, on: today))
        #expect(row.source == .hand)
        #expect(row.editedAt != nil)

        HabitStore.setCompletion(for: habit, on: today, state: 1, source: .auto, in: context)
        #expect(HabitStore.entry(for: habit, on: today)?.source == .auto)
        #expect(HabitStore.entryCount(for: habit, on: today) == 1)
    }

    @Test func cleanupKeepsTheHandRowOverNewerAutoRowsAndNeverReachesZero() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let habit = Habit(name: "Test Diet", frequency: "daily", completionStyle: .multiState)
        context.insert(habit)
        try context.save()

        HabitStore.setCompletion(for: habit, on: today, state: 3, in: context)
        let tapped = try #require(HabitStore.entry(for: habit, on: today))

        // Two auto duplicates: newer edit times AND smaller ids than the tap.
        context.insert(HabitEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001"), date: today,
                                  completionState: .success, habit: habit, source: .auto, editedAt: Date().addingTimeInterval(60)))
        context.insert(HabitEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002"), date: today,
                                  completionState: .partial, habit: habit, source: .auto, editedAt: Date().addingTimeInterval(120)))
        try context.save()
        #expect(HabitStore.entryCount(for: habit, on: today) == 3)
        // What's shown before cleanup is already the survivor.
        #expect(HabitStore.entry(for: habit, on: today)?.id == tapped.id)

        #expect(HabitStore.dedupeEntries(for: habit, on: today, in: context) == 2)
        let survivor = try #require(HabitStore.entry(for: habit, on: today))
        #expect(survivor.id == tapped.id)
        #expect(survivor.source == .hand)
        #expect(survivor.effectiveCompletionState == .failure)

        // Second pass: nothing to do; one row stays.
        #expect(HabitStore.dedupeEntries(for: habit, on: today, in: context) == 0)
        #expect(HabitStore.entryCount(for: habit, on: today) == 1)
    }

    @Test func restIsWrittenLikeAnyHandState() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let workout = Habit(name: "Test Workout", frequency: "daily", completionStyle: .multiState)
        workout.gradingKind = .workout
        context.insert(workout)
        try context.save()

        HabitStore.setCompletion(for: workout, on: today, state: Int(CompletionState.rest.rawValue), in: context)
        let row = HabitStore.entry(for: workout, on: today)
        #expect(row?.effectiveCompletionState == .rest)
        #expect(HabitStore.isNeutral(entry: row))
        #expect(!HabitStore.isWin(for: workout, entry: row, on: today))
        #expect(HabitStore.completionState(for: workout, entry: row).stateIcon == "zzz")
    }

    /// The Today row's "is this habit gone?" guard relies on these two facts
    /// (bt-0018 pass test crash): `isDeleted` is true only while the delete
    /// is pending; after the save the model is detached (`modelContext == nil`).
    @Test func deletedHabitIsDetachedAfterSave() throws {
        let context = try makeContext()
        let habit = Habit(name: "Test Diet", frequency: "daily", completionStyle: .multiState)
        context.insert(habit)
        try context.save()
        #expect(habit.modelContext != nil)
        #expect(!habit.isDeleted)

        context.delete(habit)
        #expect(habit.isDeleted)
        try context.save()
        #expect(habit.modelContext == nil)
    }

    @Test func engineGradeAppliesInProgressAndUnknownRules() {
        let today = Calendar.current.startOfDay(for: Date())
        let t = GradingTargets.defaults
        let neither = DayFacts(day: today, proteinGrams: 100, calories: 1200)
        #expect(HabitSyncEngine.grade(kind: .diet, targets: t, facts: neither, steps: nil, isToday: true) == nil)
        #expect(HabitSyncEngine.grade(kind: .diet, targets: t, facts: neither, steps: nil, isToday: false) == .failure)
        #expect(HabitSyncEngine.grade(kind: .diet, targets: t, facts: nil, steps: nil, isToday: false) == nil)
        #expect(HabitSyncEngine.grade(kind: .workout, targets: t, facts: nil, steps: 4000, isToday: false) == nil)
        #expect(HabitSyncEngine.grade(kind: .workout, targets: t, facts: nil, steps: 12000, isToday: true) == .partial)
        let zeroMinutes = DayFacts(day: today, proteinGrams: nil, calories: nil, workoutMinutes: 0)
        #expect(HabitSyncEngine.grade(kind: .workout, targets: t, facts: zeroMinutes, steps: 4000, isToday: false) == .failure)
        #expect(HabitSyncEngine.grade(kind: .workout, targets: t, facts: zeroMinutes, steps: 4000, isToday: true) == nil)
    }
}

// MARK: - Step 3, the real sync (bt-0019)

struct DustinHealthWireTests {
    @Test func dayStringsRoundTripAsLocalDays() throws {
        let day = try #require(DustinHealthWire.day(from: "2026-10-27"))
        #expect(day == Calendar.current.startOfDay(for: day))
        #expect(DustinHealthWire.string(from: day) == "2026-10-27")
        #expect(DustinHealthWire.day(from: "2026-13-40") == nil || DustinHealthWire.day(from: "nope") == nil)
    }

    @Test func factsBecomeDayFactsWithNothingTrackedAsNil() throws {
        let json = """
        {"time_zone":"America/New_York","days":[
          {"day":"2026-10-26","meals":{"count":2,"calories":2050,"protein":190.5,"carbs":100,"fat":60,"names":["Eggs","Chicken"],
             "items":[{"id":"m1","name":"Eggs","calories":450,"protein":30.5,"carbs":2,"fat":30,"logged_at":"2026-10-26T12:05:22.397+00:00"},
                      {"id":"m2","name":"Chicken","calories":null,"protein":160,"carbs":null,"fat":null,"logged_at":"2026-10-26T23:10:00+00:00"}]},
           "workouts":{"count":1,"minutes":45,"sessions":[{"name":"Incline walk","category":"walking","minutes":45,"set_count":13,"started_at":"2026-10-26T12:00:00+00:00","active_kcal":368.938,"activity_type":"Indoor Walk","activity_code":52}]}},
          {"day":"2026-10-27","meals":{"count":0,"calories":0,"protein":0,"carbs":0,"fat":0,"names":[]},
           "workouts":{"count":0,"minutes":0,"sessions":[]}}
        ]}
        """
        let response = try JSONDecoder().decode(DustinHealthClient.FactsResponse.self, from: Data(json.utf8))
        let facts = DustinHealthWire.facts(response)
        let tracked = try #require(facts[DustinHealthWire.day(from: "2026-10-26")!])
        #expect(tracked.proteinGrams == 190.5)
        #expect(tracked.calories == 2050)
        #expect(tracked.workoutMinutes == 45)
        #expect(tracked.mealNames == ["Eggs", "Chicken"])
        // bt-0021 — category, set count and start time ride along.
        let start = try #require(DustinHealthWire.timestamp(from: "2026-10-26T12:00:00+00:00"))
        // bt-0022 — active calories and Apple's activity name too; the code is read but not kept.
        #expect(tracked.sessions == [DayFacts.Session(name: "Incline walk", minutes: 45, category: "walking", setCount: 13, startedAt: start,
                                                      activeKcal: 368.938, activityType: "Indoor Walk")])
        // bt-0021 — per-meal items; null is nil (a dash), never 0; fractional seconds parse.
        #expect(tracked.meals.count == 2)
        #expect(tracked.meals[0].name == "Eggs" && tracked.meals[0].calories == 450 && tracked.meals[0].protein == 30.5)
        let whole = try #require(DustinHealthWire.timestamp(from: "2026-10-26T12:05:22+00:00"))
        let logged = try #require(tracked.meals[0].loggedAt)
        #expect(abs(logged.timeIntervalSince(whole) - 0.397) < 0.001)
        #expect(tracked.meals[1].calories == nil && tracked.meals[1].protein == 160 && tracked.meals[1].fat == nil)
        #expect(DustinHealthWire.timestamp(from: nil) == nil && DustinHealthWire.timestamp(from: "nope") == nil)
        let empty = try #require(facts[DustinHealthWire.day(from: "2026-10-27")!])
        #expect(empty.proteinGrams == nil)
        #expect(empty.calories == nil)
        #expect(empty.workoutMinutes == 0)
        // Nothing tracked still grades as a miss, as the design says.
        #expect(DietGrade.state(for: empty) == .failure)
    }

    @Test func inboxRowsBecomeActions() throws {
        let json = """
        {"actions":[
          {"id":"a1","habit":"Test Sauna","kind":"simple","day":"2026-10-27","action":"tick","status":"pending","created_at":"x"},
          {"id":"a2","habit":"Read","kind":"simple","day":"2026-10-27","action":"tick","book":"Harry Potter","pages":30,"status":"pending","created_at":"x"},
          {"id":"a3","habit":"Diet","kind":"graded","day":"2026-10-26","action":"set_grade","grade":"partial","status":"pending","created_at":"x"},
          {"id":"a4","habit":"Workout","kind":"graded","day":"2026-10-27","action":"note","note":"knee felt tight","status":"pending","created_at":"x"},
          {"id":"a5","day":"2026-10-27","action":"set_target","target_key":"protein_min_g","target_value":190,"status":"pending","created_at":"x"},
          {"id":"a6","habit":"Sauna","kind":"simple","day":"2026-10-27","action":"untick","status":"pending","created_at":"x"},
          {"id":"a7","habit":"Sauna","kind":"simple","day":"2026-10-27","action":"something_new","status":"pending","created_at":"x"}
        ]}
        """
        let response = try JSONDecoder().decode(DustinHealthClient.InboxResponse.self, from: Data(json.utf8))
        let actions = DustinHealthWire.actions(response)
        #expect(actions.count == 6)
        #expect(actions[0].kind == .tick(note: nil, book: nil, pages: nil))
        #expect(actions[1].kind == .tick(note: nil, book: "Harry Potter", pages: 30))
        #expect(actions[2].kind == .setGrade(.partial))
        #expect(actions[3].kind == .note(text: "knee felt tight", book: nil, pages: nil))
        #expect(actions[4].kind == .setTarget(.proteinMinGrams, 190))
        #expect(actions[4].habitName == nil)
        #expect(actions[5].kind == .untick)
    }

    @Test func syncReplyKeepsHeldTargets() throws {
        let json = """
        {"habits":12,"held_targets":["protein_min_g"],"targets":{"protein_min_g":190,"calories_min":1900,"calories_max":2200,"workout_minutes_min":30,"steps_min":10000},"time_zone":"America/New_York"}
        """
        let reply = DustinHealthWire.syncReply(try JSONDecoder().decode(DustinHealthClient.SyncResponse.self, from: Data(json.utf8)))
        #expect(reply.heldTargets == [.proteinMinGrams])
        #expect(reply.targets[.proteinMinGrams] == 190)
        #expect(reply.targets[.stepsMin] == 10_000)
    }

    @Test func syncRequestSendsExplicitNullDetailKind() throws {
        let payload = HabitSyncPayload(
            habits: [.init(name: "Read", kind: "simple", detailKind: "reading_log"), .init(name: "Sauna", kind: "simple", detailKind: nil)],
            targets: [.proteinMinGrams: 180], timeZone: "America/New_York", tickedToday: ["Sauna"])
        let data = try JSONEncoder().encode(DustinHealthWire.syncRequest(payload))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let habits = try #require(object["habits"] as? [[String: Any]])
        #expect(habits[0]["detail_kind"] as? String == "reading_log")
        #expect(habits[1]["detail_kind"] is NSNull)
        #expect((object["targets"] as? [String: Double])?["protein_min_g"] == 180)
        #expect(object["ticked_today"] as? [String] == ["Sauna"])
    }

    @Test func rangesSplitAtGapsAndAtTheCap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func d(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        let ranges = DustinHealthWire.ranges(of: [d(0), d(-1), d(-2), d(-10)], calendar: calendar)
        #expect(ranges.count == 2)
        #expect(ranges[0].from == d(-10) && ranges[0].to == d(-10))
        #expect(ranges[1].from == d(-2) && ranges[1].to == d(0))
        let long = DustinHealthWire.ranges(of: Set((0..<100).map { d(-$0) }), maxDays: 93, calendar: calendar)
        #expect(long.count == 2)
        #expect(long.allSatisfy { (calendar.dateComponents([.day], from: $0.from, to: $0.to).day ?? 0) < 93 })
        #expect(DustinHealthWire.ranges(of: []).isEmpty)
    }

    /// bt-0019 pass-test fix: dh's cursor carries "+00:00"; the "+" must be
    /// sent as %2B or the server reads it as a space and refuses it.
    @Test func plusInTheChangesCursorIsPercentEncoded() throws {
        let cursor = "2026-10-27T17:58:12.345678+00:00"
        let url = try #require(DustinHealthClient.url(base: DustinHealthClient.defaultBaseURL, op: "changes",
                                                      query: [URLQueryItem(name: "since", value: cursor)]))
        let query = try #require(url.query(percentEncoded: true))
        #expect(!query.contains("+"))
        #expect(query.contains("since=2026-10-27T17%3A58%3A12.345678%2B00%3A00") || query.contains("since=2026-10-27T17:58:12.345678%2B00:00"))
        // What a server that turns "+" into a space, then percent-decodes, sees:
        let serverSide = query.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        #expect(serverSide?.contains("since=\(cursor)") == true)
        #expect(url.absoluteString.hasPrefix("https://dustin-health.vercel.app/api/bullet?op=changes&"))
    }

    @Test func pastedKeyIsTrimmed() {
        #expect(APIKeyStore.trimmed("  abc123\n") == "abc123")
        #expect(APIKeyStore.trimmed("abc 123") == "abc 123")
        #expect(APIKeyStore.trimmed(" \n\t") == nil)
    }

    @Test func targetKeysMapToHabitFields() {
        let habit = Habit(name: "Diet", completionStyle: .multiState)
        habit.setTarget(.proteinMinGrams, to: 190)
        habit.setTarget(.caloriesMax, to: 2300)
        #expect(habit.targetProteinGrams == 190)
        #expect(habit.target(for: .caloriesMax) == 2300)
        #expect(habit.target(for: .stepsMin) == nil)
        #expect(TargetKey.proteinMinGrams.gradingKind == .diet)
        #expect(TargetKey.stepsMin.gradingKind == .workout)
        // bt-0022 — the two ring ceilings belong to Diet and fill from 180 / 65.
        habit.setTarget(.fatMaxGrams, to: 70)
        #expect(habit.targetFatGrams == 70 && habit.target(for: .carbsMaxGrams) == nil)
        #expect(TargetKey.carbsMaxGrams.gradingKind == .diet && TargetKey.fatMaxGrams.rawValue == "fat_g")
        #expect(habit.gradingTargets.carbsCeilingGrams == 180 && habit.gradingTargets.fatCeilingGrams == 70)
        #expect(DietGrade.state(proteinGrams: 190, calories: 2000, targets: habit.gradingTargets) == .success) // carbs/fat never grade
        #expect(VoiceGrade.rest.completionState == .rest)
        #expect(VoiceGrade.auto.completionState == nil)
    }
}

@MainActor
struct SyncEngineStep3Tests {
    private func makeContext() throws -> ModelContext {
        // No CloudKit on the test store: `.automatic` picks up the app's
        // iCloud entitlement, the mirroring setup fails without an account
        // on the simulator, and the first save then throws "No eligible
        // connection available" (seen on the iOS 27.1 runtime, bt-0021).
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func payloadSendsKindsTargetsAndTodaysTicks() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let diet = Habit(name: "Diet", order: 0, completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        diet.targetProteinGrams = 190
        let read = Habit(name: "Read", order: 1, completionStyle: .simple, detailKind: .reading)
        let weed = Habit(name: "Weed", order: 2, completionStyle: .avoidance)
        let sauna = Habit(name: "Sauna", order: 3, completionStyle: .simple)
        let dupe = Habit(name: "sauna ", order: 4, completionStyle: .simple)
        for h in [diet, read, weed, sauna, dupe] { context.insert(h) }
        try context.save()
        HabitStore.setCompletion(for: sauna, on: today, state: 1, in: context)

        let payload = HabitSyncEngine.payload(habits: [diet, read, weed, sauna, dupe], today: today, timeZone: "America/New_York")
        #expect(payload.habits.map(\.name) == ["Diet", "Read", "Weed", "Sauna"])
        #expect(payload.habits.map(\.kind) == ["graded", "simple", "avoid", "simple"])
        #expect(payload.habits[1].detailKind == "reading_log")
        #expect(payload.habits[0].detailKind == nil)
        #expect(payload.targets[.proteinMinGrams] == 190)
        #expect(payload.targets[.caloriesMin] == 1900)
        #expect(payload.targets[.stepsMin] == nil)
        // bt-0022 — carbs / fat go up like the others (defaults when blank).
        #expect(payload.targets[.carbsMaxGrams] == 180 && payload.targets[.fatMaxGrams] == 65)
        #expect(payload.tickedToday == ["Sauna"])
        #expect(payload.timeZone == "America/New_York")
    }

    /// bt-0022 — with a Diet and a Workout habit graded, the wire carries
    /// exactly dh's seven target keys (dh rejects any key it doesn't know,
    /// `api/bullet.js:59`, and fails the whole sync).
    @Test func targetsOnTheWireAreExactlyTheSevenKeysDhAccepts() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let diet = Habit(name: "Diet", order: 0, completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        diet.targetCarbsGrams = 150
        let workout = Habit(name: "Workout", order: 1, completionStyle: .multiState)
        workout.gradingKind = .workout
        workout.gradingSince = today
        for h in [diet, workout] { context.insert(h) }
        try context.save()

        let payload = HabitSyncEngine.payload(habits: [diet, workout], today: today, timeZone: "America/New_York")
        let data = try JSONEncoder().encode(DustinHealthWire.syncRequest(payload))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let targets = try #require(object["targets"] as? [String: Double])
        #expect(Set(targets.keys) == ["protein_min_g", "calories_min", "calories_max", "workout_minutes_min", "steps_min", "carbs_g", "fat_g"])
        #expect(targets["carbs_g"] == 150 && targets["fat_g"] == 65)
    }

    @Test func daysToGradeAddChangedDaysOnOrAfterGoLiveOnly() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func d(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        let days = HabitSyncEngine.daysToGrade(since: d(-20), today: today, changedDays: [d(-15), d(-30), d(2)], calendar: calendar)
        #expect(days.first == d(-15))
        #expect(days.count == HabitSyncEngine.lookbackDays + 1)
        #expect(!days.contains(d(-30)) && !days.contains(d(2)))
        let young = HabitSyncEngine.daysToGrade(since: d(-2), today: today, changedDays: [d(-5)], calendar: calendar)
        #expect(young == [d(-2), d(-1), d(0)])
    }

    @Test func unknownFactsAreNotActedOn() {
        let t = GradingTargets.defaults
        #expect(!HabitSyncEngine.isKnown(kind: .diet, facts: nil, grade: nil))
        #expect(HabitSyncEngine.isKnown(kind: .diet, facts: DayFacts(day: Date(), proteinGrams: nil, calories: nil), grade: nil))
        #expect(!HabitSyncEngine.isKnown(kind: .workout, facts: nil, grade: nil))
        #expect(HabitSyncEngine.isKnown(kind: .workout, facts: nil, grade: .partial))
        #expect(HabitSyncEngine.isKnown(kind: .workout, facts: DayFacts(day: Date(), proteinGrams: nil, calories: nil, workoutMinutes: 0), grade: nil))
        _ = t
    }

    /// Dustin's rule (bt-0019 addition 3): a voice note adds details only.
    /// With no row it goes to the Journal; the automatic grade then colours
    /// the day as if the note had never happened — and the note survives.
    @Test func voiceNoteNeverBlocksTheAutomaticGrade() throws {
        let context = try makeContext()
        let engine = HabitSyncEngine.shared
        let today = Calendar.current.startOfDay(for: Date())
        let workout = Habit(name: "Test Workout", frequency: "daily", completionStyle: .multiState, detailKind: .workout)
        workout.gradingKind = .workout
        workout.gradingSince = today
        context.insert(workout)
        try context.save()

        let note = InboxAction(id: "n1", kind: .note(text: "knee felt tight", book: nil, pages: nil), habitName: "test workout", day: today)
        guard case .applied(let touched, _) = engine.applyInbox(note, on: today, habits: [workout], in: context) else {
            Issue.record("note was not applied")
            return
        }
        #expect(touched == nil)
        #expect(HabitStore.entry(for: workout, on: today) == nil)
        let journal = try context.fetch(FetchDescriptor<Note>())
        #expect(journal.count == 1)
        #expect(journal.first?.content == "Test Workout: knee felt tight")

        // The facts arrive: 45 minutes → the grader is free to write Done.
        HabitStore.setCompletion(for: workout, on: today, state: 1, source: .auto, in: context)
        let row = try #require(HabitStore.entry(for: workout, on: today))
        #expect(row.source == .auto)

        // A second note lands on the row's details, state and source untouched.
        let second = InboxAction(id: "n2", kind: .note(text: "stretch after", book: nil, pages: nil), habitName: "Test Workout", day: today)
        _ = engine.applyInbox(second, on: today, habits: [workout], in: context)
        let after = try #require(HabitStore.entry(for: workout, on: today))
        #expect(after.source == .auto)
        #expect(after.effectiveCompletionState == .success)
        if case .workout(_, _, _, let notes)? = after.details {
            #expect(notes == "stretch after")
        } else {
            Issue.record("expected workout details")
        }
    }

    @Test func voiceTickOnAnAvoidHabitIsTheSlipAndReadingDetailsRideAlong() throws {
        let context = try makeContext()
        let engine = HabitSyncEngine.shared
        let today = Calendar.current.startOfDay(for: Date())
        let weed = Habit(name: "Test Weed", frequency: "daily", completionStyle: .avoidance)
        let read = Habit(name: "Read", frequency: "daily", completionStyle: .simple, detailKind: .reading)
        context.insert(weed)
        context.insert(read)
        try context.save()

        _ = engine.applyInbox(InboxAction(id: "t1", kind: .tick(note: nil, book: nil, pages: nil), habitName: "Test Weed", day: today),
                              on: today, habits: [weed, read], in: context)
        let slip = try #require(HabitStore.entry(for: weed, on: today))
        #expect(slip.effectiveCompletionState == .failure)
        #expect(slip.source == .voice)

        _ = engine.applyInbox(InboxAction(id: "t2", kind: .tick(note: nil, book: "Harry Potter", pages: 30), habitName: "read", day: today),
                              on: today, habits: [weed, read], in: context)
        let reading = try #require(HabitStore.entry(for: read, on: today))
        #expect(reading.effectiveCompletionState == .success)
        #expect(reading.details == .reading(bookTitle: "Harry Potter", pagesRead: "30", notes: ""))

        // Undo removes the row; a target with no graded habit is skipped, not acked.
        _ = engine.applyInbox(InboxAction(id: "t3", kind: .untick, habitName: "Read", day: today), on: today, habits: [weed, read], in: context)
        #expect(HabitStore.entry(for: read, on: today) == nil)
        guard case .skipped = engine.applyInbox(InboxAction(id: "t4", kind: .setTarget(.proteinMinGrams, 190), habitName: nil, day: today),
                                                on: today, habits: [weed, read], in: context) else {
            Issue.record("target with no graded habit should be skipped")
            return
        }
    }

    @Test func voiceGradesRespectRestAndGoLive() throws {
        let context = try makeContext()
        let engine = HabitSyncEngine.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let diet = Habit(name: "Test Diet", frequency: "daily", completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        context.insert(diet)
        try context.save()

        _ = engine.applyInbox(InboxAction(id: "g1", kind: .setGrade(.partial), habitName: "Test Diet", day: today), on: today, habits: [diet], in: context)
        let row = try #require(HabitStore.entry(for: diet, on: today))
        #expect(row.effectiveCompletionState == .partial && row.source == .voice)

        guard case .skipped = engine.applyInbox(InboxAction(id: "g2", kind: .setGrade(.rest), habitName: "Test Diet", day: today), on: today, habits: [diet], in: context) else {
            Issue.record("Rest on a Diet habit should be skipped"); return
        }
        guard case .skipped = engine.applyInbox(InboxAction(id: "g3", kind: .setGrade(.auto), habitName: "Test Diet", day: yesterday), on: yesterday, habits: [diet], in: context) else {
            Issue.record("Back to auto before go-live should be skipped"); return
        }
        guard case .applied = engine.applyInbox(InboxAction(id: "g4", kind: .setGrade(.auto), habitName: "Test Diet", day: today), on: today, habits: [diet], in: context) else {
            Issue.record("Back to auto on the go-live day should apply"); return
        }
        #expect(HabitStore.entry(for: diet, on: today) == nil)
    }

    @Test func mergedDetailsAppendNotesAndSetBookAndPages() {
        let base = HabitStore.merged(nil, habitKind: .reading, text: nil, book: "Dune", pages: 12)
        #expect(base == .reading(bookTitle: "Dune", pagesRead: "12", notes: ""))
        let more = HabitStore.merged(base, habitKind: .reading, text: "slow start", book: nil, pages: 40)
        #expect(more == .reading(bookTitle: "Dune", pagesRead: "40", notes: "slow start"))
        let workout = HabitStore.merged(.workout(types: ["Run"], duration: "30 min", intensity: 4, notes: "a"), habitKind: .workout, text: "b", book: nil, pages: nil)
        #expect(workout == .workout(types: ["Run"], duration: "30 min", intensity: 4, notes: "a\nb"))
        #expect(HabitStore.merged(nil, habitKind: nil, text: nil, book: nil, pages: nil) == nil)
        #expect(HabitStore.merged(nil, habitKind: nil, text: "hi", book: nil, pages: nil) == .notes(notes: "hi"))
    }

    /// bt-0021 — chips light from dh's categories; a chip Dustin lit stays;
    /// the bt-0019 session names drop out of `types`; notes + intensity kept.
    @Test func autoWorkoutDetailsLightChipsAndKeepTheRowsNotes() {
        let today = Calendar.current.startOfDay(for: Date())
        let workout = Habit(name: "Workout", completionStyle: .multiState, detailKind: .workout)
        let facts = DayFacts(day: today, proteinGrams: nil, calories: nil, workoutMinutes: 89,
                             sessions: [.init(name: "Weighted incline walk", minutes: 66, category: "walking"),
                                        .init(name: "Workout B — Full Body", minutes: 23, category: "strength", setCount: 13)])
        let details = HabitSyncEngine.autoDetails(for: workout, facts: facts,
                                                  existing: .workout(types: ["Incline walk", "Core/Pre-Hab"], duration: "", intensity: 4, notes: "knee"))
        // bt-0022 — the bare number; the Journal adds " min" itself.
        #expect(details == .workout(types: ["Core/Pre-Hab", "Cardio", "Strength"], duration: "89", intensity: 4, notes: "knee"))
        #expect(HabitSyncEngine.autoDetails(for: workout, facts: DayFacts(day: today, proteinGrams: nil, calories: nil, workoutMinutes: 0), existing: nil) == nil)
        let diet = Habit(name: "Diet", completionStyle: .multiState)
        #expect(HabitSyncEngine.autoDetails(for: diet, facts: facts, existing: nil) == nil)
        #expect(WorkoutTypeChips.chip(forCategory: "basketball") == "Cardio")
        #expect(WorkoutTypeChips.chip(forCategory: "other") == "Other")
        #expect(WorkoutTypeChips.chip(forCategory: nil) == nil)
    }
}

// MARK: - dh's list on the row (bt-0021)

@MainActor
struct HealthSnapshotTests {
    private func makeContext() throws -> ModelContext {
        // No CloudKit on the test store: `.automatic` picks up the app's
        // iCloud entitlement, the mirroring setup fails without an account
        // on the simulator, and the first save then throws "No eligible
        // connection available" (seen on the iOS 27.1 runtime, bt-0021).
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    private var coffee: HealthSnapshot {
        HealthSnapshot(meals: [.init(id: "m1", name: "1.5 protein coffees", calories: 168, protein: 30, carbs: 0, fat: 0,
                                     at: HealthSnapshot.wholeSecond(Date()))])
    }

    /// The `health` key sits beside the details keys: a note write keeps it,
    /// a health write keeps the note, and a row with only `health` has no
    /// details (an old build reads it as empty notes).
    @Test func healthKeyRidesBesideTheDetails() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let entry = HabitEntry(date: today, completionState: .partial, details: .notes(notes: "hi"))
        entry.health = coffee
        #expect(entry.details == .notes(notes: "hi"))
        #expect(entry.health == coffee)
        entry.details = .notes(notes: "hi\nmore")
        #expect(entry.health == coffee)
        let json = try #require(entry.detailsJSON)
        #expect(json.contains("\"health\"") && json.contains("\"notes\""))
        entry.details = nil
        #expect(entry.details == nil && entry.health == coffee)

        let workout = HabitEntry(date: today, completionState: .success,
                                 details: .workout(types: ["Cardio"], duration: "89 min", intensity: 3, notes: ""))
        workout.health = HealthSnapshot(sessions: [.init(name: "Walk", category: "walking", minutes: 66, sets: 0, start: nil)])
        #expect(workout.details == .workout(types: ["Cardio"], duration: "89 min", intensity: 3, notes: ""))
        #expect(workout.health?.sessions.first?.name == "Walk")

        let bare = HabitEntry(date: today, completionState: .success)
        bare.health = coffee
        #expect(bare.details == nil && bare.health == coffee)
        bare.health = nil
        #expect(bare.detailsJSON == nil)
    }

    /// Dates arrive with fractional seconds; the stored copy must compare
    /// equal to a fresh one or every run would rewrite every row.
    @Test func snapshotFromFactsRoundTripsUnchanged() {
        let today = Calendar.current.startOfDay(for: Date())
        let logged = DustinHealthWire.timestamp(from: "2026-10-27T14:05:22.397+00:00")
        let facts = DayFacts(day: today, proteinGrams: 30, calories: 168, workoutMinutes: 89,
                             sessions: [.init(name: "Workout B — Full Body", minutes: 23, category: "strength", setCount: 13, startedAt: logged)],
                             meals: [.init(id: "m1", name: "1.5 protein coffees", calories: 168, protein: 30, carbs: nil, fat: nil, loggedAt: logged)])
        let diet = HabitSyncEngine.snapshot(kind: .diet, facts: facts)
        let workout = HabitSyncEngine.snapshot(kind: .workout, facts: facts, steps: 8_412)
        let entry = HabitEntry(date: today, completionState: .success)
        entry.health = diet
        #expect(entry.health == diet)
        #expect(entry.health?.meals.first?.carbs == nil)
        entry.health = workout
        #expect(entry.health == workout)
        #expect(entry.health?.sessions.first?.sets == 13)
        // bt-0022 — steps ride on the Workout block and survive the round trip;
        // a day with steps but no session still gets a block; the Diet block never carries steps.
        #expect(entry.health?.steps == 8_412)
        #expect(diet?.steps == nil)
        let stepsOnly = HabitSyncEngine.snapshot(kind: .workout, facts: DayFacts(day: today, proteinGrams: nil, calories: nil), steps: 3_000)
        #expect(stepsOnly == HealthSnapshot(sessions: [], steps: 3_000) && stepsOnly?.isEmpty == false)
        #expect(HabitSyncEngine.snapshot(kind: .diet, facts: DayFacts(day: today, proteinGrams: nil, calories: nil)) == nil)
        #expect(HabitSyncEngine.snapshot(kind: .workout, facts: nil) == nil)
        #expect(HabitSyncEngine.snapshot(kind: .workout, facts: nil, steps: 500)?.steps == 500)
        // A block stored before bt-0022 has no `steps` key and still decodes.
        let old = HabitEntry(date: today, completionState: .success)
        old.detailsJSON = #"{"health":{"meals":[],"sessions":[{"minutes":66,"name":"Walk","sets":0}]}}"#
        #expect(old.health?.steps == nil && old.health?.sessions.first?.activeKcal == nil && old.health?.totalMinutes == 66)
    }

    /// Dustin's test: a hand-set row keeps its source and edit time after a
    /// sync that changes its meals; the notes stay; the same facts twice
    /// write nothing.
    @Test func healthWriteLeavesHandRowsSourceAndEditTimeAlone() throws {
        let context = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let diet = Habit(name: "Diet", frequency: "daily", completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        context.insert(diet)
        try context.save()

        HabitStore.setCompletion(for: diet, on: today, state: 2, in: context)
        HabitStore.mergeDetails(for: diet, on: today, text: "ate out", book: nil, pages: nil, in: context)
        let row = try #require(HabitStore.entry(for: diet, on: today))
        let fixed = Date(timeIntervalSince1970: 1_790_000_000)
        row.editedAt = fixed
        try context.save()

        #expect(HabitStore.setHealth(for: diet, on: today, snapshot: coffee, in: context))
        #expect(row.source == .hand)
        #expect(row.editedAt == fixed)
        #expect(row.effectiveCompletionState == .partial)
        #expect(row.details == .notes(notes: "ate out"))
        #expect(row.health == coffee)

        // Same facts again → nothing written.
        #expect(!HabitStore.setHealth(for: diet, on: today, snapshot: coffee, in: context))

        // The meals change → written; everything else still as it was.
        var lunch = coffee
        lunch.meals.append(.init(id: "m2", name: "Chicken bowl", calories: 640, protein: 52, carbs: nil, fat: nil, at: nil))
        #expect(HabitStore.setHealth(for: diet, on: today, snapshot: lunch, in: context))
        #expect(row.health?.meals.count == 2)
        #expect(row.source == .hand && row.editedAt == fixed && row.details == .notes(notes: "ate out"))

        // No row → nothing; an empty snapshot → the key goes.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        #expect(!HabitStore.setHealth(for: diet, on: yesterday, snapshot: coffee, in: context))
        #expect(HabitStore.setHealth(for: diet, on: today, snapshot: HealthSnapshot(), in: context))
        #expect(row.health == nil && row.details == .notes(notes: "ate out"))
    }

    /// Only a hand / voice row WITH a grade overrides the grader; a
    /// details-only row doesn't, and shows as Auto.
    @Test func detailsOnlyRowsAreNotOverrides() {
        let today = Date()
        #expect(!HabitEntry(date: today, completionState: .notDone, source: .hand).isOverride)
        #expect(HabitEntry(date: today, completionState: .partial, source: .hand).isOverride)
        #expect(HabitEntry(date: today, completionState: .partial, source: .voice).isOverride)
        #expect(!HabitEntry(date: today, completionState: .success, source: .auto).isOverride)
        #expect(GradeWording.mode(.hand) == "Set by you" && GradeWording.mode(.auto) == "Auto")
    }

    @Test func sheetWordingAndBlankCheck() {
        #expect(HabitCompletionDetailView.mealNumbers(calories: 168, protein: 30) == "168 cal · 30 g")
        #expect(HabitCompletionDetailView.mealNumbers(calories: nil, protein: 30.4) == "— cal · 30 g")
        #expect(HabitCompletionDetailView.sessionNumbers(.init(name: "B", category: "strength", minutes: 23, sets: 13, start: nil)) == "23 min · 13 sets")
        #expect(HabitCompletionDetailView.sessionNumbers(.init(name: "W", category: "walking", minutes: 66, sets: 0, start: nil)) == "66 min")
        #expect(HabitCompletionDetailView.isBlank(.workout(types: [], duration: "", intensity: 3, notes: "")))
        #expect(!HabitCompletionDetailView.isBlank(.workout(types: ["Cardio"], duration: "", intensity: 3, notes: "")))
        #expect(HabitCompletionDetailView.isBlank(.notes(notes: "")) && !HabitCompletionDetailView.isBlank(.notes(notes: "x")))
    }
}

// MARK: - Backup round trip (bt-0022)

struct BackupRoundTripTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    /// A backup → restore keeps dh's `health` block beside the notes (it used
    /// to rebuild the string from the typed enum and drop it), and a row from
    /// a pre-fix backup — details keys only — still restores typed.
    @Test func backupKeepsTheHealthBlock() throws {
        let source = try makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let diet = Habit(name: "Diet", frequency: "daily", completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        source.insert(diet)
        let row = HabitEntry(date: today, completionState: .partial, details: .notes(notes: "ate out"), habit: diet, source: .hand)
        let coffee = HealthSnapshot(meals: [.init(id: "m1", name: "1.5 protein coffees", calories: 168, protein: 30, carbs: 2, fat: 1,
                                                 at: HealthSnapshot.wholeSecond(Date()))])
        row.health = coffee
        source.insert(row)
        // A pre-fix shape: the legacy details string with no `health` key.
        let legacy = HabitEntry(date: today, completionState: .success, habit: diet)
        legacy.detailsJSON = #"{"bookTitle":"Dune","pagesRead":"12","notes":""}"#
        source.insert(legacy)
        try source.save()

        let url = try #require(BackupManager.shared.createBackup(in: source))
        let target = try makeContext()
        #expect(BackupManager.shared.restoreFromURL(url, in: target))

        let restored = try target.fetch(FetchDescriptor<HabitEntry>())
        #expect(restored.count == 2)
        let withHealth = try #require(restored.first { $0.health != nil })
        #expect(withHealth.health == coffee)
        #expect(withHealth.details == .notes(notes: "ate out"))
        #expect(withHealth.effectiveCompletionState == .partial && withHealth.source == .hand)
        let typed = try #require(restored.first { $0.health == nil })
        #expect(typed.details == .reading(bookTitle: "Dune", pagesRead: "12", notes: ""))
    }
}

// MARK: - History rewrite (bt-0022)

@MainActor
struct HistoryMigrationTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    private let calendar = Calendar.current
    private func day(_ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: m, day: d))!)
    }

    /// Dustin's table, end to end: Poison keeps everything; Workout loses
    /// every row before Oct 27 (even July) and gets one Auto row per dh
    /// session day, graded minutes-then-steps, sessions + steps under
    /// `health`; every other habit loses its rows before Oct 27; notes and
    /// everything from Oct 27 on are untouched; no Diet row is written
    /// before Oct 27 even though the same facts carry meals.
    @Test func rewriteKeepsPoisonRebuildsWorkoutFromSessionsAndWipesTheRest() throws {
        let context = try makeContext()
        let dates = HistoryMigration.Dates.standard(calendar: calendar)
        UserDefaults.standard.removeObject(forKey: HistoryMigration.doneKey)
        defer { UserDefaults.standard.removeObject(forKey: HistoryMigration.doneKey) }

        // Poison is a simple habit (dh: kind = simple), not avoidance — bt-0024 corrected the fixture.
        let poison = Habit(name: "Poison", order: 0, completionStyle: .simple)
        let weed = Habit(name: "Weed", order: 1, completionStyle: .avoidance)
        let diet = Habit(name: "Diet", order: 2, completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = dates.cutoff
        let workout = Habit(name: "Workout", order: 3, completionStyle: .multiState, detailKind: .workout)
        workout.gradingKind = .workout
        workout.gradingSince = dates.cutoff
        workout.targetWorkoutMinutes = 30
        workout.targetSteps = 10_000
        let sauna = Habit(name: "Sauna", order: 4, completionStyle: .simple)
        let all = [poison, weed, diet, workout, sauna]
        for h in all { context.insert(h) }
        // Three hand rows before the cutoff (one in July), two from the cutoff on, for every habit.
        for h in all {
            for d in [day(7, 15), day(8, 5), day(10, 26), day(10, 27), day(10, 28)] {
                context.insert(HabitEntry(date: d, completionState: .success, habit: h, source: .hand, editedAt: Date()))
            }
        }
        context.insert(Note(date: day(8, 5), content: "old note"))
        context.insert(Note(date: day(10, 27), content: "new note"))
        try context.save()

        // dh's answer: a 45-min day (Done), a 10-min day with 12,000 steps
        // (Partial), a 20-min day with 2,000 steps (Tried), a meal-only day
        // (no Workout row), and a session before Aug 1 that is out of the span.
        let meal = DayFacts.Meal(id: "m", name: "Bowl", calories: 700, protein: 50, carbs: 60, fat: 20)
        func facts(_ d: Date, minutes: Double, sessions: [DayFacts.Session]) -> DayFacts {
            DayFacts(day: d, proteinGrams: 50, calories: 700, workoutMinutes: minutes, mealNames: ["Bowl"], sessions: sessions, meals: [meal])
        }
        let history = HistoryMigration.History(
            facts: [
                day(8, 5): facts(day(8, 5), minutes: 45, sessions: [.init(name: "Incline walk", minutes: 45, category: "walking", activeKcal: 300, activityType: "Indoor Walk")]),
                day(9, 1): facts(day(9, 1), minutes: 10, sessions: [.init(name: "Core", minutes: 10, category: "strength")]),
                day(9, 2): facts(day(9, 2), minutes: 20, sessions: [.init(name: "Walk", minutes: 12, category: "walking"), .init(name: "Stretch", minutes: 8, category: "flexibility")]),
                day(10, 1): facts(day(10, 1), minutes: 0, sessions: []),
                day(7, 20): facts(day(7, 20), minutes: 60, sessions: [.init(name: "Run", minutes: 60, category: "cardio")]),
            ],
            steps: [day(8, 5): 4_000, day(9, 1): 12_000, day(9, 2): 2_000],
            stepsAvailable: true)

        // The plan first — the counts the screen shows.
        let plan = HistoryMigration.plan(habits: all, history: history, dates: dates, in: context)
        #expect(plan.lines.map(\.name) == ["Poison", "Weed", "Diet", "Workout", "Sauna"])
        #expect(plan.lines.map(\.rowsBefore) == [3, 3, 3, 3, 3])
        #expect(plan.lines[0].action == .kept)
        #expect(plan.lines[1].action == .deleted && plan.lines[2].action == .deleted && plan.lines[4].action == .deleted)
        #expect(plan.lines[3].action == .rebuilt(.init(sessions: 4, days: 3, done: 1, partial: 1, tried: 1)))
        #expect(plan.notesBefore == 1 && plan.deletedRows == 12 && plan.keptRows == 3 && !plan.workoutMissing)
        #expect(!HistoryMigration.isDone)
        // The plan is a preview: nothing pending in the store, same row counts
        // on a second look. (Found on the simulator: building entries with
        // `habit:` inside the plan auto-inserted 87 rows into the live context.)
        #expect(!context.hasChanges)
        #expect(HistoryMigration.rowsBefore(cutoff: dates.cutoff, habitID: workout.id!, in: context).count == 3)
        #expect(HistoryMigration.plan(habits: all, history: history, dates: dates, in: context) == plan)

        try HistoryMigration.perform(habits: all, history: history, dates: dates, in: context)
        #expect(HistoryMigration.isDone)

        func rows(_ h: Habit) -> [HabitEntry] {
            (try? context.fetch(FetchDescriptor<HabitEntry>()))?.filter { $0.habit?.id == h.id }.sorted { $0.date < $1.date } ?? []
        }
        // Poison: all five. Weed / Diet / Sauna: only the two from the cutoff on.
        #expect(rows(poison).count == 5)
        for h in [weed, diet, sauna] {
            #expect(rows(h).map(\.date) == [day(10, 27), day(10, 28)])
            #expect(rows(h).allSatisfy { $0.source == .hand })
        }
        // No Diet row before the cutoff although every facts day carried a meal.
        #expect(rows(diet).allSatisfy { $0.date >= dates.cutoff })

        // Workout: July and the hand rows gone; three Auto rows on the session days; Oct 27/28 untouched.
        let w = rows(workout)
        #expect(w.map(\.date) == [day(8, 5), day(9, 1), day(9, 2), day(10, 27), day(10, 28)])
        #expect(w[0].effectiveCompletionState == .success && w[1].effectiveCompletionState == .partial && w[2].effectiveCompletionState == .failure)
        #expect(w[0...2].allSatisfy { $0.source == .auto })
        #expect(w[3].source == .hand && w[4].source == .hand)
        let first = try #require(w[0].health)
        #expect(first.sessions.map(\.name) == ["Incline walk"] && first.meals.isEmpty && first.steps == 4_000)
        #expect(first.sessions.first?.activeKcal == 300 && first.sessions.first?.activityType == "Indoor Walk")
        #expect(w[2].health?.sessions.count == 2 && w[2].health?.steps == 2_000)
        if case .workout(let types, let duration, _, _)? = w[0].details {
            #expect(types.contains("Cardio") && duration == "45")
        } else {
            Issue.record("the rebuilt row should carry workout details")
        }
        // Notes untouched.
        #expect(((try? context.fetch(FetchDescriptor<Note>())) ?? []).count == 2)
    }

    /// Without a Workout habit nothing is rebuilt and the plan says so; a
    /// Diet-only store still wipes before the cutoff and keeps the rest.
    @Test func planWithoutAWorkoutHabitOnlyDeletes() throws {
        let context = try makeContext()
        let dates = HistoryMigration.Dates.standard(calendar: calendar)
        let diet = Habit(name: "Diet", order: 0, completionStyle: .multiState)
        context.insert(diet)
        context.insert(HabitEntry(date: day(9, 9), completionState: .partial, habit: diet))
        try context.save()
        let history = HistoryMigration.History(facts: [day(9, 9): DayFacts(day: day(9, 9), proteinGrams: 1, calories: 1,
                                                                             sessions: [.init(name: "Run", minutes: 50)])],
                                               steps: [:], stepsAvailable: false)
        let plan = HistoryMigration.plan(habits: [diet], history: history, dates: dates, in: context)
        #expect(plan.workoutMissing && plan.rebuilt == nil && plan.deletedRows == 1)
        #expect(HistoryMigration.isKeptWhole(Habit(name: " POISON ")) && !HistoryMigration.isKeptWhole(diet))
    }
}

// MARK: - Cleanup survivor order (bt-0018)

struct DedupeKeyTests {
    @Test func handBeatsAutoThenNewestThenSmallestId() {
        let now = Date()
        let earlier = now.addingTimeInterval(-600)
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

        let handOld = HabitEntry(id: b, date: now, completionState: .failure, source: .hand, editedAt: earlier)
        let autoNew = HabitEntry(id: a, date: now, completionState: .success, source: .auto, editedAt: now)
        // Override wins even though the auto row is newer and has the smaller id.
        #expect(HabitStore.dedupeKey(handOld) < HabitStore.dedupeKey(autoNew))

        let autoOld = HabitEntry(id: a, date: now, completionState: .partial, source: .auto, editedAt: earlier)
        // Same source: newest edit first.
        #expect(HabitStore.dedupeKey(autoNew) < HabitStore.dedupeKey(autoOld))

        let legacyA = HabitEntry(id: a, date: now, completionState: .success)
        let legacyB = HabitEntry(id: b, date: now, completionState: .success)
        // No source, no edit time (pre-bt-0018 rows): smallest id, as in Step 0.
        #expect(HabitStore.dedupeKey(legacyA) < HabitStore.dedupeKey(legacyB))
        // And a legacy (hand) row still beats an auto row.
        #expect(HabitStore.dedupeKey(legacyB) < HabitStore.dedupeKey(autoNew))
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

// MARK: - Quiet sync after a tap (bt-0020)

/// Counts `sync()` calls and keeps the last payload; every other call is
/// empty. The engine is main-actor, so the counters are only touched there.
final class CountingSource: HabitFactsSource, @unchecked Sendable {
    let displayName = "Counting"
    let isLive = false
    private(set) var syncCalls = 0
    private(set) var lastPayload: HabitSyncPayload?

    func sync(_ payload: HabitSyncPayload) async throws -> HabitSyncReply {
        syncCalls += 1
        lastPayload = payload
        return HabitSyncReply(heldTargets: [], targets: payload.targets)
    }
    func changedDays(since: String?) async throws -> ChangedDays { ChangedDays(days: [], nextSince: "counting") }
    func facts(from: Date, to: Date) async throws -> [Date: DayFacts] { [:] }
    func pendingActions() async throws -> [InboxAction] { [] }
    func confirmApplied(_ ids: [String]) async throws -> AckResult { AckResult(applied: ids.count, notApplied: []) }
}

/// Serialized: these share `HabitSyncEngine.shared`'s test override and
/// delay. Taps from any other suite's context are ignored while an
/// override is set, so the counts here are exact.
@Suite(.serialized) @MainActor
struct QuietSyncTests {
    private let today = Calendar.current.startOfDay(for: Date())

    private struct Rig {
        let context: ModelContext
        let pills: Habit
        let source: CountingSource
    }

    private func makeRig() async throws -> Rig {
        // The test host is the real app: its on-open sync (steps only on the
        // simulator, and the Health permission request can take its full
        // 10 s) may still be running. One run at a time, so wait it out.
        var waited = 0
        while HabitSyncEngine.shared.isRunning && waited < 400 {
            try await Task.sleep(for: .milliseconds(50))
            waited += 1
        }
        #expect(!HabitSyncEngine.shared.isRunning, "the host app's own sync never finished")

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        let context = ModelContext(container)
        let pills = Habit(name: "Pills", order: 0, completionStyle: .simple)
        context.insert(pills)
        try context.save()
        let source = CountingSource()
        HabitSyncEngine.quietSyncDelay = .milliseconds(300)
        HabitSyncEngine.shared.testOverride = .init(source: source, context: context)
        return Rig(context: context, pills: pills, source: source)
    }

    private func tearDown() {
        HabitSyncEngine.shared.testOverride = nil
        HabitSyncEngine.quietSyncDelay = .seconds(3)
    }

    /// Lets the store's main-actor hand-off to the engine run.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(30))
    }

    @Test func fiveQuickTapsMakeOneSend() async throws {
        let rig = try await makeRig()
        defer { tearDown() }

        // on / off / on / off / on — ends ticked.
        for state in [1, 0, 1, 0, 1] {
            HabitStore.setCompletion(for: rig.pills, on: today, state: state, in: rig.context)
        }
        try await Task.sleep(for: .seconds(1))

        #expect(rig.source.syncCalls == 1)
        #expect(rig.source.lastPayload?.tickedToday == ["Pills"])
        #expect(HabitSyncEngine.shared.lastReport?.reason == .afterTap)
    }

    @Test func autoVoiceAndPastDayWritesSendNothing() async throws {
        let rig = try await makeRig()
        defer { tearDown() }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        HabitStore.setCompletion(for: rig.pills, on: today, state: 1, source: .auto, in: rig.context)
        HabitStore.setCompletion(for: rig.pills, on: today, state: 1, source: .voice, in: rig.context)
        HabitStore.removeEntry(for: rig.pills, on: today, source: .auto, in: rig.context)
        HabitStore.setCompletion(for: rig.pills, on: yesterday, state: 1, in: rig.context)
        try await Task.sleep(for: .milliseconds(700))

        #expect(rig.source.syncCalls == 0)
    }

    @Test func aStartingRunDropsTheWaitingOne() async throws {
        let rig = try await makeRig()
        defer { tearDown() }

        HabitStore.setCompletion(for: rig.pills, on: today, state: 1, in: rig.context)
        try await settle()
        // Pull-down (or open, Save, Back to Auto) right after the tap.
        await HabitSyncEngine.shared.refresh(in: rig.context, force: true)

        #expect(rig.source.syncCalls == 1)
        #expect(rig.source.lastPayload?.tickedToday == ["Pills"])
        try await Task.sleep(for: .milliseconds(700))
        #expect(rig.source.syncCalls == 1, "the waiting quiet sync must not run as a second send")
    }

    /// Review finding (2026-10-28): the store's hand-off to the engine is a
    /// queued main-actor task, so a hand write followed at once by a forced
    /// run armed the timer AFTER the run had started and made Back to Auto
    /// two runs. No settle() here on purpose — that ordering is the test.
    @Test func backToAutoIsOneRun() async throws {
        let rig = try await makeRig()
        defer { tearDown() }
        let diet = Habit(name: "Diet", order: 1, completionStyle: .multiState)
        diet.gradingKind = .diet
        diet.gradingSince = today
        rig.context.insert(diet)
        try rig.context.save()
        // An override row to drop (voice, so creating it arms nothing).
        HabitStore.setCompletion(for: diet, on: today, state: 2, source: .voice, in: rig.context)
        try await settle()
        #expect(rig.source.syncCalls == 0)

        await HabitSyncEngine.shared.revertToAutomatic(habit: diet, day: today, in: rig.context)

        #expect(rig.source.syncCalls == 1)
        #expect(HabitSyncEngine.shared.lastReport?.reason == .backToAuto)
        #expect(HabitStore.entry(for: diet, on: today) == nil)
        try await Task.sleep(for: .milliseconds(700))   // past the 300 ms timer
        #expect(rig.source.syncCalls == 1, "Back to Auto must not be followed by a quiet sync")
    }

    @Test func quietSyncDecisionTable() {
        typealias E = HabitSyncEngine
        #expect(E.shouldQuietSync(isPhone: true, hasKey: true, source: .hand, isToday: true))
        #expect(!E.shouldQuietSync(isPhone: false, hasKey: true, source: .hand, isToday: true), "iPad")
        #expect(!E.shouldQuietSync(isPhone: true, hasKey: false, source: .hand, isToday: true), "no key")
        #expect(!E.shouldQuietSync(isPhone: true, hasKey: true, source: .auto, isToday: true), "grader")
        #expect(!E.shouldQuietSync(isPhone: true, hasKey: true, source: .voice, isToday: true), "voice")
        #expect(!E.shouldQuietSync(isPhone: true, hasKey: true, source: .hand, isToday: false), "yesterday")
    }

    @Test func leavingTheAppSendsTheWaitingTapNow() async throws {
        let rig = try await makeRig()
        defer { tearDown() }

        // Nothing waiting → leaving does nothing.
        HabitSyncEngine.shared.appLeftForeground()
        try await settle()
        #expect(rig.source.syncCalls == 0)

        HabitStore.setCompletion(for: rig.pills, on: today, state: 1, in: rig.context)
        try await settle()
        HabitSyncEngine.shared.appLeftForeground()
        try await Task.sleep(for: .milliseconds(100))   // well inside the 300 ms the timer would have waited

        #expect(rig.source.syncCalls == 1)
        #expect(HabitSyncEngine.shared.lastReport?.reason == .leavingApp)
        try await Task.sleep(for: .milliseconds(500))
        #expect(rig.source.syncCalls == 1, "the dropped timer must not send again")
    }

    @Test func aWaitingTapBeatsTheThrottle() {
        typealias E = HabitSyncEngine
        let now = Date()
        let sent = now.addingTimeInterval(-60)          // a run started a minute ago and sent fine
        let attempt = now.addingTimeInterval(-30)       // inside the 120 s throttle

        #expect(E.decideOnOpen(lastAttempt: attempt, now: now, tapWaitingSince: nil, widgetStamp: nil, lastSentAt: sent) == .skip)
        #expect(E.decideOnOpen(lastAttempt: attempt, now: now, tapWaitingSince: sent.addingTimeInterval(-5), widgetStamp: nil, lastSentAt: sent) == .skip, "a tap already sent")
        #expect(E.decideOnOpen(lastAttempt: attempt, now: now, tapWaitingSince: now.addingTimeInterval(-10), widgetStamp: nil, lastSentAt: sent) == .runTapWaiting)
        #expect(E.decideOnOpen(lastAttempt: attempt, now: now, tapWaitingSince: nil, widgetStamp: now.addingTimeInterval(-10), lastSentAt: sent) == .runTapWaiting, "widget tap")
        // A tap that landed after the last run STARTED but before it finished is still waiting.
        #expect(E.decideOnOpen(lastAttempt: attempt, now: now, tapWaitingSince: sent.addingTimeInterval(1), widgetStamp: nil, lastSentAt: sent) == .runTapWaiting)
        #expect(E.decideOnOpen(lastAttempt: now.addingTimeInterval(-300), now: now, tapWaitingSince: nil, widgetStamp: nil, lastSentAt: sent) == .run, "throttle over")
        #expect(E.decideOnOpen(lastAttempt: nil, now: now, tapWaitingSince: nil, widgetStamp: nil, lastSentAt: nil) == .run, "first open")
    }
}

// MARK: - Dashboard (bt-0023)

@MainActor
struct DashboardTests {
    private let calendar = Calendar.current

    private func day(_ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: m, day: d))!)
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Habit.self, HabitEntry.self, Note.self, configurations: config)
        return ModelContext(container)
    }

    /// The line under the eaten total, for each side of the band.
    @Test func calorieBandTextCoversUnderInRangeAndOver() {
        #expect(DashboardDay.calorieBandText(calories: 1_840, floor: 1_900, ceiling: 2_200) == "60 to 1,900 · 360 under 2,200")
        #expect(DashboardDay.calorieBandText(calories: 2_040, floor: 1_900, ceiling: 2_200) == "In range · 160 under 2,200")
        #expect(DashboardDay.calorieBandText(calories: 2_340, floor: 1_900, ceiling: 2_200) == "140 over 2,200")
        #expect(DashboardDay.calorieBandText(calories: nil, floor: 1_900, ceiling: 2_200) == "—")
        #expect(DashboardDay.bandPosition(calories: 1_900, floor: 1_900, ceiling: 2_200) == .inRange)
        #expect(DashboardDay.bandPosition(calories: nil, floor: 1_900, ceiling: 2_200) == .none)
    }

    /// Dustin's rule: the daily burn is Apple Health's total only. The
    /// sessions' active calories are shown per session and never added in —
    /// a block with sessions but no Health reading has no burn at all.
    @Test func burnedIsHealthsTotalAndNeverTheSessions() {
        var block = HealthSnapshot(sessions: [.init(name: "Treadmill walk", category: "walking", minutes: 38, sets: 0, start: nil, activeKcal: 212)],
                                   steps: 8_412, activeBurnKcal: 1_030, restingBurnKcal: 2_159)
        #expect(block.totalBurnKcal == 3_189)              // Dustin's Fitness check for Oct 27
        #expect(block.totalActiveKcal == 212)              // the sessions, kept apart
        #expect(DashboardDay.burnedDetailText(active: 1_030, resting: 2_159) == "1,030 active + 2,159 resting")
        block.activeBurnKcal = nil
        block.restingBurnKcal = nil
        #expect(block.totalBurnKcal == nil, "no Health reading → a dash, never the session sum")
        #expect(DashboardDay.wholeOrDash(block.totalBurnKcal) == "—")
        #expect(DashboardDay.burnedDetailText(active: nil, resting: nil) == nil)
        #expect(HealthBurn(activeKcal: 1_030, restingKcal: nil).totalKcal == 1_030)
        #expect(HealthBurn(activeKcal: nil, restingKcal: nil).totalKcal == nil && HealthBurn(activeKcal: nil, restingKcal: nil).isEmpty)
    }

    /// The engine's snapshot carries the burn beside the steps; a block
    /// stored before bt-0023 has no burn keys and still decodes.
    @Test func snapshotCarriesBurnAndOldBlocksDecode() throws {
        let today = calendar.startOfDay(for: Date())
        let burn = HealthBurn(activeKcal: 1_030, restingKcal: 2_159)
        let burnOnly = try #require(HabitSyncEngine.snapshot(kind: .workout, facts: nil, steps: nil, burn: burn))
        #expect(burnOnly.sessions.isEmpty && burnOnly.steps == nil && burnOnly.totalBurnKcal == 3_189 && !burnOnly.isEmpty)
        #expect(HabitSyncEngine.snapshot(kind: .workout, facts: nil, steps: nil, burn: HealthBurn(activeKcal: nil, restingKcal: nil)) == nil)
        let entry = HabitEntry(date: today, completionState: .success)
        entry.health = burnOnly
        #expect(entry.health == burnOnly, "round-trips through the JSON string unchanged")
        // Diet blocks never carry a burn.
        let facts = DayFacts(day: today, proteinGrams: 30, calories: 168, meals: [.init(id: "m", name: "Coffee", calories: 168, protein: 30)])
        #expect(HabitSyncEngine.snapshot(kind: .diet, facts: facts, burn: burn)?.totalBurnKcal == nil)
        let old = HabitEntry(date: today, completionState: .success)
        old.detailsJSON = #"{"health":{"meals":[],"sessions":[{"minutes":66,"name":"Walk","sets":0}],"steps":4000}}"#
        #expect(old.health?.steps == 4_000 && old.health?.totalBurnKcal == nil && old.health?.activeBurnKcal == nil)
    }

    /// Sessions adding up to more than Health's Active Energy is said on
    /// screen with both numbers; equal, under or unknown is nothing.
    @Test func sessionsOverHealthActiveIsFlaggedNeverSilently() {
        #expect(DashboardDay.sessionsExceedHealth(sessionsKcal: 612, healthActiveKcal: 480))
        #expect(DashboardDay.warningText(sessionsKcal: 612, healthActiveKcal: 480)
                == "Sessions add up to 612 active cal; Apple Health counted 480 for the day")
        #expect(DashboardDay.warningText(sessionsKcal: 480, healthActiveKcal: 480) == nil)
        #expect(DashboardDay.warningText(sessionsKcal: 212, healthActiveKcal: 1_030) == nil)
        #expect(DashboardDay.warningText(sessionsKcal: nil, healthActiveKcal: 1_030) == nil, "unknown sessions")
        #expect(DashboardDay.warningText(sessionsKcal: 612, healthActiveKcal: nil) == nil, "no Health reading")
    }

    /// The website's driver rule: carbs or fat over its ceiling, the one
    /// further over by ratio, the meal with the most of that macro.
    @Test func driverLineIsTheWebsitesRule() {
        let eggs = HealthSnapshot.Meal(id: "1", name: "Eggs & toast", calories: 420, protein: 28, carbs: 30, fat: 22)
        let bowl = HealthSnapshot.Meal(id: "2", name: "Burrito bowl", calories: 760, protein: 52, carbs: 74, fat: 18)
        let snack = HealthSnapshot.Meal(id: "3", name: "Trail mix", calories: 300, protein: 8, carbs: 87, fat: 18)
        let carbsOver = DashboardDay.driver(meals: [eggs, bowl, snack], carbsCeiling: 180, fatCeiling: 65)
        #expect(carbsOver?.macro == .carbs && carbsOver?.mealName == "Trail mix")
        #expect(carbsOver?.text == "Trail mix — 87 g of your 191 g carbs")
        // Fat 58 of 65 and carbs 191 of 180 → carbs; fat 80 of 65 (1.23) beats carbs 191 of 180 (1.06).
        let fatty = HealthSnapshot.Meal(id: "4", name: "Ribeye", calories: 900, protein: 60, carbs: 0, fat: 80)
        let fatOver = DashboardDay.driver(meals: [eggs, fatty], carbsCeiling: 180, fatCeiling: 65)
        #expect(fatOver?.macro == .fat && fatOver?.mealName == "Ribeye" && fatOver?.mealGrams == 80 && fatOver?.dayGrams == 102)
        #expect(DashboardDay.driver(meals: [eggs, bowl], carbsCeiling: 180, fatCeiling: 65) == nil, "neither over → no line")
        #expect(DashboardDay.driver(meals: [], carbsCeiling: 180, fatCeiling: 65) == nil)
    }

    @Test func modeLineUsesTheTodayRowsWording() {
        #expect(DashboardDay.modeLine(source: .auto, state: nil, isToday: true) == "Auto · in progress")
        #expect(DashboardDay.modeLine(source: .auto, state: nil, isToday: false) == "Auto · no grade")
        #expect(DashboardDay.modeLine(source: .hand, state: .partial, isToday: true) == "Set by you · Partial")
        #expect(DashboardDay.modeLine(source: .voice, state: .rest, isToday: false) == "Set by voice · Rest")
        #expect(DashboardDay.modeLine(source: nil, state: .success, isToday: false) == "Auto · Done")
    }

    /// The week bar: positive habits scored and won by the win rule, Rest
    /// days not scored, a slip a mark on the day and never a point lost.
    @Test func dayWinsCountPositiveHabitsAndMarkSlips() throws {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let sauna = Habit(name: "Sauna", completionStyle: .simple)
        let workout = Habit(name: "Workout", completionStyle: .multiState)
        let weed = Habit(name: "Weed", completionStyle: .avoidance)
        let entries: [UUID: [Date: HabitEntry]] = [
            sauna.id!: [yesterday: HabitEntry(date: yesterday, completionState: .success)],
            workout.id!: [yesterday: HabitEntry(date: yesterday, completionState: .failure),
                          today: HabitEntry(date: today, completionState: .rest)],
            weed.id!: [yesterday: HabitEntry(date: yesterday, completionState: .failure)],
        ]
        let wins = DashboardTrends.dayWins(habits: [sauna, workout, weed], entries: entries, days: [yesterday, today], today: today)
        #expect(wins.count == 2)
        #expect(wins[0] == .init(day: yesterday, wins: 1, scheduled: 2, slips: 1), "Tried is a miss, the slip is a mark")
        #expect(wins[1] == .init(day: today, wins: 0, scheduled: 1, slips: 0), "Rest drops Workout out of the day's count")
        #expect(DashboardTrends.scheduledCeiling(wins) == 2)
        #expect(DashboardTrends.averageWins(wins) == 0.5)
        #expect(DashboardTrends.averageWins([]) == nil)
        #expect(DashboardTrends.averageText(current: 5.125, ceiling: 8) == "5.1 of 8 a day")
        #expect(DashboardTrends.averageText(current: nil, ceiling: 0) == "Nothing scheduled")
        #expect(DashboardTrends.trend(current: 5.1, previous: 4.4) == .up)
        #expect(DashboardTrends.trend(current: 4.43, previous: 4.47) == .flat)
        #expect(DashboardTrends.trend(current: 3, previous: 5) == .down)
        #expect(DashboardTrends.trend(current: nil, previous: 4.4) == .flat)
    }

    /// Protein / calories from the Diet rows, minutes / steps / burned from
    /// the Workout rows; a day with no row is no reading, not 0.
    @Test func nutritionAndTrainingSeriesComeFromStoredRows() {
        let d1 = day(10, 27), d2 = day(10, 28), d3 = day(10, 29)
        let diet1 = HabitEntry(date: d1, completionState: .success)
        diet1.health = HealthSnapshot(meals: [.init(id: "a", name: "A", calories: 2_000, protein: 180),
                                              .init(id: "b", name: "B", calories: 100, protein: 10)])
        let diet2 = HabitEntry(date: d2, completionState: .partial)
        diet2.health = HealthSnapshot(meals: [.init(id: "c", name: "C", calories: 1_500, protein: 150)])
        let targets = GradingTargets.defaults
        let nutrition = DashboardTrends.nutritionSeries(dietRows: [d1: diet1, d2: diet2], days: [d1, d2, d3], targets: targets)
        #expect(nutrition.protein.points.map(\.value) == [190, 150, nil])
        #expect(nutrition.protein.summaryText == "avg 170 g of 180")
        #expect(nutrition.calories.points.map(\.value) == [2_100, 1_500, nil])
        #expect(nutrition.calories.summaryText == "avg 1,800 · 1 of 3 in band")

        let w1 = HabitEntry(date: d1, completionState: .success)
        w1.health = HealthSnapshot(sessions: [.init(name: "Walk", category: "walking", minutes: 38, sets: 0, start: nil, activeKcal: 212)],
                                   steps: 8_412, activeBurnKcal: 1_030, restingBurnKcal: 2_159)
        let training = DashboardTrends.trainingSeries(workoutRows: [d1: w1], days: [d1, d2], targets: targets)
        #expect(training.minutes.points.map(\.value) == [38, nil] && training.minutes.summaryText == "avg 38 of 30")
        #expect(training.steps.points.map(\.value) == [8_412, nil] && training.steps.summaryText == "avg 8,412 of 10,000")
        #expect(training.burned.points.map(\.value) == [3_189, nil] && training.burned.summaryText == "avg 3,189")
        #expect(!DashboardTrends.trainingSeries(workoutRows: [:], days: [d1], targets: targets).burned.hasData)
        #expect(DashboardPeriod.week.days(ending: d3).first == day(10, 23) && DashboardPeriod.month.days == 30)
    }

    /// While today is still open the streak counts from yesterday; a Tried
    /// today still breaks it; the walk never goes back past the floor.
    @Test func openTodayStreakStartsFromYesterdayAndStopsAtTheFloor() {
        let service = HabitCalculationService.shared
        let today = calendar.startOfDay(for: Date())
        func ago(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today)! }
        let habit = Habit(name: "Sauna", frequency: "daily", completionStyle: .simple)
        var entries: [Date: HabitEntry] = [:]
        for n in 1...6 { entries[ago(n)] = HabitEntry(date: ago(n), completionState: .success) }
        #expect(service.calculateCurrentStreak(for: habit, using: entries) == 0, "the old walk breaks on an open today")
        #expect(service.calculateCurrentStreak(for: habit, using: entries, allowingOpenToday: true) == 6)
        #expect(service.calculateCurrentStreak(for: habit, using: entries, allowingOpenToday: true, floor: ago(3)) == 3)
        entries[today] = HabitEntry(date: today, completionState: .success)
        #expect(service.calculateCurrentStreak(for: habit, using: entries, allowingOpenToday: true) == 7)
        let tried = Habit(name: "Workout", frequency: "daily", completionStyle: .multiState)
        var triedEntries = entries
        triedEntries[today] = HabitEntry(date: today, completionState: .failure)
        #expect(service.calculateCurrentStreak(for: tried, using: triedEntries, allowingOpenToday: true) == 0, "Tried today is a real break")
    }

    /// The detail heatmap through the win rule: a win is full colour, Rest a
    /// light tint, Tried and empty days grey; an avoidance habit's slips are
    /// the only coloured cells.
    @Test func detailHeatmapGoesThroughTheWinRule() {
        let d = [day(10, 27), day(10, 28), day(10, 29), day(10, 30)]
        let workout = Habit(name: "Workout", completionStyle: .multiState)
        let entries: [Date: HabitEntry] = [
            d[0]: HabitEntry(date: d[0], completionState: .success),
            d[1]: HabitEntry(date: d[1], completionState: .failure),
            d[2]: HabitEntry(date: d[2], completionState: .rest),
        ]
        let map = HabitDetailViewModel.heatmap(for: workout, entries: entries, dates: d, today: d[3])
        #expect(map[d[0]] == 1.0 && map[d[1]] == 0.0 && map[d[2]] == 0.4 && map[d[3]] == 0.0)
        let weed = Habit(name: "Weed", completionStyle: .avoidance)
        let slips: [Date: HabitEntry] = [d[1]: HabitEntry(date: d[1], completionState: .failure)]
        let slipMap = HabitDetailViewModel.heatmap(for: weed, entries: slips, dates: d, today: d[3])
        #expect(slipMap[d[0]] == 0.0 && slipMap[d[1]] == 1.0 && slipMap[d[2]] == 0.0)
    }

    /// The clean start: Poison keeps its own start, Workout goes back to the
    /// Aug 1 import, everything else starts at the Oct 27 cutoff — and the
    /// range control never starts before it ("0 of 84 days" is gone).
    @Test func detailRangeClampsToTheCleanStart() {
        let dates = HistoryMigration.Dates.standard(calendar: calendar)
        let poison = Habit(name: "Poison", startDate: day(4, 1), completionStyle: .simple)
        let weed = Habit(name: "Weed", startDate: day(4, 1), completionStyle: .avoidance)
        let workout = Habit(name: "Workout", startDate: day(4, 1), completionStyle: .multiState)
        workout.gradingKind = .workout
        workout.gradingSince = dates.cutoff
        let newer = Habit(name: "Sauna", startDate: day(11, 2), completionStyle: .simple)
        #expect(HistoryMigration.cleanStart(for: poison, dates: dates, calendar: calendar) == day(4, 1))
        #expect(HistoryMigration.cleanStart(for: weed, dates: dates, calendar: calendar) == day(10, 27))
        #expect(HistoryMigration.cleanStart(for: workout, dates: dates, calendar: calendar) == day(8, 1))
        #expect(HistoryMigration.cleanStart(for: newer, dates: dates, calendar: calendar) == day(11, 2), "a habit made after the cutoff starts when it started")

        let today = day(10, 28)
        #expect(HabitDetailRange.twelveWeeks.start(today: today, cleanStart: day(10, 27), calendar: calendar) == day(10, 27))
        #expect(HabitDetailRange.fourWeeks.start(today: today, cleanStart: day(4, 1), calendar: calendar) == day(10, 1))
        #expect(HabitDetailRange.twelveWeeks.start(today: today, cleanStart: day(4, 1), calendar: calendar) == day(8, 6))
        #expect(HabitDetailRange.all.start(today: today, cleanStart: day(4, 1), calendar: calendar) == day(4, 1))
    }

    /// The one-time refresh: dh's corrected session calories land on the
    /// stored rows, the day's steps and burn from Health come along, a day
    /// dh no longer reports keeps its sessions, nothing but the `health`
    /// block moves, and the biggest correction is found for the screen.
    @Test func refetchRewritesSessionsAddsBurnAndKeepsEverythingElse() throws {
        let context = try makeContext()
        UserDefaults.standard.removeObject(forKey: HealthRefetch.doneKey)
        defer { UserDefaults.standard.removeObject(forKey: HealthRefetch.doneKey) }
        let dates = HealthRefetch.Dates(start: day(8, 1), end: day(10, 28))
        let workout = Habit(name: "Workout", completionStyle: .multiState, detailKind: .workout)
        workout.gradingKind = .workout
        workout.gradingSince = day(10, 27)
        context.insert(workout)

        // Aug 24: the double-counted walk. Oct 20: a session with no calories.
        // Oct 27: a hand-set day dh no longer reports. Oct 10: no row at all.
        let fixed = Date(timeIntervalSince1970: 1_790_000_000)
        let aug24 = HabitEntry(date: day(8, 24), completionState: .success, habit: workout, source: .auto, editedAt: fixed)
        aug24.health = HealthSnapshot(sessions: [.init(name: "Walk", category: "walking", minutes: 60, sets: 0, start: nil, activeKcal: 1_189.8)], steps: 9_000)
        let oct20 = HabitEntry(date: day(10, 20), completionState: .success, habit: workout, source: .auto, editedAt: fixed)
        oct20.health = HealthSnapshot(sessions: [.init(name: "Lift", category: "strength", minutes: 40, sets: 12, start: nil, activeKcal: nil)], steps: 5_000)
        let oct27 = HabitEntry(date: day(10, 27), completionState: .partial,
                               details: .workout(types: ["Cardio"], duration: "20", intensity: 4, notes: "knee"),
                               habit: workout, source: .hand, editedAt: fixed)
        oct27.health = HealthSnapshot(sessions: [.init(name: "Bike", category: "cycling", minutes: 20, sets: 0, start: nil, activeKcal: 150)], steps: 7_000)
        try context.save()

        let facts: [Date: DayFacts] = [
            day(8, 24): DayFacts(day: day(8, 24), proteinGrams: nil, calories: nil, workoutMinutes: 60,
                                 sessions: [.init(name: "Walk", minutes: 60, category: "walking", activeKcal: 483.8, activityType: "Walking")]),
            day(10, 20): DayFacts(day: day(10, 20), proteinGrams: nil, calories: nil, workoutMinutes: 40,
                                  sessions: [.init(name: "Lift", minutes: 40, category: "strength", setCount: 12, activeKcal: 310)]),
            day(10, 10): DayFacts(day: day(10, 10), proteinGrams: nil, calories: nil, workoutMinutes: 30,
                                  sessions: [.init(name: "Run", minutes: 30, category: "running", activeKcal: 300)]),
        ]
        let readings = HealthRefetch.Readings(
            facts: facts,
            steps: [day(8, 24): 9_500, day(10, 20): 5_000, day(10, 27): 7_000],
            burn: [day(8, 24): HealthBurn(activeKcal: 700, restingKcal: 2_100),
                   day(10, 20): HealthBurn(activeKcal: 900, restingKcal: 2_150),
                   day(10, 27): HealthBurn(activeKcal: 500, restingKcal: 2_100)],
            healthAvailable: true)

        let rows = HealthRefetch.rows(for: workout, dates: dates, calendar: calendar)
        #expect(rows.map(\.date) == [day(8, 24), day(10, 20), day(10, 27)])
        let plan = HealthRefetch.plan(rows: rows, readings: readings, calendar: calendar)
        #expect(plan.rows == 3 && plan.sessionsBefore == 3 && plan.sessionsAfter == 3)
        #expect(plan.changedRows == 3 && plan.burnAdded == 3)
        #expect(plan.biggestKcalChange == .init(day: day(8, 24), name: "Walk", before: 1_189.8, after: 483.8))
        #expect(!HealthRefetch.isDone && !context.hasChanges, "the plan is a preview")

        HealthRefetch.perform(habit: workout, plan: plan, in: context)
        #expect(HealthRefetch.isDone)
        // Aug 24: corrected calories, new steps, burn added; grade / source / time untouched.
        #expect(aug24.health?.sessions.first?.activeKcal == 483.8 && aug24.health?.steps == 9_500)
        #expect(aug24.health?.totalBurnKcal == 2_800 && aug24.health?.sessions.first?.activityType == "Walking")
        #expect(aug24.effectiveCompletionState == .success && aug24.source == .auto && aug24.editedAt == fixed)
        // Oct 20: null → a number.
        #expect(oct20.health?.sessions.first?.activeKcal == 310 && oct20.health?.activeBurnKcal == 900)
        // Oct 27: dh reported nothing, so the sessions stay; burn and steps refreshed; the hand row is still hand.
        #expect(oct27.health?.sessions.map(\.name) == ["Bike"] && oct27.health?.sessions.first?.activeKcal == 150)
        #expect(oct27.health?.totalBurnKcal == 2_600 && oct27.source == .hand && oct27.editedAt == fixed)
        #expect(oct27.details == .workout(types: ["Cardio"], duration: "20", intensity: 4, notes: "knee"))
        // Oct 10 had no row and still has none: the refresh never creates one.
        #expect(HabitStore.entry(for: workout, on: day(10, 10)) == nil)
        // A second plan over the same readings changes nothing.
        #expect(HealthRefetch.plan(rows: HealthRefetch.rows(for: workout, dates: dates, calendar: calendar),
                                   readings: readings, calendar: calendar).changedRows == 0)
    }

    /// Health not readable: the stored steps and burn stay; a block with no
    /// facts and nothing stored stays absent.
    @Test func refetchWithoutHealthKeepsStoredNumbers() {
        let before = HealthSnapshot(sessions: [.init(name: "Walk", category: "walking", minutes: 60, sets: 0, start: nil, activeKcal: 1_189.8)],
                                    steps: 9_000, activeBurnKcal: 650, restingBurnKcal: 2_000)
        let facts = DayFacts(day: day(8, 24), proteinGrams: nil, calories: nil, workoutMinutes: 60,
                             sessions: [.init(name: "Walk", minutes: 60, category: "walking", activeKcal: 483.8)])
        let after = HealthRefetch.rebuilt(before: before, facts: facts, steps: nil, burn: nil)
        #expect(after?.sessions.first?.activeKcal == 483.8 && after?.steps == 9_000)
        #expect(after?.activeBurnKcal == 650 && after?.restingBurnKcal == 2_000)
        #expect(HealthRefetch.rebuilt(before: nil, facts: nil, steps: nil, burn: nil) == nil)
        #expect(HealthRefetch.rebuilt(before: nil, facts: nil, steps: 3_000, burn: HealthBurn(activeKcal: 400, restingKcal: 1_900))
                == HealthSnapshot(steps: 3_000, activeBurnKcal: 400, restingBurnKcal: 1_900))
    }
}

