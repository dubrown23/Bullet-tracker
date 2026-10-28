//
//  DeveloperSyncView.swift
//  Bullet Tracker
//
//  bt-0017 / bt-0018. Settings → Developer. Debug builds only. Drives the
//  sync pass tests: the "Simulate dh sync" switch, what the fake source
//  says (so every colour can be forced), a manual run, this device's role,
//  today's steps, the raw rows per test habit for today and yesterday
//  (state · source · edit time — what the Today square can't show), the
//  last run's report, and cleanup.
//

#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine = HabitSyncEngine.shared
    @State private var rows: [(name: String, day: String, rows: [HabitSyncEngine.RowReadout]?)] = []
    @State private var confirmingRemove = false
    @State private var duplicateNotice: String?
    @State private var dietScenario = FakeHealthFacts.dietScenario
    @State private var workoutScenario = FakeHealthFacts.workoutScenario

    var body: some View {
        @Bindable var engine = engine

        Form {
            Section {
                Toggle("Simulate dh sync", isOn: $engine.isSimulationEnabled)

                Picker("Fake meals", selection: $dietScenario) {
                    ForEach(FakeHealthFacts.DietScenario.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .onChange(of: dietScenario) { _, new in FakeHealthFacts.dietScenario = new }

                Picker("Fake workout", selection: $workoutScenario) {
                    ForEach(FakeHealthFacts.WorkoutScenario.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .onChange(of: workoutScenario) { _, new in FakeHealthFacts.workoutScenario = new }

                Button {
                    Task { await runNow() }
                } label: {
                    if engine.isRunning {
                        HStack {
                            Text("Running…")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Run now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(engine.isRunning)
            } header: {
                Text("Fake dh")
            } footer: {
                Text("While the switch is on, the fake sync runs instead of Dustin's Health every time the app becomes active and on pull-down. The fake says the same thing for every day it is asked about. Meals: Neither = 100 g / 1,200 cal · Protein only = 190 g / 1,500 cal · Both = 190 g / 2,050 cal · Over = 190 g / 2,400 cal. Inbox: “Test Sauna done”. Switch it on from one device only and let the test habits (Test Diet, Test Workout, Test Sauna, Test Weed) reach the other before running there. With the switch off and a key saved in Settings, Run now is the real sync.")
            }

            Section("This device") {
                LabeledContent("Role", value: HabitSyncEngine.isGradingDevice ? "Grades + syncs (iPhone)" : "Read-only (shows grades, never writes them, never calls dh)")
                // bt-0019 — the key's presence and protection, read from the
                // Keychain item itself. The key's value is never shown.
                LabeledContent("dh key", value: APIKeyStore.hasKey ? "stored, \(APIKeyStore.accessibilityDescription ?? "protection unknown")" : "none")
                LabeledContent("Steps today") {
                    if let steps = engine.lastReport?.stepsToday {
                        Text(steps, format: .number)
                            .monospacedDigit()
                    } else {
                        Text("Run to read")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("\(row.name) · \(row.day)") {
                            if let list = row.rows {
                                Text("\(list.count)")
                                    .monospacedDigit()
                                    .foregroundStyle(list.count <= 1 ? .primary : AppTheme.failed)
                            } else {
                                Text("no habit")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // One line per raw row, survivor first:
                        // id · state · source · edit time.
                        ForEach(row.rows ?? []) { r in
                            Text("\(r.id)  \(r.state) · \(r.source) · \(r.editedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "no time")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Refresh rows", systemImage: "arrow.clockwise") {
                    refreshCounts()
                }
            } header: {
                Text("Rows for today and yesterday")
            } footer: {
                Text("Raw entry rows per test habit. 0 = no colour, 1 = one row (pass), 2 = a duplicate the next Run now's cleanup should collapse, keeping the first row listed. The source column proves the override rule: a hand row is never rewritten by a run.")
            }

            Section {
                Button("Start grading yesterday", systemImage: "calendar.badge.clock") {
                    engine.startGradingYesterday(in: modelContext)
                    refreshCounts()
                }
                Button("Put Test Workout first (for the widget)", systemImage: "arrow.up.to.line") {
                    engine.moveTestWorkoutFirst(in: modelContext)
                }
                Button("Add a duplicate auto row for Test Diet", systemImage: "plus.square.on.square") {
                    if engine.insertDuplicateTestRow(in: modelContext) {
                        duplicateNotice = "Added a Partial / auto row. Rows for Test Diet today should read 2 here, and on the other device once iCloud delivers it. The next Run now keeps a hand row over it, else the newest."
                    } else {
                        duplicateNotice = "Test Diet isn't on this device yet."
                    }
                    refreshCounts()
                }
                if let duplicateNotice {
                    Text(duplicateNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Force a state")
            } footer: {
                Text("“Start grading yesterday” moves Test Diet and Test Workout's go-live day back one day, so a run with fake meals set to Neither turns yesterday red while today stays blank. “Put Test Workout first” only changes the test habit's position (real habits are untouched) so its tile shows in the widget. The duplicate button creates the exact state two devices produce when both write the same day offline.")
            }

            if let report = engine.lastReport {
                Section {
                    ForEach(Array(report.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.footnote)
                    }
                    ForEach(Array(report.errors.enumerated()), id: \.offset) { _, line in
                        Label(line, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.failed)
                    }
                } header: {
                    Text("Last run")
                } footer: {
                    // bt-0020 — why the run happened and the count since launch
                    // (five quick taps → the count goes up by one, not five).
                    // Two lines on purpose: one line wrapped with an orphan
                    // "since launch" on the folded Duo.
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(report.sourceName) · \(report.reason.rawValue) · \(report.finished.formatted(date: .omitted, time: .standard))")
                        Text("\(engine.runsSinceLaunch) run\(engine.runsSinceLaunch == 1 ? "" : "s") since launch")
                    }
                }
            }

            Section {
                Button("Remove test habits", systemImage: "trash", role: .destructive) {
                    confirmingRemove = true
                }
            } footer: {
                Text("Deletes Test Diet, Test Workout, Test Sauna and Test Weed and all their entries, on every device once it syncs.")
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshCounts)
        .confirmationDialog("Remove the test habits?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Test Diet, Test Workout, Test Sauna and Test Weed", role: .destructive) {
                engine.removeTestHabits(in: modelContext)
                refreshCounts()
            }
        }
    }

    /// Simulation on → the fake. Off → whatever `refresh` picks (dh with a
    /// key on the iPhone; steps only otherwise), forced past the debounce.
    private func runNow() async {
        if engine.isSimulationEnabled {
            await engine.runSimulation(in: modelContext)
        } else {
            await engine.refresh(in: modelContext, force: true)
        }
        refreshCounts()
    }

    private func refreshCounts() {
        rows = engine.testHabitRows(in: modelContext)
    }
}

#Preview {
    NavigationStack {
        DeveloperSyncView()
    }
    .modelContainer(for: [Habit.self, HabitEntry.self, Note.self], inMemory: true)
}
#endif
