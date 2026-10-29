//
//  DashboardModel.swift
//  Bullet Tracker
//
//  bt-0023 — the pure rules behind the Dashboard, kept out of the views so
//  the tests can pin them:
//
//    • `DashboardDay`    — one day like the dh website: the calorie band
//                          line, Eaten vs Burned, the driver line, the
//                          sessions-over-Health warning, the mode caption.
//    • `DashboardTrends` — the half underneath: habits won per day with a
//                          comparison to the period before, one row per
//                          habit in Today order, nutrition / training
//                          series from the stored rows.
//
//  Everything here reads `HealthSnapshot` values and `HabitEntry` rows the
//  caller already fetched; nothing touches the network or the store.
//

import Foundation

// MARK: - One day

enum DashboardDay {

    /// Whole-number formatting shared by every line ("1,840").
    static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    /// A number dh or Health doesn't know is a dash, never 0.
    static func wholeOrDash(_ value: Double?) -> String {
        value.map(whole) ?? "—"
    }

    // MARK: Calories

    /// The line under the eaten total: where the day sits against the band.
    ///   under the floor → "60 to 1,900 · 360 under 2,200"
    ///   in the band     → "In range · 160 under 2,200"
    ///   over the ceiling→ "140 over 2,200"
    ///   nothing eaten   → "—"
    static func calorieBandText(calories: Double?, floor: Double, ceiling: Double) -> String {
        guard let calories else { return "—" }
        if calories < floor {
            return "\(whole(floor - calories)) to \(whole(floor)) · \(whole(ceiling - calories)) under \(whole(ceiling))"
        }
        if calories > ceiling {
            return "\(whole(calories - ceiling)) over \(whole(ceiling))"
        }
        return "In range · \(whole(ceiling - calories)) under \(whole(ceiling))"
    }

    /// Where the eaten total sits: below, inside or above the band.
    enum BandPosition: Equatable { case none, under, inRange, over }

    static func bandPosition(calories: Double?, floor: Double, ceiling: Double) -> BandPosition {
        guard let calories else { return .none }
        if calories < floor { return .under }
        if calories > ceiling { return .over }
        return .inRange
    }

    /// The line under the burned total: "1,030 active + 2,159 resting".
    /// Only the parts Health knows; `nil` when it knows neither.
    static func burnedDetailText(active: Double?, resting: Double?) -> String? {
        var parts: [String] = []
        if let active { parts.append("\(whole(active)) active") }
        if let resting { parts.append("\(whole(resting)) resting") }
        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }

    // MARK: Driver line (the website's rule)

    enum Macro: Equatable {
        case carbs, fat
        var title: String { self == .carbs ? "carbs" : "fat" }
    }

    struct Driver: Equatable {
        let macro: Macro
        let mealName: String
        /// Grams of that macro in the meal.
        let mealGrams: Double
        /// The day's total of that macro.
        let dayGrams: Double

        /// "Burrito bowl — 74 g of your 191 g carbs"
        var text: String {
            "\(mealName) — \(DashboardDay.whole(mealGrams)) g of your \(DashboardDay.whole(dayGrams)) g \(macro.title)"
        }
    }

    /// Carbs or fat over its ceiling; the one further over by ratio; the meal
    /// with the most of that macro. `nil` when neither is over, or when no
    /// meal carries that macro.
    static func driver(meals: [HealthSnapshot.Meal], carbsCeiling: Double, fatCeiling: Double) -> Driver? {
        let carbs = sum(meals.map(\.carbs))
        let fat = sum(meals.map(\.fat))
        let carbsRatio = carbs.map { carbsCeiling > 0 ? $0 / carbsCeiling : 0 } ?? 0
        let fatRatio = fat.map { fatCeiling > 0 ? $0 / fatCeiling : 0 } ?? 0
        guard carbsRatio > 1 || fatRatio > 1 else { return nil }
        let macro: Macro = carbsRatio >= fatRatio ? .carbs : .fat
        let total = (macro == .carbs ? carbs : fat) ?? 0
        let grams: (HealthSnapshot.Meal) -> Double? = { macro == .carbs ? $0.carbs : $0.fat }
        guard let top = meals.filter({ grams($0) != nil }).max(by: { (grams($0) ?? 0) < (grams($1) ?? 0) }),
              let topGrams = grams(top), topGrams > 0 else { return nil }
        return Driver(macro: macro, mealName: top.name, mealGrams: topGrams, dayGrams: total)
    }

