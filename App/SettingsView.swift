//
//  SettingsView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/15/25.
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
class SettingsViewModel {
    // MARK: - Properties

    var reminderEnabled: Bool {
        didSet { savePreferences() }
    }
    var reminderTime: Date {
        didSet { savePreferences() }
    }
    var iCloudSyncEnabled: Bool {
        didSet {
            if iCloudSyncEnabled != oldValue {
                savePreferences()
                NotificationCenter.default.post(name: .iCloudSyncSettingChanged, object: nil)
                showAlert(
                    title: "iCloud Sync",
                    message: iCloudSyncEnabled ? Constants.syncEnabledMessage : Constants.syncDisabledMessage
                )
            }
        }
    }

    // Alert state
    var alertConfig: AlertConfig?

    // Sheet state
    var showingExportJournal = false

    /// Set by the view in `.onAppear`; SwiftData contexts can't be created in the VM's init.
    var modelContext: ModelContext?

    // MARK: - Types

    struct AlertConfig: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryButton: AlertButton?
        let secondaryButton: AlertButton?

        struct AlertButton {
            let title: String
            let role: ButtonRole?
            let action: () -> Void
        }

        init(title: String, message: String, primaryButton: AlertButton? = nil, secondaryButton: AlertButton? = nil) {
            self.title = title
            self.message = message
            self.primaryButton = primaryButton
            self.secondaryButton = secondaryButton
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let notificationIdentifier = "bulletJournalReminder"
        static let notificationTitle = "Bullet Journal Reminder"
        static let notificationBody = "Time to log your day in your Bullet Journal"

        static let syncEnabledMessage = "Your data will sync across all devices signed into the same iCloud account."
        static let syncDisabledMessage = "Data will only be stored locally on this device."
    }

    // MARK: - Initialization

    init() {
        self.reminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        self.reminderTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date
            ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    // MARK: - Public Methods

    func confirmClearData() {
        alertConfig = AlertConfig(
            title: "Clear All Data",
            message: "Are you sure you want to clear all journal data? This action cannot be undone.",
            primaryButton: .init(title: "Cancel", role: .cancel, action: {}),
            secondaryButton: .init(title: "Clear", role: .destructive, action: { [weak self] in
                self?.clearAllData()
            })
        )
    }

    // MARK: - Private Methods

    private func savePreferences() {
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
        UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")

        scheduleReminder()
    }

    private func scheduleReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        guard reminderEnabled else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor in
                self?.createNotification()
            }
        }
    }

    private func createNotification() {
        let content = UNMutableNotificationContent()
        content.title = Constants.notificationTitle
        content.body = Constants.notificationBody
        content.sound = .default

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = calendar.component(.hour, from: reminderTime)
        dateComponents.minute = calendar.component(.minute, from: reminderTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Constants.notificationIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func showAlert(title: String, message: String) {
        alertConfig = AlertConfig(title: title, message: message)
    }

    private func clearAllData() {
        guard let context = modelContext else { return }

        try? context.delete(model: HabitEntry.self)
        try? context.delete(model: Note.self)
        try? context.delete(model: Habit.self)
        try? context.save()

        showAlert(title: "Data Cleared", message: "All data has been cleared successfully.")
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let iCloudSyncSettingChanged = Notification.Name("iCloudSyncSettingChanged")
}

// MARK: - Main View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    /// bt-0022 — seconds since 1970 once the history rewrite has run; the
    /// row below hides itself after that.
    @AppStorage(HistoryMigration.doneKey) private var historyRewrittenAt: Double = 0
    /// bt-0023 — same shape: the one-time session refresh hides itself once run.
    @AppStorage(HealthRefetch.doneKey) private var healthRefetchedAt: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                syncSection
                // bt-0019 — the dh key (iPhone) / "syncs on the iPhone" (iPad).
                HealthSyncSection()
                remindersSection
                dataManagementSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.modelContext = modelContext }
            .sheet(isPresented: $viewModel.showingExportJournal) {
                JournalExportView()
            }
            // Current alert API (the `Alert` struct + `.alert(item:)` are deprecated).
            .alert(
                Text(viewModel.alertConfig?.title ?? ""),
                isPresented: isShowingAlert,
                presenting: viewModel.alertConfig
            ) { config in
                if let primary = config.primaryButton {
                    Button(primary.title, role: primary.role, action: primary.action)
                }
                if let secondary = config.secondaryButton {
                    Button(secondary.title, role: secondary.role, action: secondary.action)
                }
                if config.primaryButton == nil && config.secondaryButton == nil {
                    Button("OK") { }
                }
            } message: { config in
                Text(config.message)
            }
        }
    }

    private var isShowingAlert: Binding<Bool> {
        Binding(
            get: { viewModel.alertConfig != nil },
            set: { if !$0 { viewModel.alertConfig = nil } }
        )
    }

    // MARK: - Sections

    private var syncSection: some View {
        Section("Sync") {
            Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)

            if viewModel.iCloudSyncEnabled {
                Label {
                    Text("Syncing with iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Daily Reminder", isOn: $viewModel.reminderEnabled)

            if viewModel.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $viewModel.reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
            NavigationLink(destination: BackupRestoreView()) {
                Label("Backup & Restore", systemImage: "arrow.clockwise.icloud")
            }

            Button(action: { viewModel.showingExportJournal = true }) {
                Label("Export Journal", systemImage: "square.and.arrow.up")
            }

            // bt-0022 — one-time, gone once run.
            if historyRewrittenAt == 0 {
                NavigationLink(destination: HistoryMigrationView()) {
                    Label("Prepare Dashboard History", systemImage: "clock.arrow.circlepath")
                }
            }

            // bt-0023 — one-time, gone once run: dh's corrected session
            // calories + the day's burn from Health onto the stored rows.
            if healthRefetchedAt == 0 {
                NavigationLink(destination: HealthRefetchView()) {
                    Label("Refresh Workout Calories", systemImage: "flame")
                }
            }

            Button(role: .destructive, action: viewModel.confirmClearData) {
                Label("Clear All Data", systemImage: "trash")
            }
        }
    }

    #if DEBUG
    /// bt-0017 — Step 0 sync proof. Debug builds only; release has no section.
    private var developerSection: some View {
        Section("Developer") {
            NavigationLink {
                DeveloperSyncView()
            } label: {
                Label("Sync proof (fake dh)", systemImage: "hammer")
            }
        }
    }
    #endif

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0")

            LabeledContent("Made with", value: "SwiftUI")

            NavigationLink {
                HelpView()
            } label: {
                Label("Help & Support", systemImage: "questionmark.circle")
            }
        }
    }

}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        List {
            Section {
                helpRow(
                    title: "Getting Started",
                    content: "Track your daily habits by tapping on the checkboxes in the Today tab. Swipe through dates to view your history."
                )
            }

            Section {
                helpRow(
                    title: "Dashboard",
                    content: "View your habit statistics, streaks, and completion rates at a glance."
                )
            }

            Section {
                helpRow(
                    title: "Journal",
                    content: "Add notes and review your daily activity. Tap on a date to see details for that day."
                )
            }

            Section {
                helpRow(
                    title: "Backup & Sync",
                    content: "Enable iCloud Sync to keep your data synchronized across all your devices. Use Backup & Restore for manual backups."
                )
            }

            Section {
                helpRow(
                    title: "Export Journal",
                    content: "Export your journal entries as PDF for archiving or JSON for backup. Choose custom date ranges."
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpRow(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
