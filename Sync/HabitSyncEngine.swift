//
//  HabitSyncEngine.swift
//  Bullet Tracker
//
//  bt-0017 / bt-0018 / bt-0019. One sync run against a `HabitFactsSource`
//  (dustin-health when a key is stored on the iPhone; the fake from the
//  Developer screen; none = steps only):
//
//    1. steps + calories burned (active + resting, bt-0023) from Apple
//       Health for every day that will be graded
//    2. op=sync  — send habits, targets, time zone, today's hand ticks;
//                  take dh's value for any target it held (voice wins)
//    3. op=changes — which past days' facts changed since the last run
//    4. inbox → apply through the SAME write path a tap uses (source =
//       voice; a note adds details only), ack what was applied
//    5. op=facts for the window + changed days → grade with the app's
//       rules → write auto rows (overrides are never touched)
//    6. duplicate cleanup, status + cursor saved only after a clean run
//
//  Rules (shared design note, Part A + Dustin's bt-0018 / bt-0019 reviews):
//    • Overrides win — an entry written by hand or voice is never touched.
//    • Never re-grade history — only days on/after `Habit.gradingSince`.
//    • Today is "in progress" — Tried is withheld until the day is over.
//    • Only the iPhone writes automatic grades AND only the iPhone talks
//      to dh. The iPad reads and shows what iCloud brings it.
//    • One entry per habit per day — `HabitStore.dedupeEntries` after every
//      write; deterministic, never reaches zero (see that function).
//    • A voice note never sets a state or a source.
//    • Facts that could not be loaded leave every row exactly as it is.
//    • bt-0020: a hand tap sends itself — a quiet run 3 s after the last
//      tap, at once when the app leaves, and never hidden by the on-open
//      throttle (see "Quiet sync after a tap" below). Today-only until
//      2026-10-30; now any day, and op=sync carries the last seven days'
//      ticks (`ticked_days`, which replaced `ticked_today`) — sent again
//      at the end of a run that applied a voice tick / untick / grade.
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
        /// bt-0020 — why this run happened (Developer screen's Last run line).
        let reason: RunReason
        var lines: [String] = []
        var stepsToday: Int?
        var errors: [String] = []
    }

    /// Why a run happened. Plain words, shown as-is on the Developer screen.
    enum RunReason: String {
        case open = "open"
        case openTapWaiting = "open · tap waiting"
        case pullDown = "pull-down"
        case settings = "Settings"
        case afterTap = "after a tap"
        case leavingApp = "leaving the app"
        case backToAuto = "Back to Auto"
        case developer = "Developer"
    }

    /// Today's numbers for one graded habit, for the caption under its name.
    struct LiveFacts: Equatable {
        var proteinGrams: Double?
        var calories: Double?
        var workoutMinutes: Double?
        var steps: Int?
    }

    /// bt-0019 — what Settings → Dustin's Health shows. Persisted so the
    /// line survives a relaunch; only a live source (dh) writes it.
    struct SyncStatus: Codable, Equatable {
        var lastSuccess: Date?
        var lastError: String?
        var keyRejected = false
        var lastAppliedCount = 0
        var unapplied: [UnappliedAction] = []
    }

    /// An inbox action the app could not use. Stays pending on dh and
    /// listed here until Dismiss acks it on purpose.
    struct UnappliedAction: Codable, Equatable, Identifiable {
        let id: String
        let title: String
        let reason: String
    }

    private(set) var isRunning = false
    private(set) var lastReport: Report?
    /// Keyed by habit id. Cleared and refilled on every run.
    private(set) var liveFacts: [UUID: LiveFacts] = [:]
    /// Today's sessions / meals per graded habit (bt-0021), so Log Details
    /// can show the list before the day has a row. Refilled on every run.
    private(set) var liveHealth: [UUID: HealthSnapshot] = [:]
    private(set) var status: SyncStatus

    /// Dustin's rule: only the iPhone grades and only the iPhone syncs.
    /// The Duo is a phone; the iPad (and a Mac, if it ever runs this) is
    /// read-only for automatic entries and never calls dh.
    static var isGradingDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    /// How far back a run re-grades on its own (bounded, so a run stays
    /// cheap). The go-live day caps it further; changed days extend it.
    static let lookbackDays = 7

    /// An automatic run (app became active) is skipped if the last clean
    /// run with dh was this recent. Pull-down and Save always run.
    static let minimumInterval: TimeInterval = 120

    private static let statusKey = "dhSyncStatus"
    private static let cursorKey = "dhNextSince"

    private let calendar = Calendar.current
    private var lastAttempt: Date?

    // MARK: - Quiet sync after a tap (bt-0020)
    //
    // `HabitStore` reports every write here. A hand write on any day (today
    // only until 2026-10-30) arms a timer; when it fires the same full run
    // as pull-down goes (op=sync is its first call, so dh knows about the
    // tap within about a second — under its own day, via `ticked_days`).
    // Every tap restarts the timer, so a burst of taps is one send. Any run
    // that starts for another reason drops the waiting timer — it built its
    // tick list after the tap's save, so it already carries the tap.
    //
    // Leaving the app (lock, Home) with a tap waiting sends at once inside
    // a background-task window taken at the tap (Apple: take it before
    // entering the background, not on the way out). Two dates on disk make
    // the backstop: `tapWaitingSince` (every hand tap on today) and
    // `lastSentAt` (the START of the last run whose op=sync succeeded). On
    // open, a tap or widget stamp newer than `lastSentAt` runs past the
    // 120 s throttle. No clearing step, so nothing can be left stuck.

    /// How long after the last hand tap the quiet sync goes. Longer than the
    /// gap between taps when cycling a square (~1 s); shorter than lifting
    /// the phone and asking Claude. Tests shorten it.
    static var quietSyncDelay: Duration = .seconds(3)

    /// Runs since launch — the Developer screen's proof that five quick
    /// taps made one send.
    private(set) var runsSinceLaunch = 0

    private static let tapWaitingKey = "dhTapWaitingSince"
    private static let lastSentKey = "dhLastSentAt"
    /// Written by the widget's intent after every tile tap (App Group).
    private static let widgetStampKey = "lastWidgetUpdate"
    /// bt-0029 — set once the old automatic Partial Workout days are Active days.
    private static let activeDayConvertedKey = "activeDayConverted"

    private var pendingTap: Task<Void, Never>?
    private var pendingTapContext: ModelContext?
    private var backgroundWindow: UIBackgroundTaskIdentifier = .invalid

    #if DEBUG
    /// Tests only: every `refresh` runs this source against this context,
    /// taps from any other context are ignored, and Health isn't asked
    /// for steps (the permission sheet would stall the test host).
    struct TestOverride {
        let source: any HabitFactsSource
        let context: ModelContext
    }
    var testOverride: TestOverride?

    /// True inside a test host. The app's own on-open sync then stays out
    /// of the way — it would ask Health (whose permission request can hang
    /// the host) and hold `isRunning` while a test waits. Only runs a test
    /// drives through `testOverride` happen.
    static let isUnderTest: Bool = {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()
    #endif

    private init() {
        status = Self.loadStatus()
    }

    // MARK: - Entry points

    /// What the app calls on becoming active (`force == false`) and on
    /// pull-to-refresh (`force == true`). Picks the source: the fake when
    /// the Developer switch is on; dh when this is the iPhone and a key is
    /// stored; otherwise none (steps still flow).
    func refresh(in context: ModelContext, force: Bool = false, reason: RunReason? = nil) async {
        var reason = reason ?? (force ? .pullDown : .open)
        #if DEBUG
        if let override = testOverride {
            await run(source: override.source, in: override.context, reason: reason)
            return
        }
        if Self.isUnderTest { return }
        if isSimulationEnabled {
            ensureTestHabits(in: context)
            await run(source: FakeHealthFacts(), in: context, reason: reason)
            return
        }
        #endif
        if Self.isGradingDevice, let key = APIKeyStore.read() {
            if !force {
                switch Self.decideOnOpen(lastAttempt: lastAttempt, now: Date(),
                                         tapWaitingSince: Self.tapWaitingSince,
                                         widgetStamp: Self.widgetStamp,
                                         lastSentAt: Self.lastSentAt) {
                case .skip: return
                case .runTapWaiting: reason = .openTapWaiting
                case .run: break
                }
            }
            lastAttempt = Date()
            await run(source: DustinHealthFacts(key: key), in: context, reason: reason)
            return
        }
        await run(source: nil, in: context, reason: reason)
    }

    /// Settings → Save / Sync now.
    func syncNow(in context: ModelContext) async {
        await refresh(in: context, force: true, reason: .settings)
    }

    // MARK: - Quiet sync entry points (bt-0020)

    /// `HabitStore` calls this after every write. Only a hand write, on an
    /// iPhone that can reach dh, arms the quiet sync — on any day since
    /// 2026-10-30 (the payload carries the last seven days, so fixing
    /// yesterday and then asking voice is right straight away).
    func noteWrite(on day: Date, source: EntrySource, in context: ModelContext) {
        var canReach = APIKeyStore.hasKey
        #if DEBUG
        if let override = testOverride {
            guard context === override.context else { return }
            canReach = true
        } else if isSimulationEnabled {
            canReach = true
        }
        #endif
        guard Self.shouldQuietSync(isPhone: Self.isGradingDevice, hasKey: canReach, source: source) else { return }

        Self.tapWaitingSince = Date()
        holdBackgroundWindow()
        pendingTap?.cancel()
        pendingTapContext = context
        pendingTap = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(for: Self.quietSyncDelay) } catch { return }
            await self.sendWaitingTap(reason: .afterTap)
        }
    }

    /// The scene went to the background. A tap still waiting goes now,
    /// inside the window taken when it was noted. Nothing waiting → nothing.
    func appLeftForeground() {
        guard pendingTap != nil else { return }
        pendingTap?.cancel()
        pendingTap = Task { [weak self] in
            await self?.sendWaitingTap(reason: .leavingApp)
        }
    }

    /// Phone + key + a hand write, any day. Pure, so the table is testable
    /// without faking a device. (Today-only until 2026-10-30: a past-day
    /// tap used to wait for the next run; now it sends like a today tap.)
    static func shouldQuietSync(isPhone: Bool, hasKey: Bool, source: EntrySource) -> Bool {
        isPhone && hasKey && source == .hand
    }

    enum OpenDecision: Equatable {
        case skip, run, runTapWaiting
    }

    /// The on-open rule. A tap or widget stamp newer than the last
    /// successful send always runs (the throttle never hides a waiting
    /// tap); otherwise the 120 s throttle applies.
    static func decideOnOpen(lastAttempt: Date?, now: Date, tapWaitingSince: Date?, widgetStamp: Date?, lastSentAt: Date?) -> OpenDecision {
        let waiting = [tapWaitingSince, widgetStamp].compactMap { $0 }.max()
        if let waiting, waiting > (lastSentAt ?? .distantPast) {
            return .runTapWaiting
        }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < minimumInterval {
            return .skip
        }
        return .run
    }

    /// Waits for a running sync to finish (its tick list predates the tap),
    /// then runs. Clears `pendingTap` first so the run's own cancel doesn't
    /// hit the task that is calling it.
    private func sendWaitingTap(reason: RunReason) async {
        while isRunning {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        }
        guard let context = pendingTapContext else { return }
        pendingTap = nil
        pendingTapContext = nil
        await refresh(in: context, force: true, reason: reason)
    }

    private func holdBackgroundWindow() {
        guard backgroundWindow == .invalid else { return }
        backgroundWindow = UIApplication.shared.beginBackgroundTask(withName: "Send taps to dh") { [weak self] in
            self?.releaseBackgroundWindow()
        }
    }

    private func releaseBackgroundWindow() {
        guard backgroundWindow != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundWindow)
        backgroundWindow = .invalid
    }

    /// Last hand tap on today (standard defaults).
    static var tapWaitingSince: Date? {
        get { date(forKey: tapWaitingKey, in: .standard) }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: tapWaitingKey) }
    }

    /// Start time of the last run whose op=sync succeeded.
    static var lastSentAt: Date? {
        get { date(forKey: lastSentKey, in: .standard) }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: lastSentKey) }
    }

    /// The widget's last tile tap (App Group defaults; the widget writes it).
    static var widgetStamp: Date? {
        date(forKey: widgetStampKey, in: UserDefaults(suiteName: DataStore.appGroupIdentifier))
    }

    private static func date(forKey key: String, in defaults: UserDefaults?) -> Date? {
        guard let defaults, defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    /// Whether this device holds a key and may talk to dh.
    var isConnectedToHealth: Bool {
        Self.isGradingDevice && APIKeyStore.hasKey
    }

    /// "Couldn't apply" → Dismiss: ack the action without applying it, on
    /// purpose, so dh stops sending it.
    func dismiss(_ action: UnappliedAction) async {
        guard Self.isGradingDevice, let key = APIKeyStore.read() else { return }
        do {
            _ = try await DustinHealthFacts(key: key).confirmApplied([action.id])
            status.unapplied.removeAll { $0.id == action.id }
            Self.saveStatus(status)
        } catch {
            status.lastError = error.localizedDescription
            Self.saveStatus(status)
        }
    }

    /// Settings → Remove key. Forgets the key, the status and the cursor.
    func disconnectFromHealth() {
        APIKeyStore.delete()
        status = SyncStatus()
        Self.saveStatus(status)
        UserDefaults.standard.removeObject(forKey: Self.cursorKey)
        lastAttempt = nil
    }

    /// One full sync, writing into `context` (the view's main-actor context,
    /// so `@Query`-driven screens update in place). `source == nil` means no
    /// outside facts: Diet can't be graded, Workout only by steps.
    func run(source: (any HabitFactsSource)?, in context: ModelContext, reason: RunReason = .developer) async {
        guard !isRunning else { return }
        isRunning = true
        defer {
            isRunning = false
            // bt-0020 — the window taken at a tap is held until the run
            // that carries the tap is over (or a newer tap is waiting).
            if pendingTap == nil { releaseBackgroundWindow() }
        }

        // bt-0020 — a run that starts now carries every tap saved so far
        // (the tick list is built below, before any network call), so a
        // waiting quiet sync is no longer needed.
        pendingTap?.cancel()
        pendingTap = nil
        pendingTapContext = nil
        runsSinceLaunch += 1
        let startedAt = Date()

        var report = Report(finished: Date(), sourceName: source?.displayName ?? "No source (steps only)", reason: reason)
        let today = calendar.startOfDay(for: Date())
        let habits = allHabits(in: context)
        var touched: [(Habit, Date)] = []
        let canWrite = Self.isGradingDevice
        if !canWrite {
            report.lines.append("This device doesn't grade (iPhone only) — showing, not writing")
        }
        let isLive = source?.isLive ?? false

        // bt-0029 — once, on the iPhone: the steps-only Workout days the app
        // graded as Partial before Active day existed take the new state.
        if canWrite && !UserDefaults.standard.bool(forKey: Self.activeDayConvertedKey) {
            let converted = HabitStore.convertAutoWorkoutPartials(habits: habits, in: context)
            UserDefaults.standard.set(true, forKey: Self.activeDayConvertedKey)
            report.lines.append("Active day: \(converted) automatic Workout day\(converted == 1 ? "" : "s") recoloured")
        }

        // A transport / key failure anywhere stops the later network steps
        // and keeps the cursor and status from advancing.
        var transportFailed = false
        var keyRejected = false
        func failed(_ step: String, _ error: Error) {
            transportFailed = true
            if let clientError = error as? DustinHealthClient.ClientError, clientError.isAuthFailure {
                keyRejected = true
            }
            report.errors.append("\(step): \(error.localizedDescription)")
        }

        // 2. op=sync — the habit list, targets, time zone and today's taps.
        if let source {
            let payload = Self.payload(habits: habits, today: today, timeZone: TimeZone.current.identifier)
            do {
                let reply = try await source.sync(payload)
                // bt-0020 — the run's START, so a tap that landed while this
                // run was going is still newer and still "waiting".
                Self.lastSentAt = startedAt
                let tickCount = payload.tickedDays.values.reduce(0) { $0 + $1.count }
                report.lines.append("Sent \(payload.habits.count) habits, \(payload.targets.count) targets, \(tickCount) ticks over \(payload.tickedDays.count) days")
                // dh skips a bad day (future, > 14 days old, malformed) and
                // says so instead of failing; the app only sends the last 7,
                // so this should never fire — if it does, it shows as a problem.
                if !reply.skippedDays.isEmpty {
                    report.errors.append("dh skipped tick days: \(reply.skippedDays.joined(separator: ", "))")
                }
                var heldAny = false
                for key in reply.heldTargets {
                    guard let value = reply.targets[key],
                          let habit = habits.first(where: { $0.gradingKind == key.gradingKind }) else { continue }
                    if habit.target(for: key) != value {
                        habit.setTarget(key, to: value)
                        heldAny = true
                    }
                    report.lines.append("\(habit.name ?? "?"): \(key.title) held by dh → \(value.formatted()) (voice wins)")
                }
                if heldAny { try? context.save() }
            } catch {
                failed("Sync", error)
            }
        }

        // 3. op=changes — past days whose facts moved since the last run.
        var changedDays: [Date] = []
        var newCursor: String?
        if let source, !transportFailed {
            do {
                let since = isLive ? UserDefaults.standard.string(forKey: Self.cursorKey) : nil
                let changes = try await source.changedDays(since: since)
                changedDays = changes.days.map { calendar.startOfDay(for: $0) }.filter { $0 <= today }
                newCursor = changes.nextSince
                if changedDays.isEmpty {
                    report.lines.append("No changed days")
                } else {
                    report.lines.append("Changed days: " + changedDays.map(Self.shortDay).joined(separator: ", "))
                }
            } catch {
                failed("Changes", error)
            }
        }

        // 4. Inbox → through the tap write path (voice rows), before grading
        //    so "back to auto" is re-graded in this same run.
        var appliedIDs: [String] = []
        var unapplied: [UnappliedAction] = []
        var inboxFetched = false
        /// A voice tick / untick / grade landed this run, so the tick lists
        /// sent in step 2 are already stale (step 7 sends them again).
        var inboxChangedTicks = false
        if let source, !transportFailed {
            do {
                let actions = try await source.pendingActions()
                inboxFetched = true
                for action in actions {
                    let day = calendar.startOfDay(for: action.day)
                    guard day <= today else {
                        unapplied.append(UnappliedAction(id: action.id, title: action.title, reason: "dated in the future"))
                        continue
                    }
                    guard canWrite else {
                        report.lines.append("Inbox: “\(action.title)” left for the iPhone")
                        continue
                    }
                    switch applyInbox(action, on: day, habits: habits, in: context) {
                    case .applied(let habit, let line):
                        report.lines.append(line)
                        appliedIDs.append(action.id)
                        if let habit { touched.append((habit, day)) }
                        switch action.kind {
                        case .tick, .untick, .setGrade: inboxChangedTicks = true
                        case .note, .setTarget: break
                        }
                    case .skipped(let reason):
                        report.lines.append("Not applied: \(action.title) — \(reason)")
                        unapplied.append(UnappliedAction(id: action.id, title: action.title, reason: reason))
                    }
                }
                if actions.isEmpty {
                    report.lines.append("Inbox empty")
                }
                if !appliedIDs.isEmpty {
                    let ack = try await source.confirmApplied(appliedIDs)
                    report.lines.append("Confirmed \(ack.applied) to dh")
                    for miss in ack.notApplied {
                        report.errors.append("dh did not mark \(miss.id.prefix(8)) applied: \(miss.reason)")
                    }
                }
            } catch {
                failed("Inbox", error)
            }
        }

        // 5. Which days each graded habit needs, then steps + facts for them.
        var daysByHabit: [UUID: [Date]] = [:]
        var allDays = Set<Date>()
        for habit in habits where habit.isAutoGraded {
            guard let since = habit.gradingSince, let habitID = habit.id else { continue }
            let days = Self.daysToGrade(since: since, today: today, changedDays: changedDays, calendar: calendar)
            daysByHabit[habitID] = days
            allDays.formUnion(days)
        }
        // Steps for the lookback window regardless (the report shows today's).
        for offset in 0..<Self.lookbackDays {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) { allDays.insert(day) }
        }

        var stepsByDay: [Date: Int] = [:]
        // bt-0023 — the day's burn from Health rides on the Workout row too.
        var burnByDay: [Date: HealthBurn] = [:]
        var readsHealth = HealthSteps.isAvailable
        #if DEBUG
        if testOverride != nil { readsHealth = false }
        #endif
        if readsHealth {
            do {
                try await HealthSteps.shared.requestAuthorization()
                for day in allDays.sorted() {
                    stepsByDay[day] = try await HealthSteps.shared.steps(on: day)
                    burnByDay[day] = try await HealthSteps.shared.burn(on: day)
                }
                report.stepsToday = stepsByDay[today]
            } catch {
                report.errors.append("Steps: \(error.localizedDescription)")
            }
        } else {
            report.errors.append("Steps: Health data not available on this device")
        }
        #if DEBUG
        // bt-0023 — under the fake source the simulator has no Health
        // samples, so the fake supplies a burn too: 100 active + 1,500
        // resting. Smaller than the fake session's 212 active cal on
        // purpose, so the sessions-over-Health warning is forced on screen.
        if source is FakeHealthFacts {
            for day in allDays { burnByDay[day] = HealthBurn(activeKcal: 100, restingKcal: 1_500) }
        }
        #endif

        // `nil` = facts not loaded (no source, or the fetch failed): rows
        // are then left exactly as they are.
        var factsByDay: [Date: DayFacts]?
        if let source, !transportFailed {
            let needed = Set(daysByHabit.values.flatMap { $0 })
            var collected: [Date: DayFacts] = [:]
            var ok = true
            for range in DustinHealthWire.ranges(of: needed, calendar: calendar) {
                do {
                    collected.merge(try await source.facts(from: range.from, to: range.to)) { _, new in new }
                } catch {
                    failed("Facts", error)
                    ok = false
                    break
                }
            }
            if ok { factsByDay = collected }
        }

        // Grade every habit-day.
        var newLive: [UUID: LiveFacts] = [:]
        var newLiveHealth: [UUID: HealthSnapshot] = [:]
        for habit in habits where habit.isAutoGraded {
            guard let kind = habit.gradingKind, let habitID = habit.id, let days = daysByHabit[habitID] else { continue }
            for day in days {
                let facts = factsByDay?[day]
                let steps = Self.isGradingDevice ? stepsByDay[day] : nil
                let burn = Self.isGradingDevice ? burnByDay[day] : nil
                let isToday = day == today
                let grade = Self.grade(kind: kind, targets: habit.gradingTargets, facts: facts, steps: steps, isToday: isToday)
                let snapshot = Self.snapshot(kind: kind, facts: facts, steps: steps, burn: burn)

                if isToday {
                    newLive[habitID] = LiveFacts(proteinGrams: facts?.proteinGrams, calories: facts?.calories,
                                                 workoutMinutes: facts?.workoutMinutes, steps: steps)
                    if let snapshot { newLiveHealth[habitID] = snapshot }
                }

                // bt-0021 — dh's list on the day's row (override or not),
                // only when it changed; state, source and edit time untouched.
                func writeHealth() {
                    guard canWrite, factsByDay != nil else { return }
                    if HabitStore.setHealth(for: habit, on: day, snapshot: snapshot, in: context) {
                        report.lines.append("\(habit.name ?? "?") \(Self.shortDay(day)): dh list updated")
                    }
                }

                let prefix = "\(habit.name ?? "?") \(Self.shortDay(day)): \(Self.describe(facts, steps: steps))"
                if source != nil && factsByDay == nil {
                    report.lines.append("\(prefix) → facts unavailable, left as is")
                    continue
                }
                guard Self.isKnown(kind: kind, facts: facts, grade: grade) else {
                    report.lines.append("\(prefix) → not enough known, left as is")
                    writeHealth()
                    continue
                }

                let outcome = apply(grade: grade, facts: facts, to: habit, on: day, canWrite: canWrite, in: context)
                if outcome.wrote { touched.append((habit, day)) }
                report.lines.append("\(prefix) → \(GradeWording.describe(grade)) · \(outcome.note)")
                writeHealth()
            }
        }
        liveFacts = newLive
        liveHealth = newLiveHealth

        // 6. Cleanup pass over everything this run touched, plus today for
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

        // 7. 2026-10-30 — the tick lists went up in step 2, BEFORE the inbox.
        //    Once a voice tick is confirmed (step 4's ack) dh trusts the app's
        //    list for that day — and the list it holds is from before the
        //    tick, so voice would show the habit unticked until the next run.
        //    Send the lists once more, now that the rows carry the change.
        if let source, !transportFailed, inboxChangedTicks {
            let again = Self.payload(habits: habits, today: today, timeZone: TimeZone.current.identifier)
            do {
                let reply = try await source.sync(again)
                let tickCount = again.tickedDays.values.reduce(0) { $0 + $1.count }
                report.lines.append("Sent the tick lists again after voice changes (\(tickCount) ticks)")
                if !reply.skippedDays.isEmpty {
                    report.errors.append("dh skipped tick days: \(reply.skippedDays.joined(separator: ", "))")
                }
            } catch {
                failed("Sync again", error)
            }
        }

        // Status + cursor: only a live source, only after a clean run.
        if isLive {
            if transportFailed {
                status.lastError = report.errors.first
                status.keyRejected = keyRejected
            } else {
                status.lastSuccess = Date()
                status.lastError = nil
                status.keyRejected = false
                status.lastAppliedCount = appliedIDs.count
                if inboxFetched { status.unapplied = unapplied }
                if let newCursor { UserDefaults.standard.set(newCursor, forKey: Self.cursorKey) }
            }
            Self.saveStatus(status)
        }

        report.finished = Date()
        lastReport = report
    }

    // MARK: - What the app sends

    /// How many local days of ticks go up with every run (today included).
    /// dh accepts up to 15 and refuses anything older than 14 days.
    static let tickedDaysCount = 7

    /// The sync payload, from the habit list. Kind: avoid for an avoidance
    /// habit, graded when "Graded by" is on, else simple. Reading Log habits
    /// say so, so a voice "read done, Harry Potter, 30 pages" knows where
    /// the book goes. Names that dh would see as the same (same letters and
    /// digits, case-insensitive) are sent once. Ticks: one range fetch per
    /// habit over the last `tickedDaysCount` days; every day gets a list,
    /// empty when nothing is marked.
    static func payload(habits: [Habit], today: Date, timeZone: String, calendar: Calendar = .current) -> HabitSyncPayload {
        var items: [HabitSyncPayload.HabitItem] = []
        var keys = Set<String>()
        var targets: [TargetKey: Double] = [:]
        let todayStart = calendar.startOfDay(for: today)
        let days: [Date] = (0..<tickedDaysCount).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: todayStart)
        }
        var tickedByDay: [Date: [String]] = Dictionary(uniqueKeysWithValues: days.map { ($0, []) })
        for habit in habits.sorted(by: { $0.order < $1.order }) {
            guard let name = habit.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            let key = habitKey(name)
            guard !key.isEmpty, keys.insert(key).inserted else { continue }
            let kind: String
            if habit.completionStyle == .avoidance {
                kind = "avoid"
            } else if habit.gradingKind != nil {
                kind = "graded"
            } else {
                kind = "simple"
            }
            items.append(.init(name: String(name.prefix(80)), kind: kind,
                               detailKind: habit.detailKind == .reading ? "reading_log" : nil))
            if let gradingKind = habit.gradingKind {
                let t = habit.gradingTargets
                for key in TargetKey.allCases where key.gradingKind == gradingKind && targets[key] == nil {
                    switch key {
                    case .proteinMinGrams: targets[key] = t.proteinFloorGrams
                    case .caloriesMin: targets[key] = t.calorieFloor
                    case .caloriesMax: targets[key] = t.calorieCeiling
                    case .workoutMinutesMin: targets[key] = t.workoutMinutes
                    case .stepsMin: targets[key] = t.steps
                    case .carbsMaxGrams: targets[key] = t.carbsCeilingGrams
                    case .fatMaxGrams: targets[key] = t.fatCeilingGrams
                    }
                }
            }
            if let oldest = days.first {
                let rows = HabitStore.entriesByDay(for: habit, from: oldest, to: todayStart)
                for day in days where HabitWinRule.isLogged(state: rows[day]?.effectiveCompletionState) {
                    tickedByDay[day, default: []].append(String(name.prefix(80)))
                }
            }
        }
        return HabitSyncPayload(habits: items, targets: targets, timeZone: timeZone, tickedDays: tickedByDay)
    }

    /// dh's `habit_key`: lower-case letters and digits only.
    static func habitKey(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII })
    }

    /// The days one graded habit is graded in this run: the usual window
    /// (`max(gradingSince, today − 6)…today`) plus any changed day on or
    /// after the go-live day. Sorted, unique, never before go-live.
    static func daysToGrade(since: Date, today: Date, changedDays: [Date], calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: since)
        let windowStart = max(start, calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: today) ?? today)
        var days = Set<Date>()
        var day = windowStart
        while day <= today {
            days.insert(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for changed in changedDays {
            let d = calendar.startOfDay(for: changed)
            if d >= start && d <= today { days.insert(d) }
        }
        return days.sorted()
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

    /// Whether enough is known to act on `grade` at all. A `nil` grade can
    /// mean "no colour today" (drop back — acted on) or "can't tell" (left
    /// alone). Diet needs facts; Workout needs minutes, or a grade from
    /// steps alone.
    static func isKnown(kind: GradingKind, facts: DayFacts?, grade: CompletionState?) -> Bool {
        switch kind {
        case .diet: return facts != nil
        case .workout: return facts?.workoutMinutes != nil || grade != nil
        }
    }

    /// Details an automatic Workout row carries (bt-0021 shape): the type
    /// chips lit from dh's session categories, added to any chip Dustin lit
    /// himself; the dh total as the duration; his intensity and notes kept.
    /// Session names no longer go in `types` (they live under `health`), and
    /// any left there from bt-0019 are dropped.
    static func autoDetails(for habit: Habit, facts: DayFacts?, existing: HabitEntryDetails?) -> HabitEntryDetails? {
        guard habit.detailKind == .workout, let facts, !facts.sessions.isEmpty else { return nil }
        var types: [String] = []
        var notes = ""
        var intensity = 3
        if case .workout(let t, _, let i, let n)? = existing {
            types = t.filter { WorkoutTypeChips.all.contains($0) }
            notes = n
            intensity = i
        }
        for session in facts.sessions {
            if let chip = WorkoutTypeChips.chip(forCategory: session.category), !types.contains(chip) {
                types.append(chip)
            }
        }
        // The bare number, like a hand entry ("45"): every reader — the
        // Journal row, the text and PDF exports, the Log Details chips —
        // adds the unit itself. bt-0021 stored "45 min" and the Journal
        // read "45 min min" (found in the bt-0022 simulator pass).
        let minutes = facts.workoutMinutes ?? facts.sessions.reduce(0) { $0 + $1.minutes }
        return .workout(types: types, duration: minutes > 0 ? "\(Int(minutes))" : "", intensity: intensity, notes: notes)
    }

    /// bt-0021 — what goes under the row's `health` key for this habit's
    /// kind: the sessions on a Workout habit, the meals on a Diet habit.
    /// `nil` when dh has nothing for the day (the key is then removed).
    /// Dates are cut to whole seconds so the stored copy compares equal.
    /// bt-0022 — the day's steps ride on the Workout snapshot, so a day
    /// with no session but a step count still gets a block.
    /// bt-0023 — so does the day's burn from Health (active + resting kcal).
    static func snapshot(kind: GradingKind, facts: DayFacts?, steps: Int? = nil, burn: HealthBurn? = nil) -> HealthSnapshot? {
        switch kind {
        case .workout:
            let sessions = (facts?.sessions ?? []).map {
                HealthSnapshot.Session(name: $0.name, category: $0.category, minutes: $0.minutes,
                                       sets: $0.setCount, start: HealthSnapshot.wholeSecond($0.startedAt),
                                       activeKcal: $0.activeKcal, activityType: $0.activityType)
            }
            let hasBurn = burn?.isEmpty == false
            guard !sessions.isEmpty || steps != nil || hasBurn else { return nil }
            return HealthSnapshot(sessions: sessions, steps: steps,
                                  activeBurnKcal: burn?.activeKcal, restingBurnKcal: burn?.restingKcal)
        case .diet:
            guard let facts else { return nil }
            let meals = facts.meals.map {
                HealthSnapshot.Meal(id: $0.id, name: $0.name, calories: $0.calories, protein: $0.protein,
                                    carbs: $0.carbs, fat: $0.fat, at: HealthSnapshot.wholeSecond($0.loggedAt))
            }
            return meals.isEmpty ? nil : HealthSnapshot(meals: meals)
        }
    }

    /// Today's dh list for a graded habit, for Log Details when the day has
    /// no row yet (Diet in progress, Workout before the first session).
    func liveSnapshot(for habit: Habit) -> HealthSnapshot? {
        guard let id = habit.id else { return nil }
        return liveHealth[id]
    }

    /// Writes `grade` for the day if this device may and the day's row isn't
    /// an override. `grade == nil` removes an automatic row (drop back).
    private func apply(grade: CompletionState?, facts: DayFacts?, to habit: Habit, on day: Date, canWrite: Bool, in context: ModelContext) -> (wrote: Bool, note: String) {
        let existing = HabitStore.entry(for: habit, on: day)

        // bt-0021 — only a hand / voice row WITH a grade is an override. A
        // `notDone` hand row (notes typed before the day was marked) is
        // graded over, its details kept.
        if let existing, existing.isOverride {
            return (false, "kept (\(GradeWording.describe(existing.source).lowercased()))")
        }
        guard canWrite else {
            return (false, "not written here")
        }

        switch (grade, existing) {
        case (nil, nil):
            return (false, "blank")
        case (nil, .some(let e)) where !e.isAutomatic:
            return (false, "details-only row kept")
        case (nil, .some):
            HabitStore.removeEntry(for: habit, on: day, source: .auto, in: context)
            return (true, "auto row removed")
        case (let g?, let e?) where e.effectiveCompletionState == g:
            if let details = Self.autoDetails(for: habit, facts: facts, existing: e.details), details != e.details {
                HabitStore.updateEntryDetails(for: habit, on: day, state: Int(g.rawValue), details: details, source: .auto, in: context)
                return (true, "unchanged, details updated")
            }
            return (false, "unchanged")
        case (let g?, let e):
            if let details = Self.autoDetails(for: habit, facts: facts, existing: e?.details) {
                HabitStore.updateEntryDetails(for: habit, on: day, state: Int(g.rawValue), details: details, source: .auto, in: context)
            } else {
                HabitStore.setCompletion(for: habit, on: day, state: Int(g.rawValue), source: .auto, in: context)
            }
            return (true, "written (auto)")
        }
    }

    // MARK: - Inbox

    enum InboxOutcome {
        case applied(Habit?, String)
        case skipped(String)
    }

    /// One voice action → one write (or a reason it can't be done). The
    /// app's own rules decide what a tick means for the habit's style; a
    /// note adds details and nothing else.
    func applyInbox(_ action: InboxAction, on day: Date, habits: [Habit], in context: ModelContext) -> InboxOutcome {
        if case .setTarget(let key, let value) = action.kind {
            guard let habit = habits.first(where: { $0.gradingKind == key.gradingKind }) else {
                return .skipped("no habit is graded by \(key.gradingKind.rawValue)")
            }
            habit.setTarget(key, to: value)
            try? context.save()
            return .applied(nil, "\(habit.name ?? "?"): \(key.title) → \(value.formatted()) (voice)")
        }

        guard let name = action.habitName, let habit = habit(named: name, in: habits) else {
            return .skipped("no habit named “\(action.habitName ?? "?")”")
        }
        let shown = habit.name ?? name

        switch action.kind {
        case .setTarget:
            return .skipped("unreachable")

        case .tick(let note, let book, let pages):
            let state = TickGrade.state(for: habit.completionStyle)
            HabitStore.setCompletion(for: habit, on: day, state: Int(state.rawValue), source: .voice, in: context)
            if note != nil || book != nil || pages != nil {
                HabitStore.mergeDetails(for: habit, on: day, text: note, book: book, pages: pages, in: context)
            }
            return .applied(habit, "\(shown) \(Self.shortDay(day)): ticked (\(GradeWording.describe(state)), voice)")

        case .untick:
            HabitStore.removeEntry(for: habit, on: day, source: .voice, in: context)
            return .applied(habit, "\(shown) \(Self.shortDay(day)): undone (voice)")

        case .setGrade(let grade):
            if grade == .auto {
                guard habit.isWithinGrading(day) else {
                    return .skipped("grading hasn't started for that day")
                }
                HabitStore.removeEntry(for: habit, on: day, source: .voice, in: context)
                return .applied(habit, "\(shown) \(Self.shortDay(day)): back to automatic (voice)")
            }
            guard let state = grade.completionState else { return .skipped("unknown grade") }
            if state == .rest && !habit.offersRest {
                return .skipped("Rest is only for the habit graded by Workout")
            }
            if habit.completionStyle != .multiState && state != .success {
                return .skipped("\(shown) isn't a multi-state habit")
            }
            HabitStore.setCompletion(for: habit, on: day, state: Int(state.rawValue), source: .voice, in: context)
            return .applied(habit, "\(shown) \(Self.shortDay(day)): \(GradeWording.describe(state)) (voice)")

        case .note(let text, let book, let pages):
            if HabitStore.mergeDetails(for: habit, on: day, text: text, book: book, pages: pages, in: context) {
                return .applied(habit, "\(shown) \(Self.shortDay(day)): note added to the entry")
            }
            let line = [book, pages.map { "\($0) pages" }, text].compactMap { $0 }.joined(separator: ", ")
            HabitStore.addJournalNote("\(shown): \(line)", on: day, in: context)
            return .applied(nil, "\(shown) \(Self.shortDay(day)): note added to the Journal (no entry that day)")
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
        // bt-0020 — `.auto`, not the default `.hand`: the forced run right
        // below carries this change, and a hand write here would arm the
        // quiet-sync timer AFTER that run has started (the store's hand-off
        // to `noteWrite` is a queued main-actor task, so `run`'s cancel comes
        // too early) and make Back to Auto two runs instead of one.
        HabitStore.removeEntry(for: habit, on: dayStart, source: .auto, in: context)
        await refresh(in: context, force: true, reason: .backToAuto)
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

    // MARK: - Status persistence

    private static func loadStatus() -> SyncStatus {
        guard let data = UserDefaults.standard.data(forKey: statusKey),
              let status = try? JSONDecoder().decode(SyncStatus.self, from: data) else { return SyncStatus() }
        return status
    }

    private static func saveStatus(_ status: SyncStatus) {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: statusKey)
        }
    }

    // MARK: - Lookups

    private func allHabits(in context: ModelContext) -> [Habit] {
        (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    /// dh sends the name as the app sent it; match the way dh does (letters
    /// and digits, case-insensitive) so "Cold Tub" and "cold tub" agree.
    private func habit(named name: String, in habits: [Habit]) -> Habit? {
        let wanted = Self.habitKey(name)
        guard !wanted.isEmpty else { return nil }
        return habits.first { Self.habitKey($0.name ?? "") == wanted }
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
    static let testWeedName = "Test Weed"
    static let testHabitNames = [testDietName, testWorkoutName, testSaunaName, testWeedName]

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
        await run(source: FakeHealthFacts(), in: context, reason: .developer)
    }

    /// Creates Test Diet (graded by diet), Test Workout (graded by workout),
    /// Test Sauna (simple) and Test Weed (avoidance, bt-0019) if missing,
    /// go-live today. Run from ONE device and let CloudKit carry them to
    /// the other — two devices creating them at once would make two sets.
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
            order += 1
            inserted = true
        }
        if habit(named: Self.testWeedName, in: habits) == nil {
            context.insert(Habit(name: Self.testWeedName, color: TestHabitHex.failed, icon: "leaf.fill",
                                 frequency: "daily", startDate: start, order: order, completionStyle: .avoidance))
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
        liveHealth = [:]

        let habits = allHabits(in: context)
        for name in Self.testHabitNames {
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
        for name in Self.testHabitNames {
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
