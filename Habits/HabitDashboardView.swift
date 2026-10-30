//
//  HabitDashboardView.swift
//  Bullet Tracker
//
//  bt-0023 — the Dashboard answers "am I slipping, and where?" and does the
//  dh website's job on top: one day's calories (eaten vs burned), protein /
//  carbs / fat against targets, the biggest-driver line, the meals and the
//  training, all from the Diet and Workout rows' stored `health` blocks.
//  Underneath: habits won per day against the period before, one row per
//  habit in Today order with a mini strip, and the nutrition / training
//  trend. Swift Charts, first use in the app; system `Gauge` for the rings.
//
//  Every number here is read from the rows (or the engine's live copy for
//  today); nothing is fetched from the network on this screen.
//

import SwiftUI
import SwiftData
import Charts

struct HabitDashboardView: View {
    @Query(sort: [SortDescriptor(\Habit.order), SortDescriptor(\Habit.name)])
    private var habits: [Habit]

    @State private var viewModel = HabitDashboardViewModel()
    @State private var engine = HabitSyncEngine.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 28

    private let calendar = Calendar.current

    private var isToday: Bool { calendar.isDateInToday(viewModel.selectedDate) }

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Habits Yet", systemImage: "chart.bar")
                        } description: {
                            Text("Add habits in the Today tab to see your analytics here.")
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    daySections
                    trendSections
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaBar(edge: .top) {
                DateStripBar(selectedDate: $viewModel.selectedDate)
            }
            .navigationTitle("Dashboard")
            .keepNavigationBarVisible()
            .onAppear { reload() }
            .onChange(of: viewModel.selectedDate) { _, _ in reload() }
            .onChange(of: viewModel.period) { _, _ in reload() }
            .onChange(of: habits.count) { _, _ in reload() }
            // A sync just finished: today's live copy may have moved.
            .onChange(of: engine.isRunning) { _, running in if !running { reload() } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        }
    }

    private func reload() {
        viewModel.loadData(habits: habits, engine: engine)
    }

    // MARK: - One day

    private var dayTitle: String {
        viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    @ViewBuilder
    private var daySections: some View {
        let day = viewModel.day

        // The two graded rows' modes, side by side.
        if day.diet != nil || day.workout != nil {
            Section(dayTitle) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                layout {
                    if let diet = day.diet {
                        modeCell(name: diet.name ?? "Diet", entry: day.dietEntry)
                    }
                    if let workout = day.workout {
                        modeCell(name: workout.name ?? "Workout", entry: day.workoutEntry)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        if day.diet != nil {
            caloriesSection(day)
            if !day.meals.isEmpty, !isBeforeMeals(day) {
                mealsSection(day)
            }
        }

        if day.workout != nil {
            trainingSection(day)
        }
    }

    private func isBeforeMeals(_ day: HabitDashboardViewModel.DayHalf) -> Bool {
        guard let start = day.mealsStart else { return false }
        return calendar.startOfDay(for: viewModel.selectedDate) < start
    }

    private func modeCell(name: String, entry: HabitEntry?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.subheadline.weight(.semibold))
            Text(DashboardDay.modeLine(source: entry?.isOverride == true ? entry?.source : .auto,
                                       state: entry?.effectiveCompletionState, isToday: isToday))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Calories

    @ViewBuilder
    private func caloriesSection(_ day: HabitDashboardViewModel.DayHalf) -> some View {
        let t = day.dietTargets
        Section("Calories") {
            if isBeforeMeals(day), let start = day.mealsStart {
                Text("Meals start \(start.formatted(.dateTime.month(.abbreviated).day()))")
                    .foregroundStyle(.secondary)
            } else {
                let eaten = day.dietHealth?.totalCalories
                let burned = day.workoutHealth?.totalBurnKcal
                let position = DashboardDay.bandPosition(calories: eaten, floor: t.calorieFloor, ceiling: t.calorieCeiling)

                // Eaten vs Burned, side by side. Burned is Apple Health's day
                // total and nothing else (the sessions are never added to it).
                let columns = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                columns {
                    bigNumber(title: "Eaten", value: DashboardDay.wholeOrDash(eaten),
                              detail: DashboardDay.calorieBandText(calories: eaten, floor: t.calorieFloor, ceiling: t.calorieCeiling),
                              detailColor: position == .over ? AppTheme.failed : .secondary)
                    if !dynamicTypeSize.isAccessibilitySize { Divider() }
                    bigNumber(title: "Burned", value: DashboardDay.wholeOrDash(burned),
                              detail: DashboardDay.burnedDetailText(active: day.workoutHealth?.activeBurnKcal,
                                                                    resting: day.workoutHealth?.restingBurnKcal) ?? "Apple Health",
                              detailColor: .secondary)
                }
                .padding(.vertical, 2)

                CalorieBandChart(calories: eaten, floor: t.calorieFloor, ceiling: t.calorieCeiling, position: position)
                    .frame(height: 22)
                    .accessibilityLabel("Calorie band \(DashboardDay.whole(t.calorieFloor)) to \(DashboardDay.whole(t.calorieCeiling))")
                    .accessibilityValue(DashboardDay.calorieBandText(calories: eaten, floor: t.calorieFloor, ceiling: t.calorieCeiling))

                macroRings(day)

                if let driver = DashboardDay.driver(meals: day.meals, carbsCeiling: t.carbsCeilingGrams, fatCeiling: t.fatCeilingGrams) {
                    Text("**Biggest driver:** \(driver.text)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func bigNumber(title: String, value: String, detail: String, detailColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(detail)
                .font(.caption)
                .foregroundStyle(detailColor)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The three rings: system `Gauge` in its circular style. Carbs / fat
    /// over target turn red; protein never does (website behaviour).
    private func macroRings(_ day: HabitDashboardViewModel.DayHalf) -> some View {
        let t = day.dietTargets
        let health = day.dietHealth
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            MacroRing(title: "Protein", value: health?.totalProtein, target: t.proteinFloorGrams,
                      tint: (health?.totalProtein ?? 0) >= t.proteinFloorGrams ? AppTheme.success : AppTheme.accent)
            MacroRing(title: "Carbs", value: health?.totalCarbs, target: t.carbsCeilingGrams,
                      tint: (health?.totalCarbs ?? 0) > t.carbsCeilingGrams ? AppTheme.failed : AppTheme.accent)
            MacroRing(title: "Fat", value: health?.totalFat, target: t.fatCeilingGrams,
                      tint: (health?.totalFat ?? 0) > t.fatCeilingGrams ? AppTheme.failed : AppTheme.accent)
        }
        .padding(.vertical, 4)
    }

    // MARK: Meals

    private func mealsSection(_ day: HabitDashboardViewModel.DayHalf) -> some View {
        Section {
            ForEach(Array(day.meals.enumerated()), id: \.offset) { _, meal in
                // Name on top, time and numbers underneath: the Log Details
                // shape, and nothing wraps on a folded phone.
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                    Text([meal.at.map { $0.formatted(date: .omitted, time: .shortened) },
                          HabitCompletionDetailView.mealNumbers(calories: meal.calories, protein: meal.protein)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            if day.meals.count > 1 {
                LabeledContent("Total", value: HabitCompletionDetailView.mealNumbers(calories: day.dietHealth?.totalCalories,
                                                                                    protein: day.dietHealth?.totalProtein))
                    .monospacedDigit()
            }
        } header: {
            HStack {
                Text("Meals")
                Spacer()
                Text("\(day.meals.count) logged · \(DashboardDay.wholeOrDash(day.dietHealth?.totalCalories)) kcal")
            }
        }
    }

    // MARK: Training

    @ViewBuilder
    private func trainingSection(_ day: HabitDashboardViewModel.DayHalf) -> some View {
        let health = day.workoutHealth
        let t = day.workoutTargets
        Section {
            if day.sessions.isEmpty && health?.steps == nil {
                Text(isToday ? "No training yet" : "No training logged")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(day.sessions.enumerated()), id: \.offset) { _, session in
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                    // `activeKcal` null is a dash; the dh website shows 0 for
                    // the same case (the one expected side-by-side difference).
                    Text([session.start.map { $0.formatted(date: .omitted, time: .shortened) },
                          "\(DashboardDay.whole(session.minutes)) min",
                          "\(DashboardDay.wholeOrDash(session.activeKcal)) active cal"]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            if let steps = health?.steps {
                LabeledContent("Steps", value: "\(steps.formatted()) · target \(DashboardDay.whole(t.steps))")
                    .monospacedDigit()
            }
            // Never silent: sessions adding up to more than Health's Active
            // Energy means a double count somewhere.
            if let warning = DashboardDay.warningText(sessionsKcal: health?.totalActiveKcal,
                                                      healthActiveKcal: health?.activeBurnKcal) {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.partial)
            }
        } header: {
            HStack {
                Text("Training")
                Spacer()
                if !day.sessions.isEmpty {
                    Text("\(day.sessions.count) \(day.sessions.count == 1 ? "session" : "sessions") · \(DashboardDay.whole(health?.totalMinutes ?? 0)) min")
                }
            }
        }
    }

    // MARK: - Trends

    @ViewBuilder
    private var trendSections: some View {
        Section {
            Picker("Period", selection: $viewModel.period) {
                ForEach(DashboardPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section(viewModel.period.title) {
            WinsBarChart(days: viewModel.dayWins, ceiling: viewModel.scheduledCeiling, period: viewModel.period)
                .frame(height: 120)
                .padding(.vertical, 4)
                .accessibilityLabel("Habits done per day")
                .accessibilityValue(DashboardTrends.averageText(current: viewModel.currentAverage, ceiling: viewModel.scheduledCeiling))

            HStack(spacing: 6) {
                Text(DashboardTrends.averageText(current: viewModel.currentAverage, ceiling: viewModel.scheduledCeiling))
                    .font(.subheadline.weight(.semibold))
                if let previous = viewModel.previousAverage {
                    Text("·").foregroundStyle(.secondary)
                    Image(systemName: viewModel.averageTrend.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(viewModel.averageTrend.spoken(previousTitle: viewModel.period.previousTitle))
                    Text("from \(previous.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        }

        Section("Habits") {
            ForEach(viewModel.habitRows) { row in
                NavigationLink(destination: HabitDetailDashboardView(habit: row.habit)) {
                    habitRow(row)
                }
            }
        }

        let series = viewModel.nutritionSeries + viewModel.trainingSeries
        Section("Nutrition & training trend") {
            if series.isEmpty {
                Text("Appears once synced days are stored.")
                    .foregroundStyle(.secondary)
            }
            ForEach(series, id: \.title) { s in
                TrendRow(series: s)
            }
        }
    }

    private func habitRow(_ row: HabitDashboardViewModel.HabitRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HabitIconTile(systemImage: row.icon, colorHex: row.color, size: tileSize)
                Text(row.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(countText(row))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: row.trend.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(row.trend.spoken(previousTitle: viewModel.period.previousTitle))
                if row.streak > 0 {
                    Label("\(row.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("\(row.streak) day streak")
                }
            }
            MiniDayStrip(squares: row.squares)
                .accessibilityHidden(true) // the count says it
        }
        .padding(.vertical, 4)
    }

    /// "5 of 7" for a positive habit; "1 of 7 slipped" for an avoidance habit
    /// (bt-0024 — never a done count for something you don't do).
    private func countText(_ row: HabitDashboardViewModel.HabitRow) -> String {
        row.isSlipRate ? "\(row.count) of \(row.scored) slipped" : "\(row.count) of \(row.scored)"
    }
}

// MARK: - Calorie band (Swift Charts)

/// One thin horizontal bar for the eaten total over the floor–ceiling band.
/// Colour is status: under the floor it is still open (accent), in the band
/// green, over the ceiling red.
struct CalorieBandChart: View {
    let calories: Double?
    let floor: Double
    let ceiling: Double
    let position: DashboardDay.BandPosition

    private var barColor: Color {
        switch position {
        case .none, .under: return AppTheme.accent
        case .inRange: return AppTheme.success
        case .over: return AppTheme.failed
        }
    }

    var body: some View {
        let upper = max(ceiling * 1.15, calories ?? 0)
        Chart {
            RectangleMark(xStart: .value("Floor", floor), xEnd: .value("Ceiling", ceiling))
                .foregroundStyle(Color(.systemGray5))
            BarMark(xStart: .value("Start", 0), xEnd: .value("Eaten", calories ?? 0), y: .value("", "Eaten"))
                .foregroundStyle(barColor)
                .cornerRadius(4)
            RuleMark(x: .value("Floor", floor))
                .foregroundStyle(Color(.systemGray3))
                .lineStyle(StrokeStyle(lineWidth: 1))
            RuleMark(x: .value("Ceiling", ceiling))
                .foregroundStyle(Color(.systemGray3))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXScale(domain: 0...upper)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Macro ring (system Gauge)

struct MacroRing: View {
    let title: String
    let value: Double?
    let target: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Gauge(value: min(value ?? 0, target), in: 0...max(target, 1)) {
                Text(title)
            } currentValueLabel: {
                Text(DashboardDay.wholeOrDash(value))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            Text("of \(DashboardDay.whole(target))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(DashboardDay.wholeOrDash(value)) of \(DashboardDay.whole(target)) grams")
    }
}

// MARK: - Habits won per day (Swift Charts)

/// One bar per day, one hue; a slip is a red mark above the day, never a
/// point lost. Axes are recessive: two y ticks, weekday letters (week) or
/// a date every seven days (month).
struct WinsBarChart: View {
    let days: [DashboardTrends.DayWins]
    let ceiling: Int
    let period: DashboardPeriod

    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let first = days.first?.day ?? Date()
        let last = days.last?.day ?? first
        return first...(calendar.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    var body: some View {
        Chart(days) { day in
            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Done", day.wins))
                .foregroundStyle(AppTheme.accent)
                .cornerRadius(3)
                .annotation(position: .top, spacing: 2) {
                    if day.slips > 0 {
                        Circle()
                            .fill(AppTheme.failed)
                            .frame(width: 6, height: 6)
                    }
                }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...max(ceiling, 1))
        .chartYAxis {
            AxisMarks(values: [0, max(ceiling, 1)]) {
                AxisGridLine().foregroundStyle(Color(.systemGray5))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            if period == .week {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }
}

// MARK: - Mini day strip

/// Seven (or thirty) `DaySquare`s sized to the row: the Today grid's family,
/// read-only. A square with no colour is the empty style.
struct MiniDayStrip: View {
    let squares: [HabitDashboardViewModel.Square]

    @State private var width: CGFloat = 0
    private let spacing: CGFloat = 3

    private var size: CGFloat {
        guard width > 0, !squares.isEmpty else { return 12 }
        let fitted = ((width - 1) - spacing * CGFloat(squares.count - 1)) / CGFloat(squares.count)
        return max(4, min(fitted.rounded(.down), 28))
    }

    var body: some View {
        // Width reader: takes exactly the row's width. The squares sit in an
        // overlay so they can never widen what is measured — as a sibling
        // they inflated the container once laid out wide (unfolded / rotated),
        // the reader then saw that inflated width, and the squares stayed
        // large past the row's edge after the screen narrowed again.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: size)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay(alignment: .leading) {
                HStack(spacing: spacing) {
                    ForEach(squares) { square in
                        DaySquare(size: size, style: square.color.map { .filled($0) } ?? .empty)
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Trend row (sparkline + summary)

/// "Protein  ▅▇█▆▃▇▂  avg 172 g of 180": a thin bar per day with the target
/// as a hairline, the summary text carrying the numbers.
struct TrendRow: View {
    let series: DashboardTrends.Series

    /// The whole period on the x axis, so one known day draws as one thin
    /// bar in its place instead of a block filling the chart.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let first = series.points.first?.day ?? Date()
        let last = series.points.last?.day ?? first
        return first...(calendar.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(series.title)
                .font(.subheadline)
                .frame(minWidth: 64, alignment: .leading)
            Chart {
                ForEach(series.points.filter { $0.value != nil }) { point in
                    BarMark(x: .value("Day", point.day, unit: .day), y: .value(series.title, point.value ?? 0))
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                        .cornerRadius(1.5)
                }
                if let target = series.target {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(Color(.systemGray3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: xDomain)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 28)
            Text(series.summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(series.title)
        .accessibilityValue(series.summaryText)
    }
}

#Preview {
    HabitDashboardView()
        .modelContainer(for: [Habit.self, HabitEntry.self, Note.self], inMemory: true)
}
