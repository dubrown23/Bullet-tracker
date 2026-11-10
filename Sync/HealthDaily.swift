//
//  HealthDaily.swift
//  Bullet Tracker
//
//  bt-0028. Apple Watch steps per day and Oura sleep per night, shaped for
//  dh's `op=health` (dh-0034). `HealthCopy` reads and sends; the rules that
//  turn Oura's samples into nights live here, pure and unit-tested.
//
//  Oura's samples overlap in Health (the 2026-11-10 proof: a plain sum gave
//  13h 15m asleep inside an 8h 41m night). So every moment counts once: a
//  moment two stages both claim goes to deep, then REM, then core, then
//  awake. The asleep total (core + deep + REM) then matched the Oura app
//  within a minute.
//

import Foundation
import HealthKit

/// One sleep sample from Health, reduced to what a night needs.
struct SleepSlice: Equatable, Sendable {
    var start: Date
    var end: Date
    /// `HKCategoryValueSleepAnalysis` raw value.
    var value: Int
}

enum HealthDaily {
    /// Sleep comes from Oura only (Dustin, 2026-11-10).
    nonisolated static let ouraBundleID = "com.ouraring.oura"
    /// dh takes up to 400 days / 400 nights per send.
    nonisolated static let maxPerSend = 400
    /// The backlog reaches back this many days, today included.
    nonisolated static let backlogDays = 400

    /// The four stages dh stores, in the order a contested moment is given.
    enum Stage: Int, CaseIterable, Sendable {
        case deep, rem, core, awake

        init?(sleepValue: Int) {
            switch HKCategoryValueSleepAnalysis(rawValue: sleepValue) {
            case .asleepDeep: self = .deep
            case .asleepREM: self = .rem
            // dh has no "asleep, no stage"; it is sleep, so it counts as core.
            case .asleepCore, .asleepUnspecified: self = .core
            case .awake: self = .awake
            default: return nil   // in bed: sets bedtime / wake time only
            }
        }
    }

    /// One night as dh takes it.
    struct Night: Equatable, Sendable {
        var wokeOn: Date
        var bedtime: Date
        var wake: Date
        var awake: Int
        var core: Int
        var deep: Int
        var rem: Int

        var asleepMinutes: Int { core + deep + rem }
    }

    // MARK: - Nights

    /// Oura's slices → one night per day woken on. Pieces more than `maxGap`
    /// apart are separate sessions; a nap (starts 10:00 or later and ends by
    /// 20:00 the same day) is left out; the rest file under the day of their
    /// wake time + 6 h (so a piece ending 23:50 joins the next morning) and
    /// merge: first bedtime, last wake time, stages added.
    nonisolated static func nights(from slices: [SleepSlice], calendar: Calendar = .current, maxGap: TimeInterval = 2 * 3600) -> [Night] {
        var groups: [Date: [[SleepSlice]]] = [:]
        for session in sessions(slices, maxGap: maxGap) {
            guard let start = session.map(\.start).min(), let end = session.map(\.end).max(),
                  !isNap(start: start, end: end, calendar: calendar) else { continue }
            let wokeOn = calendar.startOfDay(for: end.addingTimeInterval(6 * 3600))
            groups[wokeOn, default: []].append(session)
        }
        return groups.map { wokeOn, pieces in
            var seconds: [Stage: TimeInterval] = [:]
            for piece in pieces {
                seconds.merge(stageSeconds(piece), uniquingKeysWith: +)
            }
            let minutes = wholeMinutes(seconds)
            let all = pieces.joined()
            return Night(
                wokeOn: wokeOn,
                bedtime: all.map(\.start).min() ?? wokeOn,
                wake: all.map(\.end).max() ?? wokeOn,
                awake: minutes[.awake] ?? 0,
                core: minutes[.core] ?? 0,
                deep: minutes[.deep] ?? 0,
                rem: minutes[.rem] ?? 0
            )
        }
        .sorted { $0.wokeOn < $1.wokeOn }
    }

    /// Slices sorted and cut into sessions wherever the gap since the
    /// session's latest end is more than `maxGap`.
    nonisolated static func sessions(_ slices: [SleepSlice], maxGap: TimeInterval) -> [[SleepSlice]] {
        var result: [[SleepSlice]] = []
        var latestEnd = Date.distantPast
        for slice in slices.sorted(by: { $0.start < $1.start }) {
            if result.isEmpty || slice.start.timeIntervalSince(latestEnd) > maxGap {
                result.append([slice])
                latestEnd = slice.end
            } else {
                result[result.count - 1].append(slice)
                latestEnd = max(latestEnd, slice.end)
            }
        }
        return result
    }

