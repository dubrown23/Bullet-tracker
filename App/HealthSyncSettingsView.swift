//
//  HealthSyncSettingsView.swift
//  Bullet Tracker
//
//  bt-0019. Settings → "Dustin's Health". On the iPhone: paste the app's
//  key once (trimmed, stored in the Keychain on this device only), then a
//  status line, Sync now, anything the app couldn't apply (with Dismiss),
//  and Remove key. On the iPad: one line — it syncs on the iPhone and shows
//  what iCloud brings. Release builds too; this is the one piece of the
//  sync Dustin touches.
//

import SwiftUI
import SwiftData

struct HealthSyncSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine = HabitSyncEngine.shared
    @State private var pastedKey = ""
    @State private var hasKey = APIKeyStore.hasKey
    @State private var saveError: String?
    @State private var confirmingRemove = false

    var body: some View {
        Section {
            if !HabitSyncEngine.isGradingDevice {
                Label {
                    Text("Syncs on the iPhone. This iPad shows what it brings.")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "iphone")
                }
            } else if !hasKey {
                SecureField("Paste the app key", text: $pastedKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") { save() }
                    .disabled(APIKeyStore.trimmed(pastedKey) == nil || engine.isRunning)
                if let saveError {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.failed)
                }
            } else {
                statusRow
                Button {
                    Task { await engine.syncNow(in: modelContext) }
                } label: {
                    if engine.isRunning {
                        HStack {
                            Text("Syncing…")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(engine.isRunning)

                ForEach(engine.status.unapplied) { action in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                            Text(action.reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Dismiss") {
                            Task { await engine.dismiss(action) }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button("Remove key", role: .destructive) {
                    confirmingRemove = true
                }
            }
        } header: {
            Text("Dustin's Health")
        } footer: {
            footer
        }
        .confirmationDialog("Remove the key?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                engine.disconnectFromHealth()
                hasKey = false
                pastedKey = ""
            }
        } message: {
            Text("The app stops syncing with Dustin's Health until a key is pasted again. Nothing already in the app changes.")
        }
    }

    // MARK: - Pieces

    private var statusRow: some View {
        let status = engine.status
        return Label {
            Text(statusText(status))
        } icon: {
            Image(systemName: statusIcon(status))
                .foregroundStyle(statusColor(status))
        }
    }

    @ViewBuilder
    private var footer: some View {
        if !HabitSyncEngine.isGradingDevice {
            Text("Only the iPhone grades and syncs, so voice ticks and meal facts never arrive here twice.")
        } else if !hasKey {
            Text("Paste the key once. It is stored in this iPhone's Keychain only — not in iCloud, not in a backup. The app then syncs every time it opens and when you pull down on Today.")
        } else if !engine.status.unapplied.isEmpty {
            Text("Items under the status are voice actions the app couldn't use. They stay waiting on Dustin's Health until you dismiss them.")
        } else {
            Text("Syncs when the app opens and when you pull down on Today.")
        }
    }

    private func statusText(_ status: HabitSyncEngine.SyncStatus) -> String {
        if status.keyRejected { return "Key rejected" }
        if let error = status.lastError {
            if let last = status.lastSuccess {
                return "Offline, will retry · last synced \(last.formatted(date: .omitted, time: .shortened)) · \(error)"
            }
            return "Offline, will retry · \(error)"
        }
        guard let last = status.lastSuccess else { return "Not synced yet" }
        var text = "Connected · synced \(last.formatted(date: .omitted, time: .shortened))"
        if status.lastAppliedCount > 0 {
            text += " · \(status.lastAppliedCount) voice action\(status.lastAppliedCount == 1 ? "" : "s") applied"
        }
        return text
    }

    private func statusIcon(_ status: HabitSyncEngine.SyncStatus) -> String {
        if status.keyRejected { return "key.slash" }
        if status.lastError != nil { return "wifi.exclamationmark" }
        return status.lastSuccess == nil ? "circle.dashed" : "checkmark.circle.fill"
    }

    private func statusColor(_ status: HabitSyncEngine.SyncStatus) -> Color {
        if status.keyRejected { return AppTheme.failed }
        if status.lastError != nil { return AppTheme.partial }
        return status.lastSuccess == nil ? .secondary : AppTheme.success
    }

    private func save() {
        do {
            try APIKeyStore.save(pastedKey)
            pastedKey = ""
            saveError = nil
            hasKey = true
            Task { await engine.syncNow(in: modelContext) }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            HealthSyncSection()
        }
    }
    .modelContainer(for: [Habit.self, HabitEntry.self, Note.self], inMemory: true)
}
