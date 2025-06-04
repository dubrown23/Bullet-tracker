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

class DocumentPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onDocumentsPicked?(url)
    }
}

// MARK: - View Model

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
    
    private static let defaultReminderTime: Date = {
        Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    }()
    
    private let defaultCollectionNames = ["Daily Log", "Monthly Log", "Future Log", "Habit Tracker"]
    private let entityNames = ["JournalEntry", "Collection", "Tag", "Habit", "HabitEntry"]
    
    // MARK: - Public Methods
    
    /// Saves user preferences to UserDefaults
    func savePreferences() {
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
        UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
        
        scheduleReminder()
    }
    
    /// Schedules or cancels the daily reminder notification
    func scheduleReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard reminderEnabled else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if granted {
                DispatchQueue.main.async {
                    self?.scheduleNotification()
                }
            } else if let error = error {
                #if DEBUG
                print("Notification permission error: \(error)")
                #endif
            }
        }
    }
    
    /// Exports data based on user selection
    func exportData(from viewController: UIViewController, sourceView: UIView) {
        showingExportActionSheet = true
    }
    
    /// Exports habits as CSV
    func exportHabitsCSV(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitsToCSV() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            showExportError(message: "Failed to export habits data")
        }
    }
    
    /// Exports habits with statistics as CSV
    func exportHabitsCSVWithStats(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitsToCSVWithStats() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            showExportError(message: "Failed to export habits data with statistics")
        }
    }
    
    /// Exports habit entries as CSV
    func exportEntriesCSV(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitEntriesToCSV() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            showExportError(message: "Failed to export entries data")
        }
    }
    
    /// Exports monthly report for the selected date
    func exportMonthlyReport(from viewController: UIViewController, sourceView: UIView, date: Date) {
        #if DEBUG
        print("Starting monthly report export for date: \(date)")
        #endif
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Generating Report",
                message: "Please wait...",
                preferredStyle: .alert
            )
            viewController.present(alert, animated: true)
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let url = DataExportManager.shared.exportMonthlyReport(for: date) {
                    self?.presentShareSheet(
                        for: url,
                        from: viewController,
                        sourceView: sourceView,
                        dismissingAlert: alert
                    )
                } else {
                    self?.presentExportError(
                        from: viewController,
                        dismissingAlert: alert
                    )
                }
            }
        }
    }
    
    /// Exports full backup as JSON
    func exportFullBackup(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportAppDataToJSON() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            showExportError(message: "Failed to create backup")
        }
    }
    
    /// Initiates data import process
    func importData() {
        showingImportPicker = true
    }
    
    /// Processes the selected imported file
    func processImportedFile(url: URL) {
        DataExportManager.shared.importAppDataFromJSON(url: url) { [weak self] success, message in
            self?.importSuccess = success
            self?.alertMessage = message
            self?.showingImportResultAlert = true
        }
    }
    
    /// Clears all data and creates default collections
    func clearAllData() {
        let context = CoreDataManager.shared.container.viewContext
        
        clearEntities(in: context)
        saveContext(context)
        createDefaultCollections()
    }
    
    // MARK: - Private Methods
    
    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Bullet Journal Reminder"
        content.body = "Time to log your day in your Bullet Journal"
        content.sound = .default
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: "bulletJournalReminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Reminder scheduled for \(hour):\(minute)")
            }
            #endif
        }
    }
    
    private func showExportError(message: String) {
        alertMessage = message
        showingExportProgressAlert = true
    }
    
    private func presentShareSheet(for url: URL, from viewController: UIViewController, sourceView: UIView, dismissingAlert alert: UIAlertController) {
        #if DEBUG
        print("Monthly report created successfully: \(url)")
        #endif
        
        DispatchQueue.main.async {
            alert.dismiss(animated: true) {
                let activityVC = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = sourceView
                    popoverController.sourceRect = sourceView.bounds
                }
                
                viewController.present(activityVC, animated: true)
            }
        }
    }
    
    private func presentExportError(from viewController: UIViewController, dismissingAlert alert: UIAlertController) {
        #if DEBUG
        print("Failed to create monthly report")
        #endif
        
        DispatchQueue.main.async {
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
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(batchDeleteRequest)
            } catch {
                #if DEBUG
                print("Error clearing \(entityName): \(error)")
                #endif
            }
        }
    }
    
    private func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
            #if DEBUG
            print("All data cleared successfully")
            #endif
        } catch {
            #if DEBUG
            print("Error saving context after clearing data: \(error)")
            #endif
        }
    }
    
    private func createDefaultCollections() {
        let context = CoreDataManager.shared.container.viewContext
        
        for name in defaultCollectionNames {
            let collection = Collection(context: context)
            collection.id = UUID()
            collection.name = name
        }
        
        do {
            try context.save()
            #if DEBUG
            print("Default collections created")
            #endif
        } catch {
            #if DEBUG
            print("Error creating default collections: \(error)")
            #endif
        }
    }
}

// MARK: - Main View