    nonisolated static func isNap(start: Date, end: Date, calendar: Calendar) -> Bool {
        guard calendar.isDate(start, inSameDayAs: end),
              let tenAM = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: start),
              let eightPM = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: start) else { return false }
        return start >= tenAM && end <= eightPM
    }

    /// Seconds per stage with every moment given to one stage only.
    nonisolated static func stageSeconds(_ slices: [SleepSlice]) -> [Stage: TimeInterval] {
        let staged = slices.compactMap { slice in
            Stage(sleepValue: slice.value).map { (start: slice.start, end: slice.end, stage: $0) }
        }
        let edges = Set(staged.flatMap { [$0.start, $0.end] }).sorted()
        var seconds: [Stage: TimeInterval] = [:]
        for (from, to) in zip(edges, edges.dropFirst()) {
            let claims = staged.filter { $0.start <= from && $0.end >= to }.map(\.stage)
            guard let winner = claims.min(by: { $0.rawValue < $1.rawValue }) else { continue }
            seconds[winner, default: 0] += to.timeIntervalSince(from)
        }
        return seconds
    }

    /// Whole minutes that add up to the rounded total: each stage rounded
    /// down, then the leftover minutes go to the largest remainders.
    nonisolated static func wholeMinutes(_ seconds: [Stage: TimeInterval]) -> [Stage: Int] {
        let exact = Stage.allCases.map { (stage: $0, minutes: (seconds[$0] ?? 0) / 60) }
        let total = Int(exact.reduce(0) { $0 + $1.minutes }.rounded())
        var result = Dictionary(uniqueKeysWithValues: exact.map { ($0.stage, Int($0.minutes.rounded(.down))) })
        var leftover = total - result.values.reduce(0, +)
        for item in exact.sorted(by: { $0.minutes - $0.minutes.rounded(.down) > $1.minutes - $1.minutes.rounded(.down) }) {
            guard leftover > 0 else { break }
            result[item.stage, default: 0] += 1
            leftover -= 1
        }
        return result
    }

    // MARK: - Wire

    nonisolated static func wire(_ night: Night) -> DustinHealthClient.HealthRequest.SleepNight {
        DustinHealthClient.HealthRequest.SleepNight(
            woke_on: DustinHealthWire.string(from: night.wokeOn),
            bedtime: HealthCopy.isoString(night.bedtime),
            wake_time: HealthCopy.isoString(night.wake),
            awake_minutes: night.awake,
            core_minutes: night.core,
            deep_minutes: night.deep,
            rem_minutes: night.rem
        )
    }

    /// Steps and sleep paired into sends of ≤ `max` each; either list may run
    /// out first (dh takes any one list alone).
    nonisolated static func sends(
        steps: [DustinHealthClient.HealthRequest.StepsDay],
        sleep: [DustinHealthClient.HealthRequest.SleepNight],
        max: Int = maxPerSend
    ) -> [DustinHealthClient.HealthRequest] {
        let count = Swift.max((steps.count + max - 1) / max, (sleep.count + max - 1) / max)
        return (0..<count).map { index in
            DustinHealthClient.HealthRequest(
                workouts: [],
                samples: [],
                steps: Array(steps.dropFirst(index * max).prefix(max)),
                sleep: Array(sleep.dropFirst(index * max).prefix(max))
            )
        }
    }

    // MARK: - Reading Health

    /// Oura's nights woken on from the day of `from` on. Reads from noon the
    /// day before, so the first night is whole.
    nonisolated static func ouraNights(store: HKHealthStore, from: Date, calendar: Calendar = .current) async throws -> [Night] {
        let firstDay = calendar.startOfDay(for: from)
        let readFrom = firstDay.addingTimeInterval(-12 * 3600)
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(
                type: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: readFrom, end: nil, options: .strictStartDate)
            )],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let slices = try await query.result(for: store)
            .filter { $0.sourceRevision.source.bundleIdentifier == ouraBundleID }
            .map { SleepSlice(start: $0.startDate, end: $0.endDate, value: $0.value) }
        return nights(from: slices, calendar: calendar).filter { $0.wokeOn >= firstDay }
    }
}
