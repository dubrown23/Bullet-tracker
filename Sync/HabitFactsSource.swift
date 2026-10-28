//
//  HabitFactsSource.swift
//  Bullet Tracker
//
//  bt-0017 / bt-0019. The contract between the app and an outside source of
//  day facts + voice actions. The source reports numbers and intents only;
//  every grading rule lives in the app (`HabitGrading.swift`) — see the
//  shared design note, Part A, "Option 2".
//
//  Step 0 (bt-0017) shipped one implementation, `FakeHealthFacts`, so the
//  pipeline could be proved with no server. Step 3 (bt-0019) widened the
//  protocol to the real dustin-health contract (`api/bullet.js`: sync,
//  changes, facts, inbox, ack) and added `DustinHealthFacts` in
//  `DustinHealthSource.swift`. The fake implements the same shape so the
//  Developer screen keeps forcing every colour without a network.
//

import Foundation

// MARK: - Facts

/// What an outside source knows about one local day. Numbers only.
/// `nil` means "nothing tracked" — the Diet grader treats it as a miss;
/// the Workout grader treats unknown minutes as "can't grade" (bt-0018).
struct DayFacts: Sendable, Equatable {
    /// One workout session that day, for the entry's details (bt-0019).
    struct Session: Sendable, Equatable {
        let name: String
        let minutes: Double
        /// dh's `activity_category` ("walking", "strength", …) — lights a
        /// type chip (bt-0021). `nil` = not reported.
        var category: String? = nil
        /// Sets dh logged for the session (bt-0021). The count only.
        var setCount: Int = 0
        var startedAt: Date? = nil
        /// bt-0022 — Watch active calories; `nil` = dh doesn't know.
        var activeKcal: Double? = nil
        /// bt-0022 — Apple's activity name on the primary Watch record.
        var activityType: String? = nil
    }

    /// One meal as dh logged it (bt-0021, dh's `items`). A `nil` number
    /// means dh doesn't know it — shown as a dash, never as 0.
    struct Meal: Sendable, Equatable {
        let id: String?
        let name: String
        var calories: Double? = nil
        var protein: Double? = nil
        var carbs: Double? = nil
        var fat: Double? = nil
        var loggedAt: Date? = nil
    }

    /// Start of the local day these facts describe.
    let day: Date
    let proteinGrams: Double?
    let calories: Double?
    /// Workout minutes that day, all sessions added up. `nil` = unknown.
    var workoutMinutes: Double? = nil
    /// Meal names in the order logged (bt-0019, details on a Diet row).
    var mealNames: [String] = []
    /// Sessions in start order (bt-0019, details on a Workout row).
    var sessions: [Session] = []
    /// Meals in the order logged (bt-0021, the Diet row's list).
    var meals: [Meal] = []
}

// MARK: - Sync (the app → dh, once per run)
//
// `TargetKey` (the five wire targets) lives in `Data/Models.swift` beside
// `GradingKind`, because `Habit` reads and writes by it and that file is
// shared with the widget target.

/// What the app tells dh on every run: its habit list (so voice knows the
/// names and kinds), its targets (one place to set them), its time zone
/// (so meal days are HIS days) and today's hand ticks (so "what's left
/// today" knows about taps).
struct HabitSyncPayload: Sendable, Equatable {
    struct HabitItem: Sendable, Equatable {
        let name: String
        /// "simple" / "graded" / "avoid" — dh's `HABIT_KINDS`.
        let kind: String
        /// "reading_log" or `nil`. Sent explicitly so dh clears a stale value.
        let detailKind: String?
    }

    var habits: [HabitItem]
    var targets: [TargetKey: Double]
    var timeZone: String
    var tickedToday: [String]
}

/// dh's answer: which targets it held back because a voice change is still
/// pending (the app takes dh's value for those), and its current numbers.
struct HabitSyncReply: Sendable, Equatable {
    var heldTargets: [TargetKey]
    var targets: [TargetKey: Double]
}

/// Days whose facts changed since the app last asked, plus the cursor to
/// send next time (dh already backs it off two minutes for late commits).
struct ChangedDays: Sendable, Equatable {
    var days: [Date]
    var nextSince: String
}

/// What dh says about an ack: ids it marked applied and ids it could not.
struct AckResult: Sendable, Equatable {
    struct NotApplied: Sendable, Equatable {
        let id: String
        let reason: String
    }
    var applied: Int
    var notApplied: [NotApplied]
}

// MARK: - Inbox

/// A grade said by voice, as dh spells it (`HABIT_GRADES`).
enum VoiceGrade: String, Sendable, Codable {
    case done, partial, tried, rest, auto
}

/// One voice action waiting for the app to apply it.
struct InboxAction: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// "sauna done", "weed". The app decides what a tick means for the
        /// habit's style (a tick on an avoid habit is the slip). Details
        /// said with the tick ride along (Reading Log).
        case tick(note: String?, book: String?, pages: Int?)
        /// "undo the sauna" — removes the day's row.
        case untick
        /// "call diet partial", "rest day today", "put diet back on auto".
        case setGrade(VoiceGrade)
        /// "workout note: knee felt tight". Details only — never a state,
        /// never a source (Dustin's rule, bt-0019).
        case note(text: String?, book: String?, pages: Int?)
        /// "set my protein target to 190". No habit name on the wire; the
        /// key says which graded habit it belongs to.
        case setTarget(TargetKey, Double)
    }

    /// Stable id from the source, echoed back in `confirmApplied`.
    let id: String
    let kind: Kind
    /// Habit name as dh stores it; `nil` for a target change.
    let habitName: String?
    /// Start of the local day the action applies to.
    let day: Date

    /// Short wording for reports and the "Couldn't apply" list.
    var title: String {
        let name = habitName ?? ""
        switch kind {
        case .tick: return "\(name): tick"
        case .untick: return "\(name): undo"
        case .setGrade(let grade): return "\(name): \(grade.rawValue)"
        case .note: return "\(name): note"
        case .setTarget(let key, let value): return "\(key.title) → \(value.formatted())"
        }
    }
}

