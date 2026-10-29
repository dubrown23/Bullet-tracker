//
//  HealthRefetch.swift
//  Bullet Tracker
//
//  bt-0023 — the one-time refresh of the stored Workout sessions, Aug 1 →
//  today. Why it exists: dh-0019 (2026-10-28) corrected per-session
//  `active_kcal` (Oct 13–28 sessions were null, Aug 24's walk was a double
//  count), but a stored `health` block only refreshes through the sync's
//  grading window — the last 7 days plus dh's changed days, and changed days
//  before the Oct 27 go-live are dropped. So the Aug–Oct 26 rows could never
//  catch up on their own.
//
//  What it does, per Workout row in the span: rebuilds the row's `health`
//  block from dh's sessions as they are now, reads that day's steps and
//  calories burned (active + resting) from Apple Health, and writes through
//  `HabitStore.setHealth` only when the block changed. The grade, the source
//  ("Set by you"), the edit time and the notes are never touched; no row is
//  created or removed. iPhone + key only; the iPad catches up through iCloud.
//
//  Pure over a `ModelContext` like `HistoryMigration`, so the tests run it
//  against an in-memory store and the screen only shows and confirms it.
//

import Foundation
import SwiftData

@MainActor
enum HealthRefetch {

    // MARK: - Done flag

    /// Seconds since 1970 once the refresh has run; the Settings row hides
    /// itself after that (`@AppStorage` watches the key).
    static let doneKey = "healthRefetchDoneAt"

    static var isDone: Bool { UserDefaults.standard.double(forKey: doneKey) > 0 }

    // MARK: - Span

    struct Dates: Equatable {
        let start: Date
        let end: Date

