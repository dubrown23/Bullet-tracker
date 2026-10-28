//
//  HistoryMigration.swift
//  Bullet Tracker
//
//  bt-0022 — the one-time rewrite of history the new Dashboard stands on.
//  Dustin's decisions (2026-10-28):
//
//    • Poison keeps everything.
//    • Workout is dh's record alone from Aug 1 → Oct 26: every Workout row
//      before Oct 27 goes, then one row per day dh has a session, graded by
//      the Workout rule (minutes, then steps) with the current targets,
//      `source = auto`, the sessions + steps under `health`. No-session
//      days stay blank. Meals in the same facts are ignored — no Diet row
//      is ever written here.
//    • Every other habit loses its rows before Oct 27.
//    • Journal notes, the habit list and every row from Oct 27 on are
//      never touched. Go-live stays Oct 27.
//
//  Pure over a `ModelContext` so the tests can run it against an in-memory
//  store; the screen (`App/HistoryMigrationView.swift`) only gates it
//  behind a saved backup and shows the plan first.
//

import Foundation
import SwiftData

@MainActor
enum HistoryMigration {

    // MARK: - Dates

    struct Dates: Equatable {
        /// First day that is left alone (go-live, 2026-10-27).
        let cutoff: Date
        /// The span rebuilt from dh for Workout.
        let importStart: Date
        let importEnd: Date