    // MARK: Burned, and the check that is never silent

    /// The daily burn is Apple Health's total and nothing else. The sessions'
    /// own active calories are never added to it; this check is the one place
    /// they meet: when the sessions add up to more than Health's Active
    /// Energy for the day, something is double-counted and the screen says so.
    /// Skipped when either side is unknown.
    static func sessionsExceedHealth(sessionsKcal: Double?, healthActiveKcal: Double?) -> Bool {
        guard let sessionsKcal, let healthActiveKcal else { return false }
        return sessionsKcal > healthActiveKcal
    }

    /// "Sessions add up to 612 active cal; Apple Health counted 480 for the day"
    static func warningText(sessionsKcal: Double?, healthActiveKcal: Double?) -> String? {
        guard sessionsExceedHealth(sessionsKcal: sessionsKcal, healthActiveKcal: healthActiveKcal),
              let sessionsKcal, let healthActiveKcal else { return nil }
        return "Sessions add up to \(whole(sessionsKcal)) active cal; Apple Health counted \(whole(healthActiveKcal)) for the day"
    }

    // MARK: Mode caption

    /// "Auto · in progress", "Set by you · Partial", "Auto · Done",
    /// "Auto · no grade" — the Today row's wording, for the day header.
    static func modeLine(source: EntrySource?, state: CompletionState?, isToday: Bool) -> String {
        let mode = GradeWording.mode(source ?? .auto)
        if let state, state != .notDone {
            return "\(mode) · \(GradeWording.stateWord(state))"
        }
        return "\(mode) · \(isToday ? "in progress" : "no grade")"
    }

    /// Sum of the known values; `nil` when none is known.
    static func sum(_ values: [Double?]) -> Double? {
        let known = values.compactMap { $0 }
        return known.isEmpty ? nil : known.reduce(0, +)
    }
}

// MARK: - Trends

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var days: Int { self == .week ? 7 : 30 }

    var title: String { self == .week ? "This week" : "This month" }
    var previousTitle: String { self == .week ? "last week" : "last month" }

    /// The period's days, oldest first, ending on `end`.
    func days(ending end: Date, calendar: Calendar = .current) -> [Date] {
        let last = calendar.startOfDay(for: end)
        return (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: last) }
    }
}

enum DashboardTrends {

    /// One day in the week / month bar.
    struct DayWins: Identifiable, Equatable {
        let day: Date
        /// Positive habits won that day.
        let wins: Int
        /// Positive habits scored that day (scheduled, not Rest).
        let scheduled: Int
        /// Avoidance slips that day — a mark on the day, never a point lost.
        let slips: Int
        var id: Date { day }
    }

    /// One `DayWins` per day: positive habits scored and won (the win rule),
    /// avoidance slips as marks. Rest days and unscheduled days are not
    /// scored; a slip is never a point lost (bt-0024).
    static func dayWins(habits: [Habit], entries: [UUID: [Date: HabitEntry]], days: [Date],
                        today: Date = Date(), calendar: Calendar = .current) -> [DayWins] {
        let todayStart = calendar.startOfDay(for: today)
        return days.map { day in
            let dayStart = calendar.startOfDay(for: day)
            var wins = 0, scheduled = 0, slips = 0
            for habit in habits {
                guard let id = habit.id, HabitFrequencyHelper.shouldTrack(habit, on: dayStart) else { continue }
                let state = entries[id]?[dayStart]?.effectiveCompletionState
                if HabitWinRule.isSlipScored(style: habit.completionStyle) {
                    if HabitWinRule.isSlip(style: habit.completionStyle, state: state) { slips += 1 }
                    continue
                }
                guard !HabitWinRule.isNeutral(state: state) else { continue }
                scheduled += 1
                if HabitWinRule.isWin(style: habit.completionStyle, state: state, isFuture: dayStart > todayStart) { wins += 1 }
            }
            return DayWins(day: dayStart, wins: wins, scheduled: scheduled, slips: slips)
        }
    }

    /// Wins per day over days with something scheduled; `nil` when none.
    static func averageWins(_ days: [DayWins]) -> Double? {
        let counted = days.filter { $0.scheduled > 0 }
        guard !counted.isEmpty else { return nil }
        return Double(counted.reduce(0) { $0 + $1.wins }) / Double(counted.count)
    }

    /// The most positive habits scheduled on any one day — the bar's ceiling
    /// and the "of N" in the caption.
    static func scheduledCeiling(_ days: [DayWins]) -> Int {
        days.map(\.scheduled).max() ?? 0
    }

