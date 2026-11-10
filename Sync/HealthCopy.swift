//
//  HealthCopy.swift
//  Bullet Tracker
//
//  bt-0027. Bullet is the only thing that reads Apple Health; it copies what
//  dh needs, so Claude voice talks to dh only (since ~Nov 4 the Claude app
//  turns off dh for the rest of a chat once it has read Apple Health).
//
//  What goes: every workout from 2026-10-28 on, plus every heart-rate reading
//  inside each workout (dh works out zone minutes from them). Sent to dh's
//  `op=health` in chunks of ≤ 50 workouts / ≤ 5,000 samples. dh never doubles
//  anything, so a re-send is always safe.
//
//  "New" = Apple's anchored query on workouts. The anchor (HealthKit's
//  bookmark) is saved only after dh has answered every chunk of a run; a
//  failed run leaves it alone and the next run sends the same workouts again.
//
//  When: on every app open (beside the habit sync, never inside it) and when
//  HealthKit wakes the app in the background for a new workout (observer
//  query + background delivery, registered at launch). Health can't be read
//  while the phone is locked, so a locked wake-up finds nothing and the next
//  wake-up or open retries. iPhone with the key only; the iPad never calls dh.
//
//  Workout duration is Apple's own (pauses left out), Dustin's call A
//  2026-11-09; dh loosened its "within 5 s of end − start" check for it.
//
//  bt-0028 (dh-0034): every run also sends the Apple Watch's steps for
//  yesterday + today and Oura's nights woken on in the last 3 days (dh keeps
//  the newest count and replaces a re-sent night). The first run, and "Send
//  all again", send the backlog: every day and night back up to 400 days.
//  A new Oura night wakes the app like a new workout does. Rules for nights
//  in `HealthDaily.swift`.
//

import Foundation
import HealthKit
import Observation
import UIKit

@MainActor
@Observable
final class HealthCopy {
    static let shared = HealthCopy()

    enum RunReason: String, Codable, Sendable {
        case appOpened
        case backgroundWake
        case sendAllAgain

        var label: String {
            switch self {
            case .appOpened: "app opened"
            case .backgroundWake: "background wake-up"
            case .sendAllAgain: "send all again"
            }
        }
    }

    /// What Settings → Dustin's Health shows. Kept on disk so a background
    /// send is still visible the next time the app is opened.
    struct Status: Codable, Equatable {
        struct Refused: Codable, Equatable, Identifiable {
            var id: String { "\(kind)·\(appleUUID ?? "?")·\(reason)" }
            var kind: String            // "workout" / "reading" / "steps day" / "sleep night"
            var appleUUID: String?      // the day (YYYY-MM-DD) for steps and sleep
            var reason: String
        }

        /// Last run that sent something and got dh's answer.
        var lastSentAt: Date?
        var lastSentReason: RunReason?
        var workoutsNew = 0
        var workoutsHad = 0
        var samplesNew = 0
        var samplesHad = 0
        /// bt-0028. Optional so a status saved before steps + sleep still loads.
        var stepsSaved: Int?
        var stepsOlderIgnored: Int?
        var sleepSaved: Int?
        var sleepUnchanged: Int?
        var refused: [Refused] = []
        /// Last run that finished, sent or not ("nothing new" counts).
        var lastCheckAt: Date?
        var lastCheckReason: RunReason?
        /// Why the last run stopped, if it did; cleared by the next clean run.
        var lastError: String?
    }

