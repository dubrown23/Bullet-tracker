//
//  SettingsView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/15/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Document Picker Delegate

@MainActor
class DocumentPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onDocumentsPicked?(url)
    }
}

// MARK: - View Model

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var reminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @Published var reminderTime: Date = UserDefaults.standard.object(forKey: "reminderTime") as? Date ?? defaultReminderTime
    @Published var iCloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
        didSet {
            if iCloudSyncEnabled != oldValue {
                NotificationCenter.default.post(
                    name: Notification.Name("iCloudSyncSettingChanged"),
                    object: nil
                )
            }
        }
    }
    
    @Published var showingExportActionSheet = false
    @Published var showingImportPicker = false
    @Published var showingClearDataAlert = false
    @Published var showingExportProgressAlert = false
    @Published var showingImportResultAlert = false
    @Published var alertMessage = ""
    @Published var importSuccess = false
    
    @Published var showingMonthPicker = false
    @Published var selectedMonth = Date()
    
    @Published var documentPickerDelegate = DocumentPickerDelegate()
    
    // MARK: - Constants
    
    enum Constants {
        static let notificationIdentifier = "bulletJournalReminder"
        static let notificationTitle = "Bullet Journal Reminder"
        static let notificationBody = "Time to log your day in your Bullet Journal"
        
        static let syncEnabledMessage = "iCloud sync enabled. Your data will sync across all devices signed into the same iCloud account."
        static let syncDisabledMessage = "iCloud sync disabled. Data will only be stored locally on this device."
        
        static let defaultCollectionNames = ["Daily Log", "Monthly Log", "Future Log", "Habit Tracker"]
        static let entityNames = ["JournalEntry", "Collection", "Tag", "Habit", "HabitEntry"]
    }
    
    private static let defaultReminderTime: Date = {
        Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    }()
    
    // MARK: - Public Methods
    
    func savePreferences() {
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
        UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
        
        scheduleReminder()
    }
    
    func scheduleReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard reminderEnabled else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            if granted {
                Task { @MainActor in
                    self?.scheduleNotification()
                }
            }
        }
    }
    
    func exportHabitsCSV(from viewController: UIViewController, sourceView: UIView) {
        performExport(
            DataExportManager.shared.exportHabitsToCSV(),
            message: "Failed to export habits data",
            from: viewController,
            sourceView: sourceView
        )
    }
    
    func exportHabitsCSVWithStats(from viewController: UIViewController, sourceView: UIView) {
        performExport(
            DataExportManager.shared.exportHabitsToCSVWithStats(),
            message: "Failed to export habits data with statistics",
            from: viewController,
            sourceView: sourceView
        )
    }
    
    func exportEntriesCSV(from viewController: UIViewController, sourceView: UIView) {
        performExport(
            DataExportManager.shared.exportHabitEntriesToCSV(),
            message: "Failed to export entries data",
            from: viewController,
            sourceView: sourceView
        )
    }
    
    func exportMonthlyReport(from viewController: UIViewController, sourceView: UIView, date: Date) {
        let alert = createProgressAlert()
        viewController.present(alert, animated: true)
        
        Task {
            let url = await Task.detached {
                DataExportManager.shared.exportMonthlyReport(for: date)
            }.value
            
            if let url = url {
                await presentShareSheet(for: url, from: viewController, sourceView: sourceView, dismissingAlert: alert)
            } else {
                await presentExportError(from: viewController, dismissingAlert: alert)
            }
        }
    }
    
    func exportFullBackup(from viewController: UIViewController, sourceView: UIView) {
        performExport(
            DataExportManager.shared.exportAppDataToJSON(),
            message: "Failed to create backup",
            from: viewController,
            sourceView: sourceView
        )
    }
    
    func importData() {
        showingImportPicker = true
    }
    
    func processImportedFile(url: URL) {
        DataExportManager.shared.importAppDataFromJSON(url: url) { [weak self] success, message in
            self?.importSuccess = success
            self?.alertMessage = message
            self?.showingImportResultAlert = true
        }
    }
    
    func clearAllData() {
        let context = CoreDataManager.shared.container.viewContext
        
        clearEntities(in: context)
        saveContext(context)
        createDefaultCollections()
    }
    
    // MARK: - Private Methods
    
    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = Constants.notificationTitle
        content.body = Constants.notificationBody
        content.sound = .default
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    private func performExport(_ url: URL?, message: String, from viewController: UIViewController, sourceView: UIView) {
        if let url = url {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            showExportError(message: message)
        }
    }
    
    private func showExportError(message: String) {
        alertMessage = message
        showingExportProgressAlert = true
    }
    
    private func createProgressAlert() -> UIAlertController {
        UIAlertController(
            title: "Generating Report",
            message: "Please wait...",
            preferredStyle: .alert
        )
    }
    
    private func presentShareSheet(for url: URL, from viewController: UIViewController, sourceView: UIView, dismissingAlert alert: UIAlertController) async {
        await MainActor.run {
            alert.dismiss(animated: true) {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = sourceView
                    popoverController.sourceRect = sourceView.bounds
                }
                
                viewController.present(activityVC, animated: true)
            }
        }
    }
    
    private func presentExportError(from viewController: UIViewController, dismissingAlert alert: UIAlertController) async {
        await MainActor.run {
            alert.dismiss(animated: true) {
                let errorAlert = UIAlertController(
                    title: "Export Failed",
                    message: "Failed to create monthly report. Please try again.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                viewController.present(errorAlert, animated: true)
            }
        }
    }
    
    private func clearEntities(in context: NSManagedObjectContext) {
        for entityName in Constants.entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(batchDeleteRequest)
            } catch {
                // Handle error silently
            }
        }
    }
    
    private func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            // Handle error silently
        }
    }
    
    private func createDefaultCollections() {
        let context = CoreDataManager.shared.container.viewContext
        
        for name in Constants.defaultCollectionNames {
            let collection = Collection(context: context)
            collection.id = UUID()
            collection.name = name
        }
        
        do {
            try context.save()
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Main View

struct SettingsView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = SettingsViewModel()
    
    // MARK: - Constants
    
    private enum Layout {
        static let iconWidth: CGFloat = 30
        static let cornerRadius: CGFloat = 10
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                syncSection
                remindersSection
                dataManagementSection
                aboutSection
            }
            .navigationTitle("Settings")
            .actionSheet(isPresented: $viewModel.showingExportActionSheet) {
                exportActionSheet
            }
            .sheet(isPresented: $viewModel.showingImportPicker) {
                importPickerSheet
            }
            .sheet(isPresented: $viewModel.showingMonthPicker) {
                monthPickerSheet
            }
            .alert("Import Result", isPresented: $viewModel.showingImportResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Export Error", isPresented: $viewModel.showingExportProgressAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Clear All Data", isPresented: $viewModel.showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("Are you sure you want to clear all journal data? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var syncSection: some View {
        Section(header: Text("Sync")) {
            Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)
                .onChange(of: viewModel.iCloudSyncEnabled) { _, newValue in
                    viewModel.savePreferences()
                    viewModel.alertMessage = newValue
                        ? SettingsViewModel.Constants.syncEnabledMessage
                        : SettingsViewModel.Constants.syncDisabledMessage
                    viewModel.showingImportResultAlert = true
                }
            
            if viewModel.iCloudSyncEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Syncing with iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var remindersSection: some View {
        Section(header: Text("Reminders")) {
            Toggle("Daily Reminder", isOn: $viewModel.reminderEnabled)
                .onChange(of: viewModel.reminderEnabled) { _, _ in
                    viewModel.savePreferences()
                }
            
            if viewModel.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $viewModel.reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: viewModel.reminderTime) { _, _ in
                    viewModel.savePreferences()
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            NavigationLink(destination: BackupRestoreView()) {
                Label("Backup & Restore", systemImage: "arrow.clockwise.icloud")
            }
            
            Button(action: { viewModel.showingExportActionSheet = true }) {
                Label("Export Data", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.primary)
            }
            
            Button(action: { viewModel.showingMonthPicker = true }) {
                Label("Monthly Habit Report", systemImage: "calendar")
                    .foregroundStyle(.primary)
            }
            
            Button(action: viewModel.importData) {
                Label("Import Backup", systemImage: "square.and.arrow.down")
                    .foregroundStyle(.primary)
            }
            
            Button(action: { viewModel.showingClearDataAlert = true }) {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Made with")
                Spacer()
                Text("❤️ & SwiftUI")
                    .foregroundStyle(.secondary)
            }
            
            NavigationLink {
                Text("This would show additional information about the app, how to use it, etc.")
                    .padding()
            } label: {
                Label("Help & Support", systemImage: "questionmark.circle")
            }
        }
    }
    
    // MARK: - Sheets and Alerts
    
    private var exportActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Export Data"),
            message: Text("Choose what data to export"),
            buttons: [
                .default(Text("Export Habits as CSV")) {
                    performExport(viewModel.exportHabitsCSV)
                },
                .default(Text("Export Habits with Statistics")) {
                    performExport(viewModel.exportHabitsCSVWithStats)
                },
                .default(Text("Export Habit Entries as CSV")) {
                    performExport(viewModel.exportEntriesCSV)
                },
                .default(Text("Full Backup (JSON)")) {
                    performExport(viewModel.exportFullBackup)
                },
                .cancel()
            ]
        )
    }
    
    private var importPickerSheet: some View {
        ImportDocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
            viewModel.processImportedFile(url: url)
        }
    }
    
    private var monthPickerSheet: some View {
        MonthPickerView(selectedMonth: $viewModel.selectedMonth) {
            performExport { viewController, sourceView in
                viewModel.exportMonthlyReport(
                    from: viewController,
                    sourceView: sourceView,
                    date: viewModel.selectedMonth
                )
                viewModel.showingMonthPicker = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performExport(_ action: @escaping (UIViewController, UIView) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        action(rootVC, window)
    }
}

// MARK: - Supporting Views

struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    let onExport: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    
    private enum Layout {
        static let verticalSpacing: CGFloat = 20
        static let cornerRadius: CGFloat = 10
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Layout.verticalSpacing) {
                Text("Select Month for Report")
                    .font(.headline)
                    .padding(.top)
                
                DatePicker(
                    "Month",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Button(action: {
                    selectedMonth = selectedDate
                    onExport()
                }) {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(Layout.cornerRadius)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel", action: dismiss.callAsFunction))
        }
    }
}

// MARK: - UIKit Bridges

struct ImportDocumentPickerView: UIViewControllerRepresentable {
    let delegate: DocumentPickerDelegate
    let onPick: (URL) -> Void
    
    init(delegate: DocumentPickerDelegate, onPick: @escaping (URL) -> Void) {
        self.delegate = delegate
        self.onPick = onPick
        delegate.onDocumentsPicked = onPick
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = delegate
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