    /// "5.1 of 8 a day · up from 4.4" (the arrow is drawn by the view).
    static func averageText(current: Double?, ceiling: Int) -> String {
        guard let current else { return "Nothing scheduled" }
        return "\(current.formatted(.number.precision(.fractionLength(1)))) of \(ceiling) a day"
    }

    enum Trend: Equatable {
        case up, down, flat

        var systemImage: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .flat: return "arrow.right"
            }
        }

        /// Spoken form for VoiceOver.
        func spoken(previousTitle: String) -> String {
            switch self {
            case .up: return "up from \(previousTitle)"
            case .down: return "down from \(previousTitle)"
            case .flat: return "same as \(previousTitle)"
            }
        }
    }

    /// Up / down / flat between two periods. Averages within a tenth count
    /// as flat so a 4.43 → 4.47 week doesn't flip the arrow.
    static func trend(current: Double?, previous: Double?) -> Trend {
        guard let current, let previous else { return .flat }
        if current > previous + 0.05 { return .up }
        if current < previous - 0.05 { return .down }
        return .flat
    }

    static func trend(current: Int, previous: Int) -> Trend {
        trend(current: Double(current), previous: Double(previous))
    }

    /// One day's value in a nutrition / training series. `nil` = no reading.
    struct Point: Identifiable, Equatable {
        let day: Date
        let value: Double?
        var id: Date { day }
    }

    struct Series: Equatable {
        let title: String
        let unit: String
        let points: [Point]
        let target: Double?
        /// Days whose value fell in `floor...ceiling`; the calories row only.
        let inBandDays: Int?

        var knownValues: [Double] { points.compactMap(\.value) }
        var average: Double? {
            let known = knownValues
            return known.isEmpty ? nil : known.reduce(0, +) / Double(known.count)
        }
        var hasData: Bool { !knownValues.isEmpty }

        /// "avg 172 g of 180" / "avg 2,040 · in band 5 of 7 days" / "avg 8,900 of 7,000".
        var summaryText: String {
            guard let average else { return "No data yet" }
            let value = unit.isEmpty ? DashboardDay.whole(average) : "\(DashboardDay.whole(average)) \(unit)"
            if let inBandDays {
                return "avg \(value) · \(inBandDays) of \(points.count) in band"
            }
            if let target {
                return "avg \(value) of \(DashboardDay.whole(target))"
            }
            return "avg \(value)"
        }
    }

    /// Protein and calories per day from the Diet rows' stored meals.
    static func nutritionSeries(dietRows: [Date: HabitEntry], days: [Date], targets: GradingTargets,
                                calendar: Calendar = .current) -> (protein: Series, calories: Series) {
        var protein: [Point] = []
        var calories: [Point] = []
        var inBand = 0
        for day in days {
            let health = dietRows[calendar.startOfDay(for: day)]?.health
            protein.append(Point(day: day, value: health?.totalProtein))
            let kcal = health?.totalCalories
            calories.append(Point(day: day, value: kcal))
            if let kcal, (targets.calorieFloor...targets.calorieCeiling).contains(kcal) { inBand += 1 }
        }
        return (Series(title: "Protein", unit: "g", points: protein, target: targets.proteinFloorGrams, inBandDays: nil),
                Series(title: "Calories", unit: "", points: calories, target: nil, inBandDays: inBand))
    }

    /// Minutes, steps and calories burned per day from the Workout rows'
    /// stored sessions and Health numbers. A day with no row has no reading.
    static func trainingSeries(workoutRows: [Date: HabitEntry], days: [Date], targets: GradingTargets,
                               calendar: Calendar = .current) -> (minutes: Series, steps: Series, burned: Series) {
        var minutes: [Point] = []
        var steps: [Point] = []
        var burned: [Point] = []
        for day in days {
            let health = workoutRows[calendar.startOfDay(for: day)]?.health
            minutes.append(Point(day: day, value: health.map(\.totalMinutes)))
            steps.append(Point(day: day, value: health?.steps.map(Double.init)))
            burned.append(Point(day: day, value: health?.totalBurnKcal))
        }
        return (Series(title: "Minutes", unit: "", points: minutes, target: targets.workoutMinutes, inBandDays: nil),
                Series(title: "Steps", unit: "", points: steps, target: targets.steps, inBandDays: nil),
                Series(title: "Burned", unit: "", points: burned, target: nil, inBandDays: nil))
    }
}
