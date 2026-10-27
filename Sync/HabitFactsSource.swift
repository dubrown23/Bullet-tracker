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
//  with no server. Step 3 adds the real dustin-health client behind the
//  same protocol; nothing downstream changes.
//

import Foundation

// MARK: - Facts

/// What an outside source knows about one local day. Numbers only.
/// `nil` means "nothing tracked" — the grader treats it as a miss.
struct DayFacts: Sendable {
    /// Start of the local day these facts describe.
    let day: Date
    let proteinGrams: Double?
    let calories: Double?
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

// MARK: - Fake source (Step 0)

#if DEBUG
/// Pretends to be dustin-health. Fixed facts that grade Test Diet green
/// (190 g protein, 2,050 cal → both targets hit) and one inbox action,
/// "Test Sauna done". The inbox never clears on purpose: the forced
/// duplicate test needs both devices to apply the same action.
struct FakeHealthFacts: HabitFactsSource {
    let displayName = "Fake dh"

    func facts(for day: Date) async throws -> DayFacts {
        DayFacts(day: day, proteinGrams: 190, calories: 2050)
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
