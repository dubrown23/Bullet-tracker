//
//  HealthSteps.swift
//  Bullet Tracker
//
//  bt-0017. Step counts from Apple Health. The phone has them, so the app
//  reads them itself; bt-0018 uses them for the Workout "Partial" rule and the
//  live caption on Today. bt-0028: Apple Watch steps only, and `HealthCopy`
//  copies the same per-day number to dh.
//
//  bt-0023 — calories burned, read the same way: Active Energy + Resting
//  (Basal) Energy per local day, added up = the day's total burn, exactly the
//  number the Fitness app shows. The daily burn is Apple Health's total and
//  nothing else: dh's per-session active calories are already inside it and
//  are never added on top.
//
//  Runs in the app process only: widget extensions cannot use HealthKit.
//  The simulator has no samples, so this is a device-only check.
//

import Foundation
import HealthKit

/// One local day's calories burned from Apple Health. `nil` = Health had no
/// samples for that day (a dash, never 0).
struct HealthBurn: Equatable, Sendable {
    var activeKcal: Double?
    var restingKcal: Double?

    /// Active + resting; `nil` when neither is known.
    var totalKcal: Double? {
        switch (activeKcal, restingKcal) {
        case (nil, nil): return nil
        case (let a, let r): return (a ?? 0) + (r ?? 0)
        }
    }

    var isEmpty: Bool { activeKcal == nil && restingKcal == nil }
}

actor HealthSteps {
    static let shared = HealthSteps()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private let restingEnergyType = HKQuantityType(.basalEnergyBurned)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks once for read access to steps and the two energy types. Harmless
    /// to call again; the system only shows the sheet for types it hasn't
    /// asked about yet (bt-0023 added the two energy types, so one more sheet).
    ///
    /// Bounded (bt-0018): if the permission sheet can't be shown or isn't
    /// answered, this returns after `timeout` instead of holding the whole
    /// sync run (and its `isRunning` flag) hostage. The queries that follow
    /// simply report 0 / nil / an error until access is granted.
    func requestAuthorization(timeout: Duration = .seconds(10)) async throws {
        let store = self.store
        let types: Set<HKObjectType> = [stepType, activeEnergyType, restingEnergyType]
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await store.requestAuthorization(toShare: [], read: types)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
            }
            // Whichever finishes first wins; the other is cancelled.
            try await group.next()
            group.cancelAll()
        }
    }

    /// The Apple Watch's steps for the current local day.
    func stepsToday() async throws -> Int {
        try await steps(on: Date())
    }

    /// bt-0028 — the Apple Watch's steps for the local day containing `day`.
    /// Watch only (Dustin, 2026-11-10): Pedometer++ shows the Watch's count,
    /// and dh gets this same number, so one day never has two step numbers.
    func steps(on day: Date) async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = Self.watchOnly(HKQuery.predicateForSamples(withStart: start, end: end))
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum
        )
        let sum = try await query.result(for: store)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
        return Int(sum.rounded())
    }

    /// bt-0028 — the Apple Watch's steps per local day from `from` through
    /// the day containing `to`, in one query. A day the Watch recorded
    /// nothing is left out (never 0, never another source).
    func watchStepsByDay(from: Date, to: Date) async throws -> [Date: Int] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) ?? to
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: stepType,
                predicate: Self.watchOnly(HKQuery.predicateForSamples(withStart: start, end: end))
            ),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        var byDay: [Date: Int] = [:]
        for stats in try await query.result(for: store).statistics() {
            guard let sum = stats.sumQuantity()?.doubleValue(for: .count()) else { continue }
            byDay[calendar.startOfDay(for: stats.startDate)] = Int(sum.rounded())
        }
        return byDay
    }

    /// Narrows a predicate to samples an Apple Watch recorded.
    private static func watchOnly(_ predicate: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            predicate,
            HKQuery.predicateForObjects(withDeviceProperty: HKDevicePropertyKeyModel, allowedValues: ["Watch"]),
        ])
    }

    /// bt-0023 — Active Energy and Resting Energy for the local day containing
    /// `day`, in kilocalories. A type with no samples that day reads `nil`.
    func burn(on day: Date) async throws -> HealthBurn {
        let active = try await cumulativeSum(of: activeEnergyType, on: day, unit: .kilocalorie())
        let resting = try await cumulativeSum(of: restingEnergyType, on: day, unit: .kilocalorie())
        return HealthBurn(activeKcal: active.map { $0.rounded() }, restingKcal: resting.map { $0.rounded() })
    }

    /// One statistics query: the cumulative sum of `type` over the local day.
    /// `nil` when Health has no samples of that type for the day.
    private func cumulativeSum(of type: HKQuantityType, on day: Date, unit: HKUnit) async throws -> Double? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples = HKSamplePredicate.quantitySample(type: type, predicate: range)
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: .cumulativeSum)
        return try await query.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
    }
}
