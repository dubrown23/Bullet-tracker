//
//  HabitFactsSource.swift
//  Bullet Tracker
//
//  bt-0017 (Step 0 of the dh → Bullet sync). The contract between the app
//  and an outside source of day facts + voice actions. The source reports
//  numbers and intents only; every grading rule lives in the app
//  (`HabitGrading.swift`) — see the shared design note, Part A, "Option 2".
//
//  Step 0 ships one implementation, `FakeHealthFacts`, so the pipeline
//  (facts → grade → entry, inbox → tick, cleanup, widget) can be proved
//  with no server. bt-0018 makes the fake selectable from the Developer
//  screen so every colour can be forced. Step 3 adds the real dustin-health
//  client behind the same protocol; nothing downstream changes.
//

import Foundation

// MARK: - Facts

/// What an outside source knows about one local day. Numbers only.
/// `nil` means "nothing tracked" — the Diet grader treats it as a miss;
/// the Workout grader treats unknown minutes as "can't grade" (bt-0018).
struct DayFacts: Sendable {
    /// Start of the local day these facts describe.
    let day: Date
    let proteinGrams: Double?
    let calories: Double?
    /// Workout minutes that day, all sessions added up. `nil` = unknown.
    var workoutMinutes: Double? = nil
}

// MARK: - Inbox

/// One voice action waiting for the app to apply it.
struct InboxAction: Identifiable, Sendable {
    enum Kind: Sendable {
        /// "sauna done", "weed". The app decides what a tick means for the
        /// habit's style (a tick on an avoid habit is the slip).
        case tick
    }

    /// Stable id from the source, echoed back in `confirmApplied`.
    let id: String
    let kind: Kind
    /// Habit name as spoken; matched case-insensitively against `Habit.name`.
    let habitName: String
    /// Start of the local day the action applies to.
    let day: Date
}

// MARK: - Source

protocol HabitFactsSource: Sendable {
    /// Shown in the Developer screen's last-run report.
    var displayName: String { get }

    /// Day facts for one local day.
    func facts(for day: Date) async throws -> DayFacts

    /// Voice actions not yet applied by any device.
    func pendingActions() async throws -> [InboxAction]

    /// Tell the source these actions were applied so it clears them.
    func confirmApplied(_ ids: [String]) async throws
}

// MARK: - Fake source (Step 0, selectable in bt-0018)

#if DEBUG
/// Pretends to be dustin-health. The Developer screen picks what it says,
/// and it says the same thing for every day asked about, so a past day can
/// be forced red while today stays blank. One inbox action, "Test Sauna
/// done"; the inbox never clears on purpose: the forced duplicate test needs
/// both devices to apply the same action.
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

    func facts(for day: Date) async throws -> DayFacts {
        let diet = Self.dietScenario
        return DayFacts(day: day, proteinGrams: diet.proteinGrams, calories: diet.calories,
                        workoutMinutes: Self.workoutScenario.minutes)
    }

    func pendingActions() async throws -> [InboxAction] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            InboxAction(id: "fake-test-sauna-tick", kind: .tick, habitName: HabitSyncEngine.testSaunaName, day: today)
        ]
    }

    func confirmApplied(_ ids: [String]) async throws {
        // Nothing to clear — see the type comment.
    }
}
#endif
