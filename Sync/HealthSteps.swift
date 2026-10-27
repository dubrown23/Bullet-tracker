//
//  HealthSteps.swift
//  Bullet Tracker
//
//  bt-0017. Today's step count from Apple Health. Steps never pass through
//  dustin-health — the phone has them, so the app reads them itself (Step 2
//  uses them for the Workout "Partial" rule; Step 0 only displays them).
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
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    /// Sum of step samples for the current local day, as the Health app
    /// shows it (HealthKit merges iPhone + Watch sources in the sum).
    func stepsToday() async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let today = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples = HKSamplePredicate.quantitySample(type: stepType, predicate: today)
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: .cumulativeSum)

        let sum = try await query.result(for: store)?
            .sumQuantity()?
            .doubleValue(for: .count()) ?? 0
        return Int(sum.rounded())
    }
}
