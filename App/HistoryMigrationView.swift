//
//  HistoryMigrationView.swift
//  Bullet Tracker
//
//  bt-0022 — Settings → Data Management → "Prepare Dashboard history".
//  One-time, iPhone only (the fake source on the simulator in debug
//  builds). Three steps in order: save a backup to Files (the gate — the
//  rewrite can't be undone in the app), read the table of what will be
//  kept, deleted and rebuilt, then one confirm. The logic is
//  `HistoryMigration`; this screen only shows and gates it.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryMigrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Habit.order)]) private var habits: [Habit]
    @State private var engine = HabitSyncEngine.shared

    // Step 1 — backup
    @State private var backupURL: URL?
    @State private var isExporting = false
    @State private var backupSavedTo: String?
    @State private var backupError: String?

    // Step 2 — the plan
    @State private var history: HistoryMigration.History?
    @State private var plan: HistoryMigration.Plan?
    @State private var isLoading = false
    @State private var loadError: String?

    // Step 3 — run
    @State private var confirming = false
    @State private var isRunning = false
    @State private var result: HistoryMigration.Plan?
    @State private var runError: String?

    private let dates = HistoryMigration.Dates.standard()

    private var canRun: Bool {
        backupSavedTo != nil && plan != nil && history != nil && !isRunning && result == nil && hasSource
    }

    /// dh on the iPhone with its key; the fake when the Developer switch is on.
    private var source: (any HabitFactsSource)? {
        #if DEBUG
        if engine.isSimulationEnabled { return FakeHealthFacts() }
        #endif
        guard HabitSyncEngine.isGradingDevice, let key = APIKeyStore.read() else { return nil }
        return DustinHealthFacts(key: key)
    }

    private var hasSource: Bool { source != nil }

    var body: some View {
        Form {
            if let result {
                doneSection(result)
            } else {
                backupSection
                planSection
                runSection
            }
        }
        .navigationTitle("Dashboard History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPlan() }
        .fileExporter(isPresented: $isExporting, item: backupURL, contentTypes: [.json],
                      defaultFilename: backupURL?.deletingPathExtension().lastPathComponent) { outcome in
            switch outcome {
            case .success(let url):
                backupSavedTo = url.lastPathComponent
                backupError = nil
            case .failure(let error):
                backupError = error.localizedDescription
            }
        }
        .alert("Rewrite history?", isPresented: $confirming, presenting: plan) { _ in
            Button("Rewrite", role: .destructive) { run() }
            Button("Cancel", role: .cancel) {}
        } message: { plan in
            Text(confirmMessage(plan))
        }
    }

    // MARK: - 1. Backup

    private var backupSection: some View {
        Section {
            if let backupSavedTo {
                Label {
                    Text("Backup saved · \(backupSavedTo)")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
                }
            }
            Button(backupSavedTo == nil ? "Save a backup to Files…" : "Save another backup…") {
                exportBackup()
            }
            if let backupError {
                Text(backupError).font(.footnote).foregroundStyle(AppTheme.failed)
            }
        } header: {
            Text("1. Backup")
        } footer: {
            Text("The rewrite can't be undone in the app. Save a backup first; Restore in Backup & Restore brings everything back, dh's lists included.")
        }
    }

    private func exportBackup() {
        backupError = nil
        guard let url = BackupManager.shared.createBackup(in: modelContext) else {
            backupError = BackupManager.shared.errorMessage ?? "Couldn't create the backup."
            return
        }
        backupURL = url
        isExporting = true
    }

    // MARK: - 2. The plan

    @ViewBuilder
    private var planSection: some View {
        Section {
            if !hasSource {
                Label("Runs on the iPhone with the Dustin's Health key.", systemImage: "iphone")
                    .foregroundStyle(.secondary)
            } else if isLoading {
                HStack {
                    Text("Asking Dustin's Health for Aug 1 – Oct 26…")
                    Spacer()
                    ProgressView()
                }
            } else if let loadError {
                Text(loadError).foregroundStyle(AppTheme.failed)
                Button("Try again") { Task { await loadPlan() } }
            } else if let plan {
                ForEach(plan.lines) { line in
                    planRow(line)
                }
                LabeledContent("Journal notes") {
                    Text("\(plan.notesBefore) · Kept")
                }
                if plan.workoutMissing {
                    Text("No habit is graded by Workout, so nothing is rebuilt.")
                        .foregroundStyle(AppTheme.partial)
                }
            }
        } header: {
            Text("2. Before \(dates.cutoff.formatted(.dateTime.month(.abbreviated).day()))")
        } footer: {
            footerText
        }
    }

    private func planRow(_ line: HistoryMigration.Line) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(line.name)
                Spacer()
                Text("\(line.rowsBefore) \(line.rowsBefore == 1 ? "row" : "rows")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text(actionText(line.action))
                .font(.footnote)
                .foregroundStyle(actionColor(line.action))
        }
        .accessibilityElement(children: .combine)
    }

    private func actionText(_ action: HistoryMigration.Action) -> String {
        switch action {
        case .kept: return "Kept"
        case .deleted: return "Deleted"
        case .rebuilt(let r):
            return "Deleted, then \(r.days) days rebuilt from \(r.sessions) sessions · Done \(r.done) · Partial \(r.partial) · Tried \(r.tried)"
        }
    }

    private func actionColor(_ action: HistoryMigration.Action) -> Color {
        switch action {
        case .kept: return AppTheme.success
        case .deleted: return AppTheme.failed
        case .rebuilt: return .secondary
        }
    }

    @ViewBuilder
    private var footerText: some View {
        if let history {
            let base = "\(history.sessionCount) sessions found at Dustin's Health for Aug 1 – Oct 26 (expect 138). Meals in the same answer are ignored; food history starts Oct 27."
            if history.stepsAvailable {
                Text(base + " Steps from Health lift a short-session day to Partial.")
            } else {
                Text(base + " Steps were not read, so a short-session day reads Tried. " + history.notes.joined(separator: " "))
            }
        } else {
            Text("Everything from Oct 27 on stays exactly as it is.")
        }
    }

    private func loadPlan() async {
        guard let source, !isLoading, result == nil else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            var readSteps = HabitSyncEngine.isGradingDevice
            #if DEBUG
            if engine.isSimulationEnabled { readSteps = false }
            #endif
            let loaded = try await HistoryMigration.loadHistory(source: source, readSteps: readSteps, dates: dates)
            history = loaded
            plan = HistoryMigration.plan(habits: habits, history: loaded, dates: dates, in: modelContext)
        } catch {
            loadError = "Couldn't read Dustin's Health: \(error.localizedDescription)"
            plan = nil
        }
    }

    // MARK: - 3. Run

    private var runSection: some View {
        Section {
            Button("Rewrite history…", role: .destructive) {
                confirming = true
            }
            .disabled(!canRun)
            if let runError {
                Text(runError).font(.footnote).foregroundStyle(AppTheme.failed)
            }
        } header: {
            Text("3. Rewrite")
        } footer: {
            if backupSavedTo == nil {
                Text("Save a backup first.")
            } else if plan == nil {
                Text("Waiting for the table above.")
            } else {
                Text("One confirm. iCloud carries the result to the iPad.")
            }
        }
    }

    private func confirmMessage(_ plan: HistoryMigration.Plan) -> String {
        var parts = ["Delete \(plan.deletedRows) rows before Oct 27."]
        if plan.keptRows > 0 { parts.append("Keep \(plan.keptRows) Poison rows and \(plan.notesBefore) notes.") }
        if let r = plan.rebuilt { parts.append("Rebuild Workout: \(r.days) days from \(r.sessions) sessions.") }
        parts.append("This can't be undone in the app.")
        return parts.joined(separator: " ")
    }

    private func run() {
        guard let history else { return }
        isRunning = true
        runError = nil
        do {
            result = try HistoryMigration.perform(habits: habits, history: history, dates: dates, in: modelContext)
        } catch {
            runError = "The rewrite failed and nothing was saved: \(error.localizedDescription)"
        }
        isRunning = false
    }

    // MARK: - Done

    private func doneSection(_ result: HistoryMigration.Plan) -> some View {
        Section {
            Label {
                Text("History rewritten")
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
            }
            ForEach(result.lines) { line in
                planRow(line)
            }
            LabeledContent("Journal notes", value: "\(result.notesBefore) · Kept")
            Button("Done") { dismiss() }
        } footer: {
            Text("Open the Dashboard or Journal to see it. The iPad catches up through iCloud.")
        }
    }
}

#Preview {
    NavigationStack {
        HistoryMigrationView()
    }
    .modelContainer(for: [Habit.self, HabitEntry.self, Note.self], inMemory: true)
}
