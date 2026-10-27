//
//  DeveloperSyncView.swift
//  Bullet Tracker
//
//  bt-0017. Settings → Developer. Debug builds only. Drives the Step 0 sync
//  proof: the "Simulate dh sync" switch, a manual run, today's steps, the
//  raw row count per test habit (the number the Today row can't show), the
//  last run's report, and cleanup.
//

#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine = HabitSyncEngine.shared
    @State private var rows: [(name: String, ids: [String]?)] = []
    @State private var confirmingRemove = false
    @State private var duplicateNotice: String?

    var body: some View {
        @Bindable var engine = engine

        Form {
            Section {
                Toggle("Simulate dh sync", isOn: $engine.isSimulationEnabled)

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
                Text("While the switch is on, the fake sync runs every time the app becomes active. Facts: 190 g protein, 2,050 cal. Inbox: “Test Sauna done”. Switch it on from one device only and let the test habits reach the other before running there.")
            }

            Section {
                ForEach(rows, id: \.name) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent(row.name) {
                            if let ids = row.ids {
                                Text("\(ids.count)")
                                    .monospacedDigit()
                                    .foregroundStyle(ids.count == 1 ? .primary : AppTheme.failed)
                            } else {
                                Text("no habit")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let ids = row.ids, !ids.isEmpty {
                            // Short id per row, survivor first. Same ids on
                            // both devices = merged; different = not yet.
                            Text(ids.joined(separator: "  "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Refresh counts", systemImage: "arrow.clockwise") {
                    refreshCounts()
                }
            } header: {
                Text("Rows for today")
            } footer: {
                Text("Raw entry rows per test habit for today, with each row's id. Pass is 1 on every device, never 0. Two means a duplicate exists; the next Run now's cleanup pass should bring it back to one, keeping the first id listed.")
            }

            Section {
                Button("Add a duplicate row for Test Sauna", systemImage: "plus.square.on.square") {
                    if engine.insertDuplicateTestRow(in: modelContext) {
                        duplicateNotice = "Added. Rows for Test Sauna should now read 2 here, and on the other device once iCloud delivers it."
                    } else {
                        duplicateNotice = "Test Sauna isn't on this device yet."
                    }
                    refreshCounts()
                }
                if let duplicateNotice {
                    Text(duplicateNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Force a duplicate")
            } footer: {
                Text("Creates the exact state two devices produce when both write the same day offline, without needing airplane mode. Then tap Run now on each device and watch both settle to 1.")
            }

            Section("Steps") {
                LabeledContent("Today") {
                    if let steps = engine.lastReport?.stepsToday {
                        Text(steps, format: .number)
                            .monospacedDigit()
                    } else {
                        Text("Run to read")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let report = engine.lastReport {
                Section {
                    ForEach(Array(report.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                    ForEach(Array(report.errors.enumerated()), id: \.offset) { _, line in
                        Label(line, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(AppTheme.failed)
                    }
                } header: {
                    Text("Last run")
                } footer: {
                    Text("\(report.sourceName) · \(report.finished.formatted(date: .omitted, time: .standard))")
                }
            }

            Section {
                Button("Remove test habits", systemImage: "trash", role: .destructive) {
                    confirmingRemove = true
                }
            } footer: {
                Text("Deletes Test Diet and Test Sauna and all their entries, on every device once it syncs.")
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshCounts)
        .confirmationDialog("Remove the test habits?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Test Diet and Test Sauna", role: .destructive) {
                engine.removeTestHabits(in: modelContext)
                refreshCounts()
            }
        }
    }

    private func runNow() async {
        await engine.runSimulation(in: modelContext)
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
