//
//  SettingsView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/15/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// Document picker delegate to handle file imports
class DocumentPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onDocumentsPicked?(url)
    }
}

class SettingsViewModel: ObservableObject {
    @Published var useDarkMode: Bool = UserDefaults.standard.bool(forKey: "useDarkMode")
    @Published var reminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @Published var reminderTime: Date = UserDefaults.standard.object(forKey: "reminderTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    
    @Published var showingExportActionSheet = false
    @Published var showingImportPicker = false
    @Published var showingClearDataAlert = false
    @Published var showingExportProgressAlert = false
    @Published var showingImportResultAlert = false
    @Published var alertMessage = ""
    @Published var importSuccess = false
    
    // Monthly report properties
    @Published var showingMonthPicker = false
    @Published var selectedMonth = Date()
    
    // For file picking
    @Published var documentPickerDelegate = DocumentPickerDelegate()
    
    // Save user preferences
    func savePreferences() {
        UserDefaults.standard.set(useDarkMode, forKey: "useDarkMode")
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
        
        setAppearance()
        scheduleReminder()
    }
    
    // Set the app's appearance based on the user's preference
    func setAppearance() {
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.first as? UIWindowScene else { return }
        guard let window = windowScene.windows.first else { return }
        
        window.overrideUserInterfaceStyle = useDarkMode ? .dark : .light
    }
    
    // Schedule or cancel the daily reminder notification
    func scheduleReminder() {
        // First, remove any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard reminderEnabled else { return }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.scheduleNotification()
                }
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Bullet Journal Reminder"
        content.body = "Time to log your day in your Bullet Journal"
        content.sound = .default
        
        // Create time components from the selected time
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Create the trigger and request
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "bulletJournalReminder", content: content, trigger: trigger)
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Reminder scheduled for \(hour):\(minute)")
            }
        }
    }
    
    // Export data
    func exportData(from viewController: UIViewController, sourceView: UIView) {
        showingExportActionSheet = true
    }
    
    // Export habits as CSV
    func exportHabitsCSV(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitsToCSV() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            alertMessage = "Failed to export habits data"
            showingExportProgressAlert = true
        }
    }
    
    // Export habits as CSV with stats
    func exportHabitsCSVWithStats(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitsToCSVWithStats() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            alertMessage = "Failed to export habits data with statistics"
            showingExportProgressAlert = true
        }
    }
    
    // Export habit entries as CSV
    func exportEntriesCSV(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitEntriesToCSV() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            alertMessage = "Failed to export entries data"
            showingExportProgressAlert = true
        }
    }
    
    // Export monthly report
    func exportMonthlyReport(from viewController: UIViewController, sourceView: UIView, date: Date) {
        print("Starting monthly report export for date: \(date)")
        
        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async {
            // Show a loading indicator
            let alert = UIAlertController(title: "Generating Report", message: "Please wait...", preferredStyle: .alert)
            viewController.present(alert, animated: true)
            
            // Do the export on a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                if let url = DataExportManager.shared.exportMonthlyReport(for: date) {
                    print("Monthly report created successfully: \(url)")
                    
                    // Return to main thread to dismiss alert and show share sheet
                    DispatchQueue.main.async {
                        // Dismiss the loading alert
                        alert.dismiss(animated: true) {
                            // Show the share sheet
                            print("Showing share sheet for url: \(url)")
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            
                            // For iPad support
                            if let popoverController = activityVC.popoverPresentationController {
                                popoverController.sourceView = sourceView
                                popoverController.sourceRect = sourceView.bounds
                            }
                            
                            viewController.present(activityVC, animated: true)
                        }
                    }
                } else {
                    print("Failed to create monthly report")
                    
                    // Return to main thread to dismiss alert and show error
                    DispatchQueue.main.async {
                        // Dismiss the loading alert
                        alert.dismiss(animated: true) {
                            // Show error alert
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
            }
        }
    }
    
    // Export full backup as JSON
    func exportFullBackup(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportAppDataToJSON() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            alertMessage = "Failed to create backup"
            showingExportProgressAlert = true
        }
    }
    
    // Import data from JSON backup
    func importData() {
        showingImportPicker = true
    }
    
    // Process the selected imported file
    func processImportedFile(url: URL) {
        DataExportManager.shared.importAppDataFromJSON(url: url) { success, message in
            self.importSuccess = success
            self.alertMessage = message
            self.showingImportResultAlert = true
        }
    }
    
    // Clear all data
    func clearAllData() {
        let context = CoreDataManager.shared.container.viewContext
        let entityNames = ["JournalEntry", "Collection", "Tag", "Habit", "HabitEntry"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(batchDeleteRequest)
            } catch {
                print("Error clearing \(entityName): \(error)")
            }
        }
        
        // Save context changes
        do {
            try context.save()
            print("All data cleared successfully")
        } catch {
            print("Error saving context after clearing data: \(error)")
        }
        
        // Create default collections
        createDefaultCollections()
    }
    
    // Create default collections
    private func createDefaultCollections() {
        let context = CoreDataManager.shared.container.viewContext
        let defaultNames = ["Daily Log", "Monthly Log", "Future Log", "Habit Tracker"]
        
        for name in defaultNames {
            let collection = Collection(context: context)
            collection.id = UUID()
            collection.name = name
        }
        
        do {
            try context.save()
            print("Default collections created")
        } catch {
            print("Error creating default collections: \(error)")
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingActionSheet = false
    
    // To get access to UIViewController for sharing
    @State private var actionSourceRect: CGRect = .zero
    @State private var actionSourceView: UIView? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $viewModel.useDarkMode)
                        .onChange(of: viewModel.useDarkMode) { _ in
                            viewModel.savePreferences()
                        }
                }
                
                Section(header: Text("Reminders")) {
                    Toggle("Daily Reminder", isOn: $viewModel.reminderEnabled)
                        .onChange(of: viewModel.reminderEnabled) { _ in
                            viewModel.savePreferences()
                        }
                    
                    if viewModel.reminderEnabled {
                        DatePicker("Time", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: viewModel.reminderTime) { _ in
                                viewModel.savePreferences()
                            }
                    }
                }
                
                Section(header: Text("Data Management")) {
                    // New Backup & Restore Link
                    NavigationLink(destination: BackupRestoreView()) {
                        HStack {
                            Image(systemName: "arrow.clockwise.icloud")
                                .foregroundColor(.blue)
                            Text("Backup & Restore")
                        }
                    }
                    
                    // Export Data Button
                    Button(action: {
                        if let sourceView = actionSourceView {
                            viewModel.showingExportActionSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Export Data")
                        }
                    }
                    .background(GeometryReader { geometry -> Color in
                        DispatchQueue.main.async {
                            actionSourceRect = geometry.frame(in: .global)
                            if actionSourceView == nil {
                                actionSourceView = UIView(frame: actionSourceRect)
                            }
                        }
                        return Color.clear
                    })
                    
                    // Monthly Report Button
                    Button(action: {
                        viewModel.showingMonthPicker = true
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Monthly Habit Report")
                        }
                    }
                    
                    // Import Backup Button
                    Button(action: {
                        viewModel.importData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            Text("Import Backup")
                        }
                    }
                    
                    // Clear Data Button
                    Button(action: {
                        viewModel.showingClearDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Data")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Made with")
                        Spacer()
                        Text("❤️ & SwiftUI")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: Text("This would show additional information about the app, how to use it, etc.").padding()) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .actionSheet(isPresented: $viewModel.showingExportActionSheet) {
                ActionSheet(
                    title: Text("Export Data"),
                    message: Text("Choose what data to export"),
                    buttons: [
                        .default(Text("Export Habits as CSV")) {
                            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                               let sourceView = actionSourceView {
                                viewModel.exportHabitsCSV(from: rootVC, sourceView: sourceView)
                            }
                        },
                        .default(Text("Export Habits with Statistics")) {
                            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                               let sourceView = actionSourceView {
                                viewModel.exportHabitsCSVWithStats(from: rootVC, sourceView: sourceView)
                            }
                        },
                        .default(Text("Export Habit Entries as CSV")) {
                            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                               let sourceView = actionSourceView {
                                viewModel.exportEntriesCSV(from: rootVC, sourceView: sourceView)
                            }
                        },
                        .default(Text("Full Backup (JSON)")) {
                            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                               let sourceView = actionSourceView {
                                viewModel.exportFullBackup(from: rootVC, sourceView: sourceView)
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $viewModel.showingImportPicker) {
                ImportDocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
                    viewModel.processImportedFile(url: url)
                }
            }
            .sheet(isPresented: $viewModel.showingMonthPicker) {
                MonthPickerView(selectedMonth: $viewModel.selectedMonth) {
                    if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                       let sourceView = actionSourceView {
                        // Debug output
                        print("Exporting monthly report for: \(viewModel.selectedMonth)")
                        
                        // Ensure the action is performed on the main thread
                        DispatchQueue.main.async {
                            viewModel.exportMonthlyReport(from: rootVC, sourceView: sourceView, date: viewModel.selectedMonth)
                            viewModel.showingMonthPicker = false
                        }
                    } else {
                        print("Error: rootVC or sourceView is nil")
                        viewModel.showingMonthPicker = false
                    }
                }
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
            .onAppear {
                viewModel.setAppearance()
            }
        }
    }
}

// Month Picker Sheet for selecting a month for report export
struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    var onExport: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    private let months = Calendar.current.shortMonthSymbols
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [currentYear-1, currentYear]
    }()
    
    @State private var selectedMonthIndex: Int
    @State private var selectedYearIndex: Int
    
    init(selectedMonth: Binding<Date>, onExport: @escaping () -> Void) {
        self._selectedMonth = selectedMonth
        self.onExport = onExport
        
        // Initialize with current selection
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedMonth.wrappedValue) - 1 // 0-based
        let year = calendar.component(.year, from: selectedMonth.wrappedValue)
        let yearIndex = years.firstIndex(of: year) ?? 0
        
        self._selectedMonthIndex = State(initialValue: month)
        self._selectedYearIndex = State(initialValue: yearIndex)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Month for Report")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Picker("Month", selection: $selectedMonthIndex) {
                        ForEach(0..<months.count, id: \.self) { index in
                            Text(months[index]).tag(index)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 150)
                    
                    Picker("Year", selection: $selectedYearIndex) {
                        ForEach(0..<years.count, id: \.self) { index in
                            Text(String(format: "%d", years[index])).tag(index)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 100)
                }
                .padding()
                
                Button(action: {
                    updateSelectedDate()
                    onExport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Report")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
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

// View to wrap UIDocumentPickerViewController for the settings view
struct ImportDocumentPickerView: UIViewControllerRepresentable {
    var delegate: DocumentPickerDelegate
    var onPick: (URL) -> Void
    
    init(delegate: DocumentPickerDelegate, onPick: @escaping (URL) -> Void) {
        self.delegate = delegate
        self.onPick = onPick
        
        // Set the callback
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
