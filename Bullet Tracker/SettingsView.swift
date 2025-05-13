//
//  SettingsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

class SettingsViewModel: ObservableObject {
    @Published var useDarkMode: Bool = UserDefaults.standard.bool(forKey: "useDarkMode")
    @Published var reminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @Published var reminderTime: Date = UserDefaults.standard.object(forKey: "reminderTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
    
    @Published var showingExportSheet = false
    @Published var showingImportSheet = false
    @Published var showingClearDataAlert = false
    
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
    
    // Clear all app data
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
                        viewModel.showingExportSheet = true
                    }) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        viewModel.showingImportSheet = true
                    }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: {
                        viewModel.showingClearDataAlert = true
                    }) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
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