    /// First run reaches back to here (Dustin, 2026-11-09).
    static let firstDay: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        return Calendar.current.date(from: components) ?? .distantPast
    }()

    nonisolated static let maxWorkoutsPerSend = 50
    nonisolated static let maxSamplesPerSend = 5000

    private(set) var status: Status
    private(set) var isRunning = false

    private let store = HKHealthStore()
    private var observerStarted = false

    private static let statusKey = "healthCopyStatus"
    private static let anchorKey = "healthCopyWorkoutAnchor"
    /// bt-0028 — set once the steps + sleep backlog has been answered.
    private static let dailyBacklogKey = "healthCopyDailyBacklogDone"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.statusKey),
           let saved = try? JSONDecoder().decode(Status.self, from: data) {
            status = saved
        } else {
            status = Status()
        }
    }

    /// Same rule as the habit sync: only the iPhone, and only with the key.
    static var canSend: Bool {
        HabitSyncEngine.isGradingDevice && HKHealthStore.isHealthDataAvailable() && APIKeyStore.hasKey
    }

    // MARK: - Background wake-up

    /// Called at launch (Apple requires the observer to be set up before
    /// launch finishes, or a background wake-up has nothing to call). Asks
    /// HealthKit to wake the app as soon as a new workout or night of sleep
    /// lands (bt-0028 added sleep).
    func startBackgroundDelivery() {
        guard Self.canSend, !observerStarted else { return }
        observerStarted = true
        for type in [HKObjectType.workoutType(), HKCategoryType(.sleepAnalysis)] {
            observe(type)
        }
    }

    private func observe(_ type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
            // HealthKit waits for `completionHandler` before it will wake the
            // app again; call it once the run is over, success or not.
            nonisolated(unsafe) let done = completionHandler
            guard error == nil else { done(); return }
            Task { @MainActor in
                let isBackground = UIApplication.shared.applicationState == .background
                await HealthCopy.shared.run(reason: isBackground ? .backgroundWake : .appOpened)
                done()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    // MARK: - Run

    /// One full pass: read what's new, send it, save the bookmark. A run
    /// already going makes a second call a no-op (the first one will pick
    /// everything up).
    func run(reason: RunReason) async {
        guard Self.canSend, !isRunning, let key = APIKeyStore.read() else { return }
        isRunning = true
        defer { isRunning = false }

        // Keep going if the app leaves the screen mid-send.
        var window = UIBackgroundTaskIdentifier.invalid
        window = UIApplication.shared.beginBackgroundTask(withName: "Copy Apple Health to dh") {
            UIApplication.shared.endBackgroundTask(window)
            window = .invalid
        }
        defer {
            if window != .invalid { UIApplication.shared.endBackgroundTask(window) }
        }

        do {
            // The permission sheet can only show in the foreground; a
            // background wake-up runs with whatever was granted.
            if reason != .backgroundWake {
                try await store.requestAuthorization(toShare: [], read: Self.readTypes)
                startBackgroundDelivery()
            }

            let savedAnchor = reason == .sendAllAgain ? nil : UserDefaults.standard.data(forKey: Self.anchorKey)
            let batch = try await Self.readNew(store: store, anchorData: savedAnchor, since: Self.firstDay)

            // bt-0028: steps + sleep. The backlog once (and on Send all
            // again); otherwise the last few days, re-sent every run.
            let backlog = reason == .sendAllAgain || !UserDefaults.standard.bool(forKey: Self.dailyBacklogKey)
            let daily = try await Self.readDaily(store: store, backlog: backlog)

            var client = DustinHealthClient(key: key)
            client.timeout = 60
            var totals = Status()
            for request in Self.chunks(batch.items) {
                let reply = try await client.health(request)
                totals.workoutsNew += reply.workouts.new
                totals.workoutsHad += reply.workouts.already_had
                totals.samplesNew += reply.samples.new
                totals.samplesHad += reply.samples.already_had
                totals.refused += (reply.workouts.refused ?? []).map {
                    Status.Refused(kind: "workout", appleUUID: $0.apple_uuid, reason: $0.reason)
                }
                totals.refused += (reply.samples.refused ?? []).map {
                    Status.Refused(kind: "reading", appleUUID: $0.apple_uuid, reason: $0.reason)
                }
            }
            let dailySends = HealthDaily.sends(steps: daily.steps, sleep: daily.sleep)
            for request in dailySends {
                let reply = try await client.health(request)
                totals.stepsSaved = (totals.stepsSaved ?? 0) + (reply.steps?.saved ?? 0)
                totals.stepsOlderIgnored = (totals.stepsOlderIgnored ?? 0) + (reply.steps?.older_ignored ?? 0)
                totals.sleepSaved = (totals.sleepSaved ?? 0) + (reply.sleep?.saved ?? 0)
                totals.sleepUnchanged = (totals.sleepUnchanged ?? 0) + (reply.sleep?.unchanged ?? 0)
                totals.refused += (reply.steps?.refused ?? []).map {
                    Status.Refused(kind: "steps day", appleUUID: $0.day, reason: $0.reason)
                }
                totals.refused += (reply.sleep?.refused ?? []).map {
                    Status.Refused(kind: "sleep night", appleUUID: $0.woke_on, reason: $0.reason)
                }
            }

            if !batch.items.isEmpty || !dailySends.isEmpty {
                status.lastSentAt = Date()
                status.lastSentReason = reason
                status.workoutsNew = totals.workoutsNew
                status.workoutsHad = totals.workoutsHad
                status.samplesNew = totals.samplesNew
                status.samplesHad = totals.samplesHad
                status.stepsSaved = totals.stepsSaved
                status.stepsOlderIgnored = totals.stepsOlderIgnored
                status.sleepSaved = totals.sleepSaved
                status.sleepUnchanged = totals.sleepUnchanged
                status.refused = totals.refused
            }
            if backlog { UserDefaults.standard.set(true, forKey: Self.dailyBacklogKey) }

            // Every chunk answered (or nothing to send): move the bookmark.
            if let newAnchor = batch.anchorData {
                UserDefaults.standard.set(newAnchor, forKey: Self.anchorKey)
            }
            status.lastError = nil
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            status.lastError = "Phone was locked; Health can't be read until it's unlocked. Will retry."
        } catch {
            status.lastError = error.localizedDescription
        }
        status.lastCheckAt = Date()
        status.lastCheckReason = reason
        saveStatus()
    }

    private func saveStatus() {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: Self.statusKey)
        }
    }

    // MARK: - Reading Health

    nonisolated private static let heartRate = HKQuantityType(.heartRate)
    nonisolated private static let activeEnergy = HKQuantityType(.activeEnergyBurned)

    /// Distance types a workout may carry; the first one with a total wins.
    nonisolated private static let distanceTypes: [HKQuantityType] = [
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.distanceSkatingSports),
        HKQuantityType(.distanceRowing),
        HKQuantityType(.distancePaddleSports),
        HKQuantityType(.distanceCrossCountrySkiing),
        HKQuantityType(.distanceDownhillSnowSports),
        HKQuantityType(.distanceWheelchair),
    ]

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(), heartRate, activeEnergy,
            HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis),
        ]
        for type in distanceTypes { types.insert(type) }
        return types
    }

    /// One workout and its heart-rate readings, in dh's shape.
    struct Item: Equatable, Sendable {
        var workout: DustinHealthClient.HealthRequest.Workout
        var samples: [DustinHealthClient.HealthRequest.Sample]
    }

    struct Batch: Sendable {
        var items: [Item]
        /// The new bookmark, archived; saved by `run` only after dh answers.
        var anchorData: Data?
    }

    struct Daily: Sendable {
        var steps: [DustinHealthClient.HealthRequest.StepsDay]
        var sleep: [DustinHealthClient.HealthRequest.SleepNight]
    }

    /// bt-0028 — Watch steps per day and Oura nights. Backlog: the last
    /// `HealthDaily.backlogDays` days; otherwise steps for yesterday + today
    /// and nights woken on in the last 3 days.
    private static func readDaily(store: HKHealthStore, backlog: Bool) async throws -> Daily {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let stepsFrom = calendar.date(byAdding: .day, value: backlog ? -(HealthDaily.backlogDays - 1) : -1, to: today) ?? today
        let sleepFrom = calendar.date(byAdding: .day, value: backlog ? -(HealthDaily.backlogDays - 1) : -2, to: today) ?? today

        let countedAt = isoString(now)
        let steps = try await HealthSteps.shared.watchStepsByDay(from: stepsFrom, to: now)
            .sorted { $0.key < $1.key }
            .map { DustinHealthClient.HealthRequest.StepsDay(day: DustinHealthWire.string(from: $0.key), count: $0.value, counted_at: countedAt) }
        let sleep = try await HealthDaily.ouraNights(store: store, from: sleepFrom).map(HealthDaily.wire)
        return Daily(steps: steps, sleep: sleep)
    }

    /// Workouts added since the bookmark (all from `since` when there is
    /// none), each with every heart-rate reading between its start and end.
    nonisolated private static func readNew(store: HKHealthStore, anchorData: Data?, since: Date) async throws -> Batch {
        let anchor = anchorData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }
        let fromFirstDay = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let query = HKAnchoredObjectQueryDescriptor(
            predicates: [.workout(fromFirstDay)],
            anchor: anchor
        )
        let result = try await query.result(for: store)
        let newAnchorData = try? NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true)

        var items: [Item] = []
        for workout in result.addedSamples.sorted(by: { $0.startDate < $1.startDate }) {
            let readings = try await heartRateReadings(store: store, from: workout.startDate, to: workout.endDate)
            items.append(Item(workout: wire(workout), samples: readings))
        }
        return Batch(items: items, anchorData: newAnchorData)
    }

    nonisolated private static func heartRateReadings(store: HKHealthStore, from start: Date, to end: Date) async throws -> [DustinHealthClient.HealthRequest.Sample] {
        let inside = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRate, predicate: inside)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return try await query.result(for: store).map { reading in
            DustinHealthClient.HealthRequest.Sample(
                apple_uuid: reading.uuid.uuidString,
                kind: HKQuantityTypeIdentifier.heartRate.rawValue,
                start_time: isoString(reading.startDate),
                end_time: isoString(reading.endDate),
                value: reading.quantity.doubleValue(for: bpm),
                unit: "count/min",
                source_device: reading.device?.name
            )
        }
    }

    nonisolated private static func wire(_ workout: HKWorkout) -> DustinHealthClient.HealthRequest.Workout {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let hr = workout.statistics(for: heartRate)
        let distance = distanceTypes.lazy
            .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
            .first
        let code = Int(workout.workoutActivityType.rawValue)
        return DustinHealthClient.HealthRequest.Workout(
            apple_uuid: workout.uuid.uuidString,
            activity_type: activityName(code: code),
            activity_code: code,
            start_time: isoString(workout.startDate),
            end_time: isoString(workout.endDate),
            duration_seconds: workout.duration,
            active_energy_kcal: workout.statistics(for: activeEnergy)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
            distance_m: distance,
            average_heart_rate_bpm: hr?.averageQuantity()?.doubleValue(for: bpm),
            minimum_heart_rate_bpm: hr?.minimumQuantity()?.doubleValue(for: bpm),
            maximum_heart_rate_bpm: hr?.maximumQuantity()?.doubleValue(for: bpm),
            source_device: workout.device?.name,
            source_bundle_identifier: workout.sourceRevision.source.bundleIdentifier
        )
    }

    // MARK: - Pure pieces (unit-tested)

    /// Exact time with the phone's own zone, e.g. 2026-11-09T06:02:13.402-05:00.
    nonisolated static func isoString(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// Splits the backlog into sends dh accepts: ≤ `maxWorkouts` workouts and
    /// ≤ `maxSamples` readings each. A workout goes in the send that carries
    /// its first readings; a long workout's readings run on into the next.
    nonisolated static func chunks(
        _ items: [Item],
        maxWorkouts: Int = maxWorkoutsPerSend,
        maxSamples: Int = maxSamplesPerSend
    ) -> [DustinHealthClient.HealthRequest] {
        var sends: [DustinHealthClient.HealthRequest] = []
        var current = DustinHealthClient.HealthRequest(workouts: [], samples: [])

        func flush() {
            if !current.workouts.isEmpty || !current.samples.isEmpty { sends.append(current) }
            current = DustinHealthClient.HealthRequest(workouts: [], samples: [])
        }

        for item in items {
            if current.workouts.count >= maxWorkouts || current.samples.count >= maxSamples { flush() }
            current.workouts.append(item.workout)
            var remaining = item.samples[...]
            while !remaining.isEmpty {
                let room = maxSamples - current.samples.count
                if room <= 0 { flush(); continue }
                current.samples.append(contentsOf: remaining.prefix(room))
                remaining = remaining.dropFirst(room)
            }
        }
        flush()
        return sends
    }

    /// The name dh's table gives an Apple workout code (dh
    /// `lib/apple-health-activity-types.js`: Apple's identifier, spaced and
    /// capitalised — "functionalStrengthTraining" → "Functional Strength
    /// Training"). dh refuses a workout whose name and code disagree, so
    /// Bullet uses dh's table, not its own wording. Unknown code → `nil`
    /// (the name is left out; dh goes by the code).
    nonisolated static func activityName(code: Int) -> String? {
        guard let identifier = activityIdentifiers[code] else { return nil }
        var name = ""
        var previous: Character?
        for character in identifier {
            if character.isUppercase, let p = previous, p.isLowercase || p.isNumber {
                name.append(" ")
            }
            name.append(character)
            previous = character
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Copied from dh's `HK_WORKOUT_ACTIVITY_TYPES` (Apple's raw values).
    nonisolated static let activityIdentifiers: [Int: String] = [
        1: "americanFootball", 2: "archery", 3: "australianFootball", 4: "badminton",
        5: "baseball", 6: "basketball", 7: "bowling", 8: "boxing", 9: "climbing",
        10: "cricket", 11: "crossTraining", 12: "curling", 13: "cycling", 14: "dance",
        15: "danceInspiredTraining", 16: "elliptical", 17: "equestrianSports", 18: "fencing",
        19: "fishing", 20: "functionalStrengthTraining", 21: "golf", 22: "gymnastics",
        23: "handball", 24: "hiking", 25: "hockey", 26: "hunting", 27: "lacrosse",
        28: "martialArts", 29: "mindAndBody", 30: "mixedMetabolicCardioTraining",
        31: "paddleSports", 32: "play", 33: "preparationAndRecovery", 34: "racquetball",
        35: "rowing", 36: "rugby", 37: "running", 38: "sailing", 39: "skatingSports",
        40: "snowSports", 41: "soccer", 42: "softball", 43: "squash", 44: "stairClimbing",
        45: "surfingSports", 46: "swimming", 47: "tableTennis", 48: "tennis",
        49: "trackAndField", 50: "traditionalStrengthTraining", 51: "volleyball",
        52: "walking", 53: "waterFitness", 54: "waterPolo", 55: "waterSports",
        56: "wrestling", 57: "yoga", 58: "barre", 59: "coreTraining",
        60: "crossCountrySkiing", 61: "downhillSkiing", 62: "flexibility",
        63: "highIntensityIntervalTraining", 64: "jumpRope", 65: "kickboxing",
        66: "pilates", 67: "snowboarding", 68: "stairs", 69: "stepTraining",
        70: "wheelchairWalkPace", 71: "wheelchairRunPace", 72: "taiChi", 73: "mixedCardio",
        74: "handCycling", 75: "discSports", 76: "fitnessGaming", 77: "cardioDance",
        78: "socialDance", 79: "pickleball", 80: "cooldown", 82: "swimBikeRun",
        83: "transition", 84: "underwaterDiving", 2998: "rest", 2999: "group", 3000: "other",
    ]
}