        static func standard(calendar: Calendar = .current) -> Dates {
            func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
                calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date())
            }
            return Dates(cutoff: day(2026, 10, 27), importStart: day(2026, 8, 1), importEnd: day(2026, 10, 26))
        }
    }

    // MARK: - Done flag

    /// Set once the rewrite has run (seconds since 1970, so `@AppStorage`
    /// can watch it). The Settings row hides itself after that.
    static let doneKey = "historyMigrationDoneAt"

    static var doneAt: Date? {
        let seconds = UserDefaults.standard.double(forKey: doneKey)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    static var isDone: Bool { doneAt != nil }

    // MARK: - What dh and Health know about the span

    struct History: Sendable {
        var facts: [Date: DayFacts]
        /// Apple Health steps per day; empty when Health wasn't readable.
        var steps: [Date: Int]
        var stepsAvailable: Bool
        var notes: [String] = []

        var sessionCount: Int { facts.values.reduce(0) { $0 + $1.sessions.count } }
    }

    /// One facts call for the span (87 days, inside dh's 93-day cap), then
    /// steps from Health for the same days when asked. A facts failure
    /// throws — nothing can be planned without it; a steps failure is noted
    /// and the plan says what it means (short-session days read Tried).
    static func loadHistory(source: any HabitFactsSource, readSteps: Bool, dates: Dates = .standard(),
                            calendar: Calendar = .current) async throws -> History {
        let facts = try await source.facts(from: dates.importStart, to: dates.importEnd)
        var history = History(facts: facts, steps: [:], stepsAvailable: false)
        guard readSteps else {
            history.notes.append("Steps not read on this device.")
            return history
        }
        guard HealthSteps.isAvailable else {
            history.notes.append("Steps: Health data not available on this device.")
            return history
        }
        do {
            try await HealthSteps.shared.requestAuthorization()
            var day = dates.importStart
            while day <= dates.importEnd {
                history.steps[day] = try await HealthSteps.shared.steps(on: day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            history.stepsAvailable = true
        } catch {
            history.notes.append("Steps: \(error.localizedDescription)")
        }
        return history
    }

    // MARK: - The plan

    struct Rebuild: Equatable {
        var sessions = 0
        var days = 0
        var done = 0
        var partial = 0
        var tried = 0
    }

    enum Action: Equatable {
        case kept
        case deleted
        case rebuilt(Rebuild)

        var title: String {
            switch self {
            case .kept: return "Kept"
            case .deleted: return "Deleted"
            case .rebuilt: return "Rebuilt from Dustin's Health"
            }
        }
    }

    struct Line: Identifiable, Equatable {
        let id: UUID
        let name: String
        /// Rows dated before the cutoff, as they are now.
        let rowsBefore: Int
        let action: Action
    }

    struct Plan: Equatable {
        var lines: [Line] = []
        var notesBefore = 0
        /// True when no habit is graded by Workout — nothing to rebuild.
        var workoutMissing = false

        var deletedRows: Int {
            lines.reduce(0) { $0 + ($1.action == .kept ? 0 : $1.rowsBefore) }
        }
        var keptRows: Int {
            lines.reduce(0) { $0 + ($1.action == .kept ? $1.rowsBefore : 0) }
        }
        var rebuilt: Rebuild? {
            for line in lines { if case .rebuilt(let r) = line.action { return r } }
            return nil
        }
    }

    /// Poison keeps its whole history. Matched the way dh matches names:
    /// letters and digits, case-insensitive.
    static func isKeptWhole(_ habit: Habit) -> Bool {
        HabitSyncEngine.habitKey(habit.name ?? "") == "poison"
    }

    static func isWorkout(_ habit: Habit) -> Bool {
        habit.gradingKind == .workout
    }

    /// What the rewrite would do, with counts, before anything changes.
    /// `history == nil` (not loaded yet) plans the deletes and leaves the
    /// Workout line as a rebuild of zero.
    static func plan(habits: [Habit], history: History?, dates: Dates = .standard(), in context: ModelContext) -> Plan {
        var plan = Plan()
        var sawWorkout = false
        for habit in habits.sorted(by: { $0.order < $1.order }) {
            guard let id = habit.id else { continue }
            let before = rowsBefore(cutoff: dates.cutoff, habitID: id, in: context).count
            let action: Action
            if isKeptWhole(habit) {
                action = .kept
            } else if isWorkout(habit), !sawWorkout {
                sawWorkout = true
                action = .rebuilt(rebuild(for: habit, history: history, dates: dates).summary)
            } else {
                action = .deleted
            }
            plan.lines.append(Line(id: id, name: habit.name ?? "Unnamed", rowsBefore: before, action: action))
        }
        plan.workoutMissing = !sawWorkout
        plan.notesBefore = notesBefore(cutoff: dates.cutoff, in: context).count
        return plan
    }

    // MARK: - The rewrite

    /// Does what `plan` said. One save at the end; the done flag is set
    /// only after the save succeeded. Returns the plan it carried out.
    @discardableResult
    static func perform(habits: [Habit], history: History, dates: Dates = .standard(), in context: ModelContext) throws -> Plan {
        let plan = self.plan(habits: habits, history: history, dates: dates, in: context)
        for line in plan.lines where line.action != .kept {
            for row in rowsBefore(cutoff: dates.cutoff, habitID: line.id, in: context) {
                context.delete(row)
            }
        }
        if let workout = habits.first(where: isWorkout) {
            for row in rebuild(for: workout, history: history, dates: dates).rows {
                context.insert(row)
            }
        }
        try context.save()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: doneKey)
        return plan
    }

    // MARK: - Pieces

    /// The Workout rows the span becomes: one per day with at least one
    /// session, graded by the same rule the sync uses, carrying dh's
    /// sessions and the day's steps. Meals on those days are ignored.
    static func rebuild(for workout: Habit, history: History?, dates: Dates, calendar: Calendar = .current)
        -> (rows: [HabitEntry], summary: Rebuild) {
        guard let history else { return ([], Rebuild()) }
        var rows: [HabitEntry] = []
        var summary = Rebuild()
        let targets = workout.gradingTargets
        for (day, facts) in history.facts.sorted(by: { $0.key < $1.key }) {
            let dayStart = calendar.startOfDay(for: day)
            guard dayStart >= dates.importStart, dayStart <= dates.importEnd, !facts.sessions.isEmpty else { continue }
            let steps = history.steps[dayStart]
            // Minutes are known (there is a session), so the rule always answers.
            let grade = WorkoutGrade.state(minutes: facts.workoutMinutes ?? facts.sessions.reduce(0) { $0 + $1.minutes },
                                           steps: steps, targets: targets) ?? .failure
            let row = HabitEntry(date: dayStart, completionState: grade,
                                 details: HabitSyncEngine.autoDetails(for: workout, facts: facts, existing: nil),
                                 habit: workout, source: .auto, editedAt: Date())
            row.health = HabitSyncEngine.snapshot(kind: .workout, facts: facts, steps: steps)
            rows.append(row)
            summary.sessions += facts.sessions.count
            summary.days += 1
            switch grade {
            case .success: summary.done += 1
            case .partial: summary.partial += 1
            default: summary.tried += 1
            }
        }
        return (rows, summary)
    }

    static func rowsBefore(cutoff: Date, habitID: UUID, in context: ModelContext) -> [HabitEntry] {
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in entry.habit?.id == habitID && entry.date < cutoff }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func notesBefore(cutoff: Date, in context: ModelContext) -> [Note] {
        let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        return all.filter { ($0.date ?? .distantFuture) < cutoff }
    }
}