        /// Aug 1, 2026 → today.
        static func standard(calendar: Calendar = .current, today: Date = Date()) -> Dates {
            let start = calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)) ?? today)
            return Dates(start: start, end: calendar.startOfDay(for: today))
        }
    }

    // MARK: - What dh and Health say now

    struct Readings: Sendable {
        var facts: [Date: DayFacts]
        var steps: [Date: Int] = [:]
        var burn: [Date: HealthBurn] = [:]
        var healthAvailable = false
        var notes: [String] = []

        var sessionCount: Int { facts.values.reduce(0) { $0 + $1.sessions.count } }
    }

    /// The Workout habit's rows in the span, oldest first.
    static func rows(for habit: Habit, dates: Dates, calendar: Calendar = .current) -> [HabitEntry] {
        HabitStore.entriesByDay(for: habit, from: dates.start, to: dates.end)
            .sorted { $0.key < $1.key }
            .map(\.value)
    }

    /// dh's facts for the span (split into ranges under its 93-day cap), then
    /// steps + burn from Health for each row's day when asked. A facts failure
    /// throws; a Health failure is noted and the plan keeps the stored steps.
    static func load(source: any HabitFactsSource, readHealth: Bool, rowDays: [Date], dates: Dates,
                     calendar: Calendar = .current) async throws -> Readings {
        var days = Set<Date>()
        var day = dates.start
        while day <= dates.end {
            days.insert(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        var facts: [Date: DayFacts] = [:]
        for range in DustinHealthWire.ranges(of: days, calendar: calendar) {
            facts.merge(try await source.facts(from: range.from, to: range.to)) { _, new in new }
        }
        var readings = Readings(facts: facts)
        guard readHealth else { return readings }
        guard HealthSteps.isAvailable else {
            readings.notes.append("Health data not available on this device.")
            return readings
        }
        do {
            try await HealthSteps.shared.requestAuthorization()
            for rowDay in rowDays.map({ calendar.startOfDay(for: $0) }) {
                readings.steps[rowDay] = try await HealthSteps.shared.steps(on: rowDay)
                readings.burn[rowDay] = try await HealthSteps.shared.burn(on: rowDay)
            }
            readings.healthAvailable = true
        } catch {
            readings.notes.append("Health: \(error.localizedDescription)")
        }
        return readings
    }

    // MARK: - The plan

    /// One row whose block would change.
    struct Change: Equatable, Identifiable {
        let day: Date
        let before: HealthSnapshot?
        let after: HealthSnapshot?
        var id: Date { day }
    }

    /// The largest per-session active-calorie correction in the span — the
    /// screen's proof that dh's fix landed (expected: Aug 24, 1189.8 → 483.8).
    struct KcalChange: Equatable {
        let day: Date
        let name: String
        let before: Double?
        let after: Double?
        var delta: Double { abs((after ?? 0) - (before ?? 0)) }
    }

    struct Plan: Equatable {
        var rows = 0
        var sessionsBefore = 0
        var sessionsAfter = 0
        var changes: [Change] = []
        /// Rows that gain a burned-calories reading they didn't have.
        var burnAdded = 0
        var biggestKcalChange: KcalChange?

        var changedRows: Int { changes.count }
    }

    /// What the refresh would write, before anything changes. A day dh no
    /// longer reports keeps its stored sessions (never dropped on a gap);
    /// a day Health couldn't read keeps its stored steps.
    static func plan(rows: [HabitEntry], readings: Readings, calendar: Calendar = .current) -> Plan {
        var plan = Plan()
        for row in rows {
            let day = calendar.startOfDay(for: row.date)
            let before = row.health
            let after = rebuilt(before: before, facts: readings.facts[day], steps: readings.steps[day], burn: readings.burn[day])
            plan.rows += 1
            plan.sessionsBefore += before?.sessions.count ?? 0
            plan.sessionsAfter += after?.sessions.count ?? 0
            if before?.totalBurnKcal == nil, after?.totalBurnKcal != nil { plan.burnAdded += 1 }
            if let change = biggestKcalChange(day: day, before: before, after: after),
               change.delta > (plan.biggestKcalChange?.delta ?? 0) {
                plan.biggestKcalChange = change
            }
            if before != after {
                plan.changes.append(Change(day: day, before: before, after: after))
            }
        }
        return plan
    }

    /// The block as the sync would write it today, falling back to what is
    /// stored for anything the sources didn't answer.
    static func rebuilt(before: HealthSnapshot?, facts: DayFacts?, steps: Int?, burn: HealthBurn?) -> HealthSnapshot? {
        var after: HealthSnapshot?
        if let facts {
            after = HabitSyncEngine.snapshot(kind: .workout, facts: facts, steps: steps ?? before?.steps, burn: burn)
        } else if var kept = before {
            // dh has nothing for the day any more (or never had): keep the
            // sessions as stored, refresh only what Health just said.
            if let steps { kept.steps = steps }
            after = kept
        } else if steps != nil || burn?.isEmpty == false {
            after = HealthSnapshot(steps: steps)
        }
        if after != nil, let burn, !burn.isEmpty {
            after?.activeBurnKcal = burn.activeKcal
            after?.restingBurnKcal = burn.restingKcal
        } else if after != nil, burn == nil {
            // Health not read: keep whatever burn the row already carried.
            after?.activeBurnKcal = before?.activeBurnKcal
            after?.restingBurnKcal = before?.restingBurnKcal
        }
        return after
    }

    /// Sessions matched by name (then order) between the stored and rebuilt
    /// block; the one whose active calories moved the most.
    static func biggestKcalChange(day: Date, before: HealthSnapshot?, after: HealthSnapshot?) -> KcalChange? {
        guard let after else { return nil }
        var best: KcalChange?
        var used = Set<Int>()
        for session in after.sessions {
            let oldSessions = before?.sessions ?? []
            let match = oldSessions.indices.first { !used.contains($0) && oldSessions[$0].name == session.name }
            if let match { used.insert(match) }
            let old = match.map { oldSessions[$0].activeKcal } ?? nil
            guard old != session.activeKcal else { continue }
            let change = KcalChange(day: day, name: session.name, before: old, after: session.activeKcal)
            if change.delta > (best?.delta ?? -1) { best = change }
        }
        return best
    }

    // MARK: - The write

    /// Writes every changed block through `HabitStore.setHealth` (grade,
    /// source, edit time and notes untouched), then stamps the done flag.
    @discardableResult
    static func perform(habit: Habit, plan: Plan, in context: ModelContext) -> Plan {
        for change in plan.changes {
            HabitStore.setHealth(for: habit, on: change.day, snapshot: change.after, in: context)
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: doneKey)
        return plan
    }
}
