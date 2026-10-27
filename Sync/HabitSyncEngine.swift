//
//  HabitSyncEngine.swift
//  Bullet Tracker
//
//  bt-0017. One sync run: pull day facts + the inbox from a
//  `HabitFactsSource`, grade with the app's rules, write entries through the
//  SAME write path a tap uses (`HabitStore.setCompletion`), run the
//  duplicate cleanup, confirm back to the source. Reports what it did so the
//  Developer screen can show it.
//
//  Step 0 drives this with `FakeHealthFacts` and two test habits. Step 3
//  points it at dustin-health, adds changed-day re-grading and the rules in
//  the design note ("overrides win", "never re-grade history").
//
//  Duplicate rows (two devices creating the same habit+day before CloudKit
//  merges) are cleaned by `HabitStore.dedupeEntries` — deterministic by id,
//  only ever deletes when a device sees two or more rows, so no sequence of
//  devices can reach zero. See that function's comment.
//

import Foundation
import SwiftData
import Observation

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

    private(set) var isRunning = false
    private(set) var lastReport: Report?

    /// Step 0 grades one habit by name. Step 3 replaces this with the
    /// habit's own "graded by diet facts" setting.
    static let testDietName = "Test Diet"
    static let testSaunaName = "Test Sauna"

    #if DEBUG
    /// Bumped whenever the Developer switch flips, so `@Observable` views
    /// re-read the `UserDefaults`-backed `isSimulationEnabled`.
    private var simulationToggleTick = 0
    #endif

    private let calendar = Calendar.current

    private init() {}

    // MARK: - Run

    /// One full sync against `source`, writing into `context` (the view's
    /// main-actor context, so `@Query`-driven screens update in place).
    func run(source: any HabitFactsSource, in context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        var report = Report(finished: Date(), sourceName: source.displayName)
        let today = calendar.startOfDay(for: Date())
        let habits = allHabits(in: context)
        var touched: [(Habit, Date)] = []

        // 1. Day facts → graded habits. Step 0 grades only Test Diet.
        if let diet = habit(named: Self.testDietName, in: habits) {
            do {
                let facts = try await source.facts(for: today)
                let grade = DietGrade.state(for: facts)
                HabitStore.setCompletion(for: diet, on: today, state: Int(grade.rawValue), in: context)
                touched.append((diet, today))
                report.lines.append("\(Self.testDietName): \(Self.describe(facts)) → \(Self.describe(grade))")
            } catch {
                report.errors.append("Facts: \(error.localizedDescription)")
            }
        }

        // 2. Inbox → ticks, through the tap write path.
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
                switch action.kind {
                case .tick:
                    let state = TickGrade.state(for: target.completionStyle)
                    HabitStore.setCompletion(for: target, on: day, state: Int(state.rawValue), in: context)
                    report.lines.append("\(target.name ?? action.habitName): ticked (\(Self.describe(state)))")
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

        // 3. Cleanup pass over everything this run touched.
        for (habit, day) in touched {
            let removed = HabitStore.dedupeEntries(for: habit, on: day, in: context)
            let remaining = HabitStore.entryCount(for: habit, on: day)
            var line = "\(habit.name ?? "?") rows today: \(remaining)"
            if removed > 0 {
                line += " (removed \(removed) duplicate\(removed == 1 ? "" : "s"))"
            }
            report.lines.append(line)
        }

        // 4. Steps, from the phone itself.
        if HealthSteps.isAvailable {
            do {
                try await HealthSteps.shared.requestAuthorization()
                report.stepsToday = try await HealthSteps.shared.stepsToday()
            } catch {
                report.errors.append("Steps: \(error.localizedDescription)")
            }
        } else {
            report.errors.append("Steps: Health data not available on this device")
        }

        report.finished = Date()
        lastReport = report
    }

    // MARK: - Lookups

    private func allHabits(in context: ModelContext) -> [Habit] {
        (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    private func habit(named name: String, in habits: [Habit]) -> Habit? {
        habits.first { ($0.name ?? "").compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    // MARK: - Wording

    private static func describe(_ facts: DayFacts) -> String {
        let protein = facts.proteinGrams.map { "\(Int($0)) g protein" } ?? "no protein"
        let calories = facts.calories.map { "\(Int($0)) cal" } ?? "no calories"
        return "\(protein), \(calories)"
    }

    private static func describe(_ state: CompletionState) -> String {
        switch state {
        case .notDone: return "not done"
        case .success: return "Done"
        case .partial: return "Partial"
        case .failure: return "Tried / slipped"
        }
    }

    // MARK: - Step 0 simulation (debug builds only)

    #if DEBUG
    private static let simulationKey = "debugSimulateDHSync"

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

    /// Runs the fake sync when the app becomes active, if the switch is on.
    func runSimulationIfEnabled(in context: ModelContext) async {
        guard isSimulationEnabled else { return }
        await runSimulation(in: context)
    }

    /// Ensures the two test habits exist, then runs against `FakeHealthFacts`.
    func runSimulation(in context: ModelContext) async {
        ensureTestHabits(in: context)
        await run(source: FakeHealthFacts(), in: context)
    }

    /// Creates Test Diet (multi-state) and Test Sauna (simple) if missing.
    /// Run from ONE device and let CloudKit carry them to the other —
    /// two devices creating them at once would make two pairs.
    func ensureTestHabits(in context: ModelContext) {
        let habits = allHabits(in: context)
        var order = Int32(habits.count)
        var inserted = false

        if habit(named: Self.testDietName, in: habits) == nil {
            context.insert(Habit(name: Self.testDietName, color: TestHabitHex.partial, icon: "fork.knife",
                                 frequency: "daily", startDate: Date(), order: order, completionStyle: .multiState))
            order += 1
            inserted = true
        }
        if habit(named: Self.testSaunaName, in: habits) == nil {
            context.insert(Habit(name: Self.testSaunaName, color: TestHabitHex.failed, icon: "flame.fill",
                                 frequency: "daily", startDate: Date(), order: order, completionStyle: .simple))
            inserted = true
        }
        if inserted {
            try? context.save()
        }
    }

    /// Deletes both test habits (entries cascade). Confirm gone on every device.
    func removeTestHabits(in context: ModelContext) {
        let habits = allHabits(in: context)
        for name in [Self.testDietName, Self.testSaunaName] {
            // Delete every match, not just the first — if two devices did
            // create a pair each, this is how the extras go too.
            for habit in habits where (habit.name ?? "").caseInsensitiveCompare(name) == .orderedSame {
                context.delete(habit)
            }
        }
        try? context.save()
        lastReport = nil
    }

    /// Today's raw rows per test habit, as short id prefixes in the same
    /// order the cleanup pass uses (first = the survivor). The number the
    /// Today row can't show: a tick looks the same over one row or two, and
    /// matching ids across devices is how you tell "merged" from "not yet".
    /// `nil` = habit missing on this device.
    func testHabitRows(in context: ModelContext) -> [(name: String, ids: [String]?)] {
        let habits = allHabits(in: context)
        let today = calendar.startOfDay(for: Date())
        return [Self.testDietName, Self.testSaunaName].map { name in
            guard let habit = habit(named: name, in: habits) else { return (name, nil) }
            let ids = HabitStore.entries(for: habit, on: today).map { entry in
                entry.id.map { String($0.uuidString.prefix(8)) } ?? "no-id"
            }
            return (name, ids)
        }
    }

    /// Inserts a SECOND row for Test Sauna today, on purpose, bypassing the
    /// upsert in `setCompletion`. This is what two devices writing offline
    /// produce, created deliberately so the pass test doesn't depend on
    /// airplane-mode timing. The row syncs through CloudKit like any other;
    /// the next sync run's cleanup pass should remove it on every device.
    /// Returns false if the habit isn't on this device yet.
    @discardableResult
    func insertDuplicateTestRow(in context: ModelContext) -> Bool {
        guard let habit = habit(named: Self.testSaunaName, in: allHabits(in: context)) else { return false }
        let today = calendar.startOfDay(for: Date())
        let state = TickGrade.state(for: habit.completionStyle)
        context.insert(HabitEntry(date: today, completionState: state, habit: habit))
        try? context.save()
        return true
    }

    /// Colour hexes for the test habits. Same values as `AppTheme.partialHex`
    /// / `failedHex`, repeated here so this file stays free of SwiftUI.
    private enum TestHabitHex {
        static let partial = "#FFB300"
        static let failed = "#EF5350"
    }
    #endif
}
