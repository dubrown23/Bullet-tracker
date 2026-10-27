//
//  HabitSyncEngine.swift
//  Bullet Tracker
//
//  bt-0017 / bt-0018. One sync run: pull day facts + the inbox from a
//  `HabitFactsSource` (if one is connected), read steps from Apple Health,
//  grade every automatically graded habit with the app's rules over its
//  go-live window, write entries through the SAME write path a tap uses
//  (`HabitStore.setCompletion`, source = auto), run the duplicate cleanup,
//  confirm back to the source. Keeps today's live numbers for the Today row
//  and reports what it did so the Developer screen can show it.
//
//  Rules (shared design note, Part A + Dustin's bt-0018 review):
//    • Overrides win — an entry written by hand or voice is never touched.
//    • Never re-grade history — only days on/after `Habit.gradingSince`.
//    • Today is "in progress" — Tried is withheld until the day is over.
//    • Only the iPhone writes automatic grades. Any other device (the iPad)
//      reads and shows, but never writes, removes or changes an auto entry:
//      its lagging step count must not undo the phone's grade.
//    • One entry per habit per day — `HabitStore.dedupeEntries` after every
//      write; deterministic, never reaches zero (see that function).
//
//  Step 3 points `source` at dustin-health and adds the changed-days list.
//

import Foundation
import SwiftData
import Observation
import UIKit
import WidgetKit

@MainActor
@Observable
final class HabitSyncEngine {

    static let shared = HabitSyncEngine()

    // MARK: - Report

    struct Report {
        var finished: Date
        let sourceName: String
        var lines: [String] = []
        var stepsToday: Int?
        var errors: [String] = []
    }

    /// Today's numbers for one graded habit, for the caption under its name.
    struct LiveFacts: Equatable {
        var proteinGrams: Double?
        var calories: Double?
        var workoutMinutes: Double?
        var steps: Int?
    }

    private(set) var isRunning = false
    private(set) var lastReport: Report?
    /// Keyed by habit id. Cleared and refilled on every run.
    private(set) var liveFacts: [UUID: LiveFacts] = [:]

    /// Dustin's rule: only the iPhone grades. The Duo is a phone; the iPad
    /// (and a Mac, if it ever runs this) is read-only for automatic entries.
    static var isGradingDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    /// How far back a run re-grades (bounded, so a run stays cheap). The
    /// go-live day caps it further.
    static let lookbackDays = 7

    private let calendar = Calendar.current

    private init() {}

    // MARK: - Entry points

    /// What the app calls on becoming active and on pull-to-refresh. Picks
    /// the source: the fake one when the Developer switch is on; none until
    /// Step 3 connects dustin-health (steps still flow).
    func refresh(in context: ModelContext) async {
        #if DEBUG
        if isSimulationEnabled {
            ensureTestHabits(in: context)
            await run(source: FakeHealthFacts(), in: context)
            return
        }
        #endif
        await run(source: nil, in: context)
    }

