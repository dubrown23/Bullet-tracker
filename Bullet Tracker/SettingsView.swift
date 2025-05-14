//
//  SettingsView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

class SettingsViewModel: ObservableObject {
    @Published var useDarkMode: Bool = UserDefaults.standard.bool(forKey: "useDarkMode")
    @Published var reminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @Published var reminderTime: Date = UserDefaults.standard.object(forKey: "reminderTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
    
    @Published var showingExportActionSheet = false
    @Published var showingImportPicker = false
    @Published var showingClearDataAlert = false
    @Published var showingExportProgressAlert = false
    @Published var showingImportResultAlert = false
    @Published var alertMessage = ""
    @Published var importSuccess = false
    
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
    
    // Export habit entries as CSV
    func exportEntriesCSV(from viewController: UIViewController, sourceView: UIView) {
        if let url = DataExportManager.shared.exportHabitEntriesToCSV() {
            DataExportManager.shared.shareFile(url: url, from: viewController, sourceView: sourceView)
        } else {
            alertMessage = "Failed to export entries data"
            showingExportProgressAlert = true
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

// Document picker delegate to handle file imports
class DocumentPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onDocumentsPicked?(url)
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
                    
                    Button(action: {
                        viewModel.importData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            Text("Import Backup")
                        }
                    }
                    
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
                DocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
                    viewModel.processImportedFile(url: url)
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

// View to wrap UIDocumentPickerViewController
struct DocumentPickerView: UIViewControllerRepresentable {
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
