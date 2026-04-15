//
//  SettingsView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/15/25.
//

import SwiftUI
import CoreData

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

        static let defaultCollectionNames = ["Daily Log", "Monthly Log", "Future Log", "Habit Tracker"]
        static let entityNames = ["JournalEntry", "Collection", "Tag", "Habit", "HabitEntry", "Note"]
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
        let context = CoreDataManager.shared.container.viewContext

        for entityName in Constants.entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            _ = try? context.execute(batchDeleteRequest)
        }

        try? context.save()
        createDefaultCollections(in: context)

        showAlert(title: "Data Cleared", message: "All data has been cleared successfully.")
    }

    private func createDefaultCollections(in context: NSManagedObjectContext) {
        for name in Constants.defaultCollectionNames {
            let collection = Collection(context: context)
            collection.id = UUID()
            collection.name = name
        }
        try? context.save()
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let iCloudSyncSettingChanged = Notification.Name("iCloudSyncSettingChanged")
}

// MARK: - Main View

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                syncSection
                remindersSection
                dataManagementSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showingExportJournal) {
                JournalExportView()
            }
            .alert(item: $viewModel.alertConfig) { config in
                createAlert(from: config)
            }
        }
    }

    // MARK: - Sections

    private var syncSection: some View {
        Section(header: Text("Sync")) {
            Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)
                .tint(AppTheme.accent)

            if viewModel.iCloudSyncEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text("Syncing with iCloud")
                        .font(AppTheme.Font.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var remindersSection: some View {
        Section(header: Text("Reminders")) {
            Toggle("Daily Reminder", isOn: $viewModel.reminderEnabled)
                .tint(AppTheme.accent)

            if viewModel.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $viewModel.reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .tint(AppTheme.accent)
            }
        }
    }

    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            NavigationLink(destination: BackupRestoreView()) {
                Label("Backup & Restore", systemImage: "arrow.clockwise.icloud")
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Button(action: { viewModel.showingExportJournal = true }) {
                Label("Export Journal", systemImage: "square.and.arrow.up")
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Button(action: viewModel.confirmClearData) {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(AppTheme.failed)
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            LabeledContent("Version", value: "1.0")

            LabeledContent("Made with", value: "❤️ & SwiftUI")

            NavigationLink {
                HelpView()
            } label: {
                Label("Help & Support", systemImage: "questionmark.circle")
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    // MARK: - Alert Builder

    private func createAlert(from config: SettingsViewModel.AlertConfig) -> Alert {
        if let primary = config.primaryButton, let secondary = config.secondaryButton {
            return Alert(
                title: Text(config.title),
                message: Text(config.message),
                primaryButton: .init(primary.role, action: primary.action) { Text(primary.title) },
                secondaryButton: .init(secondary.role, action: secondary.action) { Text(secondary.title) }
            )
        } else {
            return Alert(
                title: Text(config.title),
                message: Text(config.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Alert Button Extension

private extension Alert.Button {
    init(_ role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Text) {
        guard let role = role else {
            self = .default(label(), action: action)
            return
        }

        if role == .destructive {
            self = .destructive(label(), action: action)
        } else if role == .cancel {
            self = .cancel(label(), action: action)
        } else {
            self = .default(label(), action: action)
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                helpSection(
                    title: "Getting Started",
                    content: "Track your daily habits by tapping on the checkboxes in the Habits tab. Swipe through dates to view your history."
                )

                helpSection(
                    title: "Dashboard",
                    content: "View your habit statistics, streaks, and completion rates at a glance."
                )

                helpSection(
                    title: "Journal",
                    content: "Add notes and review your daily activity. Tap on a date to see details for that day."
                )

                helpSection(
                    title: "Backup & Sync",
                    content: "Enable iCloud Sync to keep your data synchronized across all your devices. Use Backup & Restore for manual backups."
                )

                helpSection(
                    title: "Export Journal",
                    content: "Export your journal entries as PDF for archiving or JSON for backup. Choose custom date ranges."
                )
            }
            .padding(AppTheme.Spacing.lg)
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Font.headline)
            Text(content)
                .font(AppTheme.Font.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

#Preview {
    SettingsView()
}
