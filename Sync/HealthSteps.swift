//
//  HealthSteps.swift
//  Bullet Tracker
//
//  bt-0017. Step counts from Apple Health. Steps never pass through
//  dustin-health — the phone has them, so the app reads them itself. bt-0018
//  uses them for the Workout "Partial" rule and the live caption on Today.
//
//  Runs in the app process only: widget extensions cannot use HealthKit.
//  The simulator has no step samples, so this is a device-only check.
//

import Foundation
import HealthKit

actor HealthSteps {
    static let shared = HealthSteps()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks once for read access to step count. Harmless to call again;
    /// the system only shows the sheet the first time.
    ///
    /// Bounded (bt-0018): if the permission sheet can't be shown or isn't
    /// answered, this returns after `timeout` instead of holding the whole
    /// sync run (and its `isRunning` flag) hostage. The step query that
    /// follows simply reports 0 / an error until access is granted.
    func requestAuthorization(timeout: Duration = .seconds(10)) async throws {
        let store = self.store
        let stepType = self.stepType
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await store.requestAuthorization(toShare: [], read: [stepType])
            }
            group.addTask {
                try await Task.sleep(for: timeout)
            }
            // Whichever finishes first wins; the other is cancelled.
            try await group.next()
            group.cancelAll()
        }
    }

    /// Sum of step samples for the current local day, as the Health app
    /// shows it (HealthKit merges iPhone + Watch sources in the sum).
    func stepsToday() async throws -> Int {
        try await steps(on: Date())
    }

    /// Sum of step samples for the local day containing `day`.
    func steps(on day: Date) async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples = HKSamplePredicate.quantitySample(type: stepType, predicate: range)
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: .cumulativeSum)

        let sum = try await query.result(for: store)?
            .sumQuantity()?
            .doubleValue(for: .count()) ?? 0
        return Int(sum.rounded())
    }
}