// MARK: - Source

protocol HabitFactsSource: Sendable {
    /// Shown in the Developer screen's last-run report.
    var displayName: String { get }

    /// True for the real server: the engine then keeps a changes cursor
    /// and the Settings status for it. The fake is never live.
    var isLive: Bool { get }

    /// Send the habit list, targets, time zone and today's hand ticks.
    func sync(_ payload: HabitSyncPayload) async throws -> HabitSyncReply

    /// Days whose facts changed since `since` (a cursor from an earlier
    /// reply). `nil` = first run: nothing extra to re-grade.
    func changedDays(since: String?) async throws -> ChangedDays

    /// Day facts for every local day in `from...to`, keyed by start of day.
    func facts(from: Date, to: Date) async throws -> [Date: DayFacts]

    /// Voice actions not yet applied by any device.
    func pendingActions() async throws -> [InboxAction]

    /// Tell the source these actions were applied so it clears them.
    func confirmApplied(_ ids: [String]) async throws -> AckResult
}

// MARK: - Fake source (Step 0, selectable in bt-0018, Step 3 shape in bt-0019)

#if DEBUG
/// Pretends to be dustin-health. The Developer screen picks what it says,
/// and it says the same thing for every day asked about, so a past day can
/// be forced red while today stays blank. One inbox action, "Test Sauna
/// done"; the inbox never clears on purpose: the forced duplicate test needs
/// both devices to apply the same action. Never holds a target, never
/// reports a changed day.
struct FakeHealthFacts: HabitFactsSource {
    /// What the fake meals say. Picked in Settings → Developer.
    enum DietScenario: String, CaseIterable, Identifiable {
        case neither, proteinOnly, both, overCalories
        var id: String { rawValue }

        var title: String {
            switch self {
            case .neither: return "Neither"
            case .proteinOnly: return "Protein only"
            case .both: return "Both"
            case .overCalories: return "Over calories"
            }
        }

        var proteinGrams: Double {
            switch self {
            case .neither: return 100
            case .proteinOnly, .both, .overCalories: return 190
            }
        }

        var calories: Double {
            switch self {
            case .neither: return 1200
            case .proteinOnly: return 1500
            case .both: return 2050
            case .overCalories: return 2400
            }
        }
    }

    /// What the fake workout log says.
    enum WorkoutScenario: String, CaseIterable, Identifiable {
        case unknown, none, fortyFive
        var id: String { rawValue }

        var title: String {
            switch self {
            case .unknown: return "Unknown"
            case .none: return "0 min"
            case .fortyFive: return "45 min"
            }
        }

        var minutes: Double? {
            switch self {
            case .unknown: return nil
            case .none: return 0
            case .fortyFive: return 45
            }
        }
    }

    static let dietKey = "debugFakeDietScenario"
    static let workoutKey = "debugFakeWorkoutScenario"

    static var dietScenario: DietScenario {
        get { UserDefaults.standard.string(forKey: dietKey).flatMap(DietScenario.init(rawValue:)) ?? .both }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: dietKey) }
    }

    static var workoutScenario: WorkoutScenario {
        get { UserDefaults.standard.string(forKey: workoutKey).flatMap(WorkoutScenario.init(rawValue:)) ?? .unknown }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: workoutKey) }
    }

    let displayName = "Fake dh"
    let isLive = false

    func sync(_ payload: HabitSyncPayload) async throws -> HabitSyncReply {
        HabitSyncReply(heldTargets: [], targets: payload.targets)
    }

    func changedDays(since: String?) async throws -> ChangedDays {
        ChangedDays(days: [], nextSince: since ?? "fake")
    }

    func facts(from: Date, to: Date) async throws -> [Date: DayFacts] {
        let calendar = Calendar.current
        let diet = Self.dietScenario
        let minutes = Self.workoutScenario.minutes
        var result: [Date: DayFacts] = [:]
        var day = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: to)
        while day <= last {
            let breakfast = calendar.date(byAdding: .hour, value: 8, to: day)
            let start = calendar.date(byAdding: .hour, value: 10, to: day)
            result[day] = DayFacts(day: day, proteinGrams: diet.proteinGrams, calories: diet.calories,
                                   workoutMinutes: minutes,
                                   mealNames: ["Fake meal"],
                                   sessions: minutes.map {
                                       [DayFacts.Session(name: "Fake session", minutes: $0, category: "walking", setCount: 0, startedAt: start)]
                                   } ?? [],
                                   meals: [DayFacts.Meal(id: "fake-meal", name: "Fake meal", calories: diet.calories,
                                                         protein: diet.proteinGrams, carbs: nil, fat: nil, loggedAt: breakfast)])
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    func pendingActions() async throws -> [InboxAction] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            InboxAction(id: "fake-test-sauna-tick", kind: .tick(note: nil, book: nil, pages: nil),
                        habitName: HabitSyncEngine.testSaunaName, day: today)
        ]
    }

    func confirmApplied(_ ids: [String]) async throws -> AckResult {
        // Nothing to clear — see the type comment.
        AckResult(applied: ids.count, notApplied: [])
    }
}
#endif
