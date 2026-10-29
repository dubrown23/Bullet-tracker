//
//  HealthRefetchView.swift
//  Bullet Tracker
//
//  bt-0023 — Settings → Data Management → "Refresh Workout Calories".
//  One-time, iPhone only (the fake source on the simulator in debug builds).
//  Shows the counts first — rows in the span, sessions before and after,
//  rows that change, the biggest per-session calorie correction — then one
//  tap. The logic is `HealthRefetch`; this screen only shows and confirms it.
//

import SwiftUI
import SwiftData

struct HealthRefetchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Habit.order)]) private var habits: [Habit]
    @State private var engine = HabitSyncEngine.shared

    @State private var readings: HealthRefetch.Readings?
    @State private var plan: HealthRefetch.Plan?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var result: HealthRefetch.Plan?

    private let dates = HealthRefetch.Dates.standard()

    private var workout: Habit? { habits.first { $0.gradingKind == .workout } }

    /// dh on the iPhone with its key; the fake when the Developer switch is on.
    private var source: (any HabitFactsSource)? {
        #if DEBUG
        if engine.isSimulationEnabled { return FakeHealthFacts() }
        #endif
        guard HabitSyncEngine.isGradingDevice, let key = APIKeyStore.read() else { return nil }
        return DustinHealthFacts(key: key)
    }

    private var spanText: String {
        "\(dates.start.formatted(.dateTime.month(.abbreviated).day())) – \(dates.end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var body: some View {
        Form {
            if let result {
                doneSection(result)
            } else {
                planSection
                runSection
            }
        }
        .navigationTitle("Workout Calories")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPlan() }
    }

    // MARK: - The plan

    @ViewBuilder
    private var planSection: some View {
        Section {
            if source == nil {
                Label("Runs on the iPhone with the Dustin's Health key.", systemImage: "iphone")
                    .foregroundStyle(.secondary)
            } else if workout == nil {
                Text("No habit is graded by Workout, so there is nothing to refresh.")
                    .foregroundStyle(AppTheme.partial)
            } else if isLoading {
                HStack {
                    Text("Asking Dustin's Health for \(spanText)…")
                    Spacer()
                    ProgressView()
                }
            } else if let loadError {
                Text(loadError).foregroundStyle(AppTheme.failed)
                Button("Try again") { Task { await loadPlan() } }
            } else if let plan {
                planRows(plan)
            }
        } header: {
            Text("What changes · \(spanText)")
        } footer: {
            footerText
        }
    }

    @ViewBuilder
    private func planRows(_ plan: HealthRefetch.Plan) -> some View {
        LabeledContent("Workout rows", value: "\(plan.rows)")
        LabeledContent("Sessions", value: "\(plan.sessionsBefore) → \(plan.sessionsAfter)")
        LabeledContent("Rows that change", value: "\(plan.changedRows)")
        LabeledContent("Burned added on", value: "\(plan.burnAdded) \(plan.burnAdded == 1 ? "day" : "days")")
        if let change = plan.biggestKcalChange {
            VStack(alignment: .leading, spacing: 2) {
                Text("Biggest calorie correction")
                Text("\(change.day.formatted(.dateTime.month(.abbreviated).day())) · \(change.name) · \(Self.kcal(change.before)) → \(Self.kcal(change.after)) active cal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var footerText: some View {
        if let readings {
            let base = "\(readings.sessionCount) sessions at Dustin's Health for the span. Grades, Set by you marks and notes are untouched; only the dh list and the Health numbers on each row are rewritten."
            if readings.healthAvailable {
                Text(base + " Steps and calories burned come from Apple Health for each row's day.")
            } else {
                Text(base + " Health was not read, so stored steps stay and no burned calories are added. " + readings.notes.joined(separator: " "))
            }
        } else {
            Text("Rewrites the Dustin's Health list on each Workout row with the corrected session calories, and adds the day's calories burned from Apple Health.")
        }
    }

    private func loadPlan() async {
        guard let source, let workout, !isLoading, result == nil else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            var readHealth = HabitSyncEngine.isGradingDevice
            #if DEBUG
            if engine.isSimulationEnabled { readHealth = false }
            #endif
            let rows = HealthRefetch.rows(for: workout, dates: dates)
            let loaded = try await HealthRefetch.load(source: source, readHealth: readHealth,
                                                      rowDays: rows.map(\.date), dates: dates)
            readings = loaded
            plan = HealthRefetch.plan(rows: rows, readings: loaded)
        } catch {
            loadError = "Couldn't read Dustin's Health: \(error.localizedDescription)"
            plan = nil
        }
    }

    // MARK: - Run

    private var runSection: some View {
        Section {
            Button("Refresh") { run() }
                .disabled(plan == nil || workout == nil)
        } footer: {
            if let plan {
                Text(plan.changedRows == 0
                     ? "Nothing would change. Refresh just marks this done."
                     : "Writes \(plan.changedRows) \(plan.changedRows == 1 ? "row" : "rows"). iCloud carries the result to the iPad.")
            } else {
                Text("Waiting for the counts above.")
            }
        }
    }

    private func run() {
        guard let plan, let workout else { return }
        result = HealthRefetch.perform(habit: workout, plan: plan, in: modelContext)
    }

    // MARK: - Done

    private func doneSection(_ result: HealthRefetch.Plan) -> some View {
        Section {
            Label {
                Text("Workout calories refreshed")
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
            }
            planRows(result)
            Button("Done") { dismiss() }
        } footer: {
            Text("Open the Dashboard to see it. The iPad catches up through iCloud.")
        }
    }

    /// "1,190" / "—": a number dh doesn't know is a dash, never 0.
    static func kcal(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview {
    NavigationStack {
        HealthRefetchView()
    }
    .modelContainer(for: [Habit.self, HabitEntry.self, Note.self], inMemory: true)
}