struct SettingsView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingActionSheet = false
    @State private var actionSourceRect: CGRect = .zero
    @State private var actionSourceView: UIView? = nil
    
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
                        ? "iCloud sync enabled. Your data will sync across all devices signed into the same iCloud account."
                        : "iCloud sync disabled. Data will only be stored locally on this device."
                    viewModel.showingImportResultAlert = true
                }
            
            if viewModel.iCloudSyncEnabled {
                syncStatusRow
            }
        }
    }
    
    private var syncStatusRow: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Syncing with iCloud")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            backupRestoreLink
            exportDataButton
            monthlyReportButton
            importBackupButton
            clearDataButton
        }
    }
    
    private var backupRestoreLink: some View {
        NavigationLink(destination: BackupRestoreView()) {
            HStack {
                Image(systemName: "arrow.clockwise.icloud")
                    .foregroundStyle(.blue)
                Text("Backup & Restore")
            }
        }
    }
    
    private var exportDataButton: some View {
        Button {
            if actionSourceView != nil {
                viewModel.showingExportActionSheet = true
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.blue)
                Text("Export Data")
                    .foregroundStyle(.primary)
            }
        }
        .background(captureSourceView)
    }
    
    private var monthlyReportButton: some View {
        Button {
            viewModel.showingMonthPicker = true
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text("Monthly Habit Report")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var importBackupButton: some View {
        Button {
            viewModel.importData()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.blue)
                Text("Import Backup")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var clearDataButton: some View {
        Button {
            viewModel.showingClearDataAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                Text("Clear All Data")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var aboutSection: some View {
        Section(header: Text("About")) {
            versionRow
            madeWithRow
            helpSupportLink
        }
    }
    
    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text("1.0")
                .foregroundStyle(.secondary)
        }
    }
    
    private var madeWithRow: some View {
        HStack {
            Text("Made with")
            Spacer()
            Text("❤️ & SwiftUI")
                .foregroundStyle(.secondary)
        }
    }
    
    private var helpSupportLink: some View {
        NavigationLink {
            Text("This would show additional information about the app, how to use it, etc.")
                .padding()
        } label: {
            Label("Help & Support", systemImage: "questionmark.circle")
        }
    }
    
    private var captureSourceView: some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                actionSourceRect = geometry.frame(in: .global)
                if actionSourceView == nil {
                    actionSourceView = UIView(frame: actionSourceRect)
                }
            }
            return Color.clear
        }
    }
    
    // MARK: - Sheets and Alerts
    
    private var exportActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Export Data"),
            message: Text("Choose what data to export"),
            buttons: exportActionSheetButtons
        )
    }
    
    private var exportActionSheetButtons: [ActionSheet.Button] {
        [
            .default(Text("Export Habits as CSV")) {
                performExport { viewController, sourceView in
                    viewModel.exportHabitsCSV(from: viewController, sourceView: sourceView)
                }
            },
            .default(Text("Export Habits with Statistics")) {
                performExport { viewController, sourceView in
                    viewModel.exportHabitsCSVWithStats(from: viewController, sourceView: sourceView)
                }
            },
            .default(Text("Export Habit Entries as CSV")) {
                performExport { viewController, sourceView in
                    viewModel.exportEntriesCSV(from: viewController, sourceView: sourceView)
                }
            },
            .default(Text("Full Backup (JSON)")) {
                performExport { viewController, sourceView in
                    viewModel.exportFullBackup(from: viewController, sourceView: sourceView)
                }
            },
            .cancel()
        ]
    }
    
    private var importPickerSheet: some View {
        ImportDocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
            viewModel.processImportedFile(url: url)
        }
    }
    
    private var monthPickerSheet: some View {
        MonthPickerView(selectedMonth: $viewModel.selectedMonth) {
            performExport { viewController, sourceView in
                #if DEBUG
                print("Exporting monthly report for: \(viewModel.selectedMonth)")
                #endif
                
                DispatchQueue.main.async {
                    viewModel.exportMonthlyReport(
                        from: viewController,
                        sourceView: sourceView,
                        date: viewModel.selectedMonth
                    )
                    viewModel.showingMonthPicker = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performExport(action: (UIViewController, UIView) -> Void) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController,
           let sourceView = actionSourceView {
            action(rootVC, sourceView)
        }
    }
}

// MARK: - Supporting Views

struct MonthPickerView: View {
    // MARK: - Properties
    
    @Binding var selectedMonth: Date
    let onExport: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let months = Calendar.current.shortMonthSymbols
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [currentYear - 1, currentYear]
    }()
    
    @State private var selectedMonthIndex: Int
    @State private var selectedYearIndex: Int
    
    // MARK: - Initialization
    
    init(selectedMonth: Binding<Date>, onExport: @escaping () -> Void) {
        self._selectedMonth = selectedMonth
        self.onExport = onExport
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedMonth.wrappedValue) - 1
        let year = calendar.component(.year, from: selectedMonth.wrappedValue)
        let yearIndex = years.firstIndex(of: year) ?? 0
        
        self._selectedMonthIndex = State(initialValue: month)
        self._selectedYearIndex = State(initialValue: yearIndex)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerText
                datePickerSection
                exportButton
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: cancelButton)
        }
    }
    
    // MARK: - View Components
    
    private var headerText: some View {
        Text("Select Month for Report")
            .font(.headline)
            .padding(.top)
    }
    
    private var datePickerSection: some View {
        HStack {
            monthPicker
            yearPicker
        }
        .padding()
    }
    
    private var monthPicker: some View {
        Picker("Month", selection: $selectedMonthIndex) {
            ForEach(0..<months.count, id: \.self) { index in
                Text(months[index]).tag(index)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 150)
    }
    
    private var yearPicker: some View {
        Picker("Year", selection: $selectedYearIndex) {
            ForEach(0..<years.count, id: \.self) { index in
                Text(String(format: "%d", years[index])).tag(index)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 100)
    }
    
    private var exportButton: some View {
        Button {
            updateSelectedDate()
            onExport()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export Report")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSelectedDate() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = years[selectedYearIndex]
        components.month = selectedMonthIndex + 1
        components.day = 1
        
        if let date = calendar.date(from: components) {
            selectedMonth = date
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