    /// One full sync, writing into `context` (the view's main-actor context,
    /// so `@Query`-driven screens update in place). `source == nil` means no
    /// outside facts: Diet can't be graded, Workout only by steps.
    func run(source: (any HabitFactsSource)?, in context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        var report = Report(finished: Date(), sourceName: source?.displayName ?? "No source (steps only)")
        let today = calendar.startOfDay(for: Date())
        let habits = allHabits(in: context)
        var touched: [(Habit, Date)] = []
        let canWrite = Self.isGradingDevice
        if !canWrite {
            report.lines.append("This device doesn't grade (iPhone only) — showing, not writing")
        }

        // 1. Steps per day in the lookback window, from the phone itself.
        var stepsByDay: [Date: Int] = [:]
        if HealthSteps.isAvailable {
            do {
                try await HealthSteps.shared.requestAuthorization()
                for offset in 0..<Self.lookbackDays {
                    guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                    stepsByDay[day] = try await HealthSteps.shared.steps(on: day)
                }
                report.stepsToday = stepsByDay[today]
            } catch {
                report.errors.append("Steps: \(error.localizedDescription)")
            }
        } else {
            report.errors.append("Steps: Health data not available on this device")
        }

        // 2. Graded habits → one grade per day in their window.
        var newLive: [UUID: LiveFacts] = [:]
        for habit in habits where habit.isAutoGraded {
            guard let kind = habit.gradingKind, let since = habit.gradingSince, let habitID = habit.id else { continue }
            let windowStart = max(calendar.startOfDay(for: since),
                                  calendar.date(byAdding: .day, value: -(Self.lookbackDays - 1), to: today) ?? today)
            var day = windowStart
            while day <= today {
                var facts: DayFacts?
                if let source {
                    do { facts = try await source.facts(for: day) } catch {
                        report.errors.append("Facts \(Self.shortDay(day)): \(error.localizedDescription)")
                    }
                }
                let steps = Self.isGradingDevice ? stepsByDay[day] : nil
                let isToday = day == today

                let grade = Self.grade(kind: kind, targets: habit.gradingTargets, facts: facts, steps: steps, isToday: isToday)

                if isToday {
                    newLive[habitID] = LiveFacts(proteinGrams: facts?.proteinGrams, calories: facts?.calories,
                                                 workoutMinutes: facts?.workoutMinutes, steps: steps)
                }

                let outcome = apply(grade: grade, to: habit, on: day, canWrite: canWrite, in: context)
                if outcome.wrote { touched.append((habit, day)) }
                report.lines.append("\(habit.name ?? "?") \(Self.shortDay(day)): \(Self.describe(facts, steps: steps)) → \(GradeWording.describe(grade)) · \(outcome.note)")

                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        liveFacts = newLive

        // 3. Inbox → ticks, through the tap write path (voice rows).
        if let source {
            do {
                let actions = try await source.pendingActions()
                var applied: [String] = []
                for action in actions {
                    guard let target = habit(named: action.habitName, in: habits) else {
                        report.errors.append("Inbox: no habit named “\(action.habitName)”")
                        continue
                    }
                    let day = calendar.startOfDay(for: action.day)
                    guard day <= today else {
                        report.errors.append("Inbox: “\(action.habitName)” is dated in the future, skipped")
                        continue
                    }
                    guard canWrite else {
                        report.lines.append("Inbox: “\(action.habitName)” left for the iPhone")
                        continue
                    }
                    switch action.kind {
                    case .tick:
                        let state = TickGrade.state(for: target.completionStyle)
                        HabitStore.setCompletion(for: target, on: day, state: Int(state.rawValue), source: .voice, in: context)
                        report.lines.append("\(target.name ?? action.habitName): ticked (\(GradeWording.describe(state)), voice)")
                    }
                    touched.append((target, day))
                    applied.append(action.id)
                }
                if !applied.isEmpty {
                    try await source.confirmApplied(applied)
                }
                if actions.isEmpty {
                    report.lines.append("Inbox empty")
                }
            } catch {
                report.errors.append("Inbox: \(error.localizedDescription)")
            }
        }

        // 4. Cleanup pass over everything this run touched, plus today for
        //    every graded habit (a duplicate can arrive from the other device
        //    even when this run wrote nothing). Deterministic on every device.
        var cleanupTargets = touched
        for habit in habits where habit.isAutoGraded { cleanupTargets.append((habit, today)) }
        var seen = Set<String>()
        for (habit, day) in cleanupTargets {
            let key = "\(habit.id?.uuidString ?? "")|\(day.timeIntervalSinceReferenceDate)"
            guard seen.insert(key).inserted else { continue }
            let removed = HabitStore.dedupeEntries(for: habit, on: day, in: context)
            if removed > 0 {
                report.lines.append("\(habit.name ?? "?") \(Self.shortDay(day)): removed \(removed) duplicate\(removed == 1 ? "" : "s")")
            }
        }

        report.finished = Date()
        lastReport = report
    }

    // MARK: - Grading

    /// The grade for one habit-day, or `nil` for "write nothing".
    static func grade(kind: GradingKind, targets: GradingTargets, facts: DayFacts?, steps: Int?, isToday: Bool) -> CompletionState? {
        let raw: CompletionState?
        switch kind {
        case .diet:
            // No source at all → nothing to grade from (not the same as
            // "nothing tracked", which a connected source reports as nils).
            guard let facts else { return nil }
            raw = DietGrade.state(for: facts, targets: targets)
        case .workout:
            raw = WorkoutGrade.state(minutes: facts?.workoutMinutes, steps: steps, targets: targets)
        }
        return InProgressRule.apply(raw, isToday: isToday)
    }

    /// Writes `grade` for the day if this device may and the day's row isn't
    /// an override. `grade == nil` removes an automatic row (drop back).
    private func apply(grade: CompletionState?, to habit: Habit, on day: Date, canWrite: Bool, in context: ModelContext) -> (wrote: Bool, note: String) {
        let existing = HabitStore.entry(for: habit, on: day)

        if let existing, !existing.isAutomatic {
            return (false, "kept (\(GradeWording.describe(existing.source).lowercased()))")
        }
        guard canWrite else {
            return (false, "not written here")
        }

        switch (grade, existing) {
        case (nil, nil):
            return (false, "blank")
        case (nil, .some):
            HabitStore.removeEntry(for: habit, on: day, in: context)
            return (true, "auto row removed")
        case (let g?, let e?) where e.effectiveCompletionState == g:
            return (false, "unchanged")
        case (let g?, _):
            HabitStore.setCompletion(for: habit, on: day, state: Int(g.rawValue), source: .auto, in: context)
            return (true, "written (auto)")
        }
    }

    /// "Back to Automatic" (bt-0018): drops the hand / voice row for the day
    /// and grades it again right now from what's known. Only meaningful on
    /// or after the habit's go-live day — callers hide the control otherwise.
    /// On a non-grading device the row is removed and the day stays blank
    /// until the iPhone's next run fills it.
    func revertToAutomatic(habit: Habit, day: Date, in context: ModelContext) async {
        let dayStart = calendar.startOfDay(for: day)
        guard habit.isWithinGrading(dayStart) else { return }
        HabitStore.removeEntry(for: habit, on: dayStart, in: context)
        await refresh(in: context)
    }

    // MARK: - Captions

    /// One line for the Today row of a graded habit: the live numbers against
    /// the targets. `nil` when nothing is known yet.
    func caption(for habit: Habit) -> String? {
        guard let id = habit.id, let kind = habit.gradingKind, let live = liveFacts[id] else { return nil }
        let t = habit.gradingTargets
        switch kind {
        case .diet:
            guard live.proteinGrams != nil || live.calories != nil else { return nil }
            let protein = "\(Int(live.proteinGrams ?? 0)) / \(Int(t.proteinFloorGrams)) g"
            let calories = "\((live.calories ?? 0).formatted(.number.precision(.fractionLength(0)))) cal"
            return "\(protein) · \(calories)"
        case .workout:
            var parts: [String] = []
            if let minutes = live.workoutMinutes { parts.append("\(Int(minutes)) min") }
            if let steps = live.steps { parts.append("\(steps.formatted()) steps") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    // MARK: - Lookups

    private func allHabits(in context: ModelContext) -> [Habit] {
        (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    private func habit(named name: String, in habits: [Habit]) -> Habit? {
        habits.first { ($0.name ?? "").compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    // MARK: - Wording

    private static func describe(_ facts: DayFacts?, steps: Int?) -> String {
        var parts: [String] = []
        if let facts {
            parts.append(facts.proteinGrams.map { "\(Int($0)) g" } ?? "no protein")
            parts.append(facts.calories.map { "\(Int($0)) cal" } ?? "no calories")
            parts.append(facts.workoutMinutes.map { "\(Int($0)) min" } ?? "min ?")
        } else {
            parts.append("no facts")
        }
        parts.append(steps.map { "\($0) steps" } ?? "steps ?")
        return parts.joined(separator: ", ")
    }

    private static func shortDay(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "today" }
        if Calendar.current.isDateInYesterday(day) { return "yesterday" }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Test habits + simulation (debug builds only)

    static let testDietName = "Test Diet"
    static let testSaunaName = "Test Sauna"
    static let testWorkoutName = "Test Workout"

    #if DEBUG
    private static let simulationKey = "debugSimulateDHSync"

    /// Bumped whenever the Developer switch flips, so `@Observable` views
    /// re-read the `UserDefaults`-backed `isSimulationEnabled`.
    private var simulationToggleTick = 0

    /// "Simulate dh sync" switch in Settings → Developer. Persisted so the
    /// on-open run survives relaunches during the pass test.
    var isSimulationEnabled: Bool {
        get {
            _ = simulationToggleTick
            return UserDefaults.standard.bool(forKey: Self.simulationKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.simulationKey)
            simulationToggleTick &+= 1
        }
    }

    /// Developer "Run now": ensures the test habits, runs against the fake.
    func runSimulation(in context: ModelContext) async {
        ensureTestHabits(in: context)
        await run(source: FakeHealthFacts(), in: context)
    }

    /// Creates Test Diet (graded by diet), Test Workout (graded by workout)
    /// and Test Sauna (simple) if missing, go-live today. Run from ONE
    /// device and let CloudKit carry them to the other — two devices
    /// creating them at once would make two sets.
    func ensureTestHabits(in context: ModelContext) {
        let habits = allHabits(in: context)
        var order = Int32(habits.count)
        var inserted = false
        let today = calendar.startOfDay(for: Date())

        // Start a week back so past squares are tappable: the go-live guard
        // check needs a hand entry on a day BEFORE grading started.
        let start = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        if habit(named: Self.testDietName, in: habits) == nil {
            let h = Habit(name: Self.testDietName, color: TestHabitHex.partial, icon: "fork.knife",
                          frequency: "daily", startDate: start, order: order, completionStyle: .multiState)
            h.gradingKind = .diet
            h.gradingSince = today
            context.insert(h)
            order += 1
            inserted = true
        }
        if habit(named: Self.testWorkoutName, in: habits) == nil {
            let h = Habit(name: Self.testWorkoutName, color: TestHabitHex.success, icon: "figure.run",
                          frequency: "daily", startDate: start, order: order, completionStyle: .multiState, detailKind: .workout)
            h.gradingKind = .workout
            h.gradingSince = today
            context.insert(h)
            order += 1
            inserted = true
        }
        if habit(named: Self.testSaunaName, in: habits) == nil {
            context.insert(Habit(name: Self.testSaunaName, color: TestHabitHex.failed, icon: "flame.fill",
                                 frequency: "daily", startDate: start, order: order, completionStyle: .simple))
            inserted = true
        }
        if inserted {
            try? context.save()
        }
    }

    /// Puts Test Workout first in the habit order so its tile is visible in
    /// the widget (the real habits fill the grid and the test ones fall into
    /// "+N"). Only the test habit's `order` changes — it takes a value below
    /// every real habit — so there is nothing to restore when it is removed.
    func moveTestWorkoutFirst(in context: ModelContext) {
        let habits = allHabits(in: context)
        guard let workout = habit(named: Self.testWorkoutName, in: habits) else { return }
        let lowest = habits.map(\.order).min() ?? 0
        workout.order = lowest - 1
        try? context.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }

    /// Moves the two graded test habits' go-live day back to yesterday so
    /// the "red only after midnight" rule can be shown without waiting.
    func startGradingYesterday(in context: ModelContext) {
        let habits = allHabits(in: context)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) else { return }
        for name in [Self.testDietName, Self.testWorkoutName] {
            habit(named: name, in: habits)?.gradingSince = yesterday
        }
        try? context.save()
    }

    /// Deletes the test habits (entries cascade). Confirm gone on every device.
    func removeTestHabits(in context: ModelContext) {
        // Clear the observable state FIRST. Today's rows watch `liveFacts`;
        // changing it after the delete re-rendered them against a habit that
        // no longer existed (SwiftData assertion, found in the bt-0018 pass
        // test). Cleared first, the rows re-render while the habits are
        // still live, and the delete then flows through `@Query` normally.
        lastReport = nil
        liveFacts = [:]

        let habits = allHabits(in: context)
        for name in [Self.testDietName, Self.testWorkoutName, Self.testSaunaName] {
            // Delete every match, not just the first — if two devices did
            // create a set each, this is how the extras go too.
            for habit in habits where (habit.name ?? "").caseInsensitiveCompare(name) == .orderedSame {
                context.delete(habit)
            }
        }
        try? context.save()
    }

    /// One raw row, as the Developer screen shows it.
    struct RowReadout: Identifiable {
        let id: String
        let state: String
        let source: String
        let editedAt: Date?
    }

    /// Raw rows per test habit for today and yesterday, survivor first.
    /// State · source · edit time is the evidence the Today square can't
    /// show. `nil` rows = habit missing on this device.
    func testHabitRows(in context: ModelContext) -> [(name: String, day: String, rows: [RowReadout]?)] {
        let habits = allHabits(in: context)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var result: [(String, String, [RowReadout]?)] = []
        for name in [Self.testDietName, Self.testWorkoutName, Self.testSaunaName] {
            guard let habit = habit(named: name, in: habits) else {
                result.append((name, "today", nil))
                continue
            }
            for (label, day) in [("today", today), ("yesterday", yesterday)] {
                let rows = HabitStore.entries(for: habit, on: day).map { entry in
                    RowReadout(id: entry.id.map { String($0.uuidString.prefix(8)) } ?? "no-id",
                               state: GradeWording.describe(entry.effectiveCompletionState),
                               source: GradeWording.describe(entry.source).lowercased(),
                               editedAt: entry.editedAt)
                }
                result.append((name, label, rows))
            }
        }
        return result
    }

    /// Inserts a SECOND row for a test habit today, on purpose, bypassing
    /// the upsert in `setCompletion`. This is what two devices writing
    /// offline produce, created deliberately so the pass test doesn't
    /// depend on airplane-mode timing. The row syncs through CloudKit like
    /// any other; the next run's cleanup pass should remove it on every
    /// device. bt-0018: the duplicate is an AUTO row, so beside a hand row
    /// the cleanup must keep the hand one. Returns false if the habit isn't
    /// on this device yet.
    @discardableResult
    func insertDuplicateTestRow(in context: ModelContext) -> Bool {
        guard let habit = habit(named: Self.testDietName, in: allHabits(in: context)) else { return false }
        let today = calendar.startOfDay(for: Date())
        context.insert(HabitEntry(date: today, completionState: .partial, habit: habit, source: .auto, editedAt: Date()))
        try? context.save()
        return true
    }

    /// Colour hexes for the test habits. Same values as `AppTheme`,
    /// repeated here so this file stays free of SwiftUI.
    private enum TestHabitHex {
        static let partial = "#FFB300"
        static let failed = "#EF5350"
        static let success = "#4CAF50"
    }
    #endif
}
