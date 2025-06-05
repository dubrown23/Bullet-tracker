//
//  Bullet_TrackerApp.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

@main
struct BulletTrackerApp: App {
    // MARK: - Properties
    
    /// Shared Core Data manager instance
    private let coreDataManager = CoreDataManager.shared
    
    /// Collection manager for automatic collections
    private let collectionManager = CollectionManager()
    
    /// Migration manager for task and future entry migrations
    @StateObject private var migrationManager = MigrationManager.shared
    
    /// Scene phase monitoring
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Initialization
    
    init() {
        setupApplication()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
                .environmentObject(migrationManager)
                .onAppear(perform: handleContentViewAppear)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Perform migrations when app becomes active
                        migrationManager.performDailyMigration()
                    }
                }
                .alert("Old Tasks Found", isPresented: $migrationManager.showOldTaskAlert) {
                    Button("Move All to Future Log") {
                        migrationManager.moveTasksToFutureLog(migrationManager.oldTasksToReview)
                        migrationManager.oldTasksToReview = []
                    }
                    
                    Button("Keep in Daily Log", role: .cancel) {
                        // Just dismiss - tasks stay as is
                        migrationManager.oldTasksToReview = []
                    }
                } message: {
                    Text("You have \(migrationManager.oldTasksToReview.count) tasks that are over 5 days old. Would you like to move them to the Future Log?")
                }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Performs initial app setup
    private func setupApplication() {
        #if DEBUG
        print("🟢 App initialized!")
        print("📱 Setting up Core Data...")
        #endif
        
        // Create default collections on first launch
        coreDataManager.setupDefaultData()
        
        // Create automatic time-based collections (Future Log, Year, Month)
        collectionManager.createCurrentTimeCollections()
        
        // One-time cleanup of old automatic collections
        collectionManager.cleanupOldAutomaticCollections()
        
        #if DEBUG
        print("🔍 Checking CloudKit status...")
        #endif
    }
    
    /// Handles ContentView appearance
    private func handleContentViewAppear() {
        #if DEBUG
        print("🎯 ContentView appeared")
        print("🌥️ Testing CloudKit connection...")
        #endif
        
        // Perform initial migration check
        migrationManager.performDailyMigration()
    }
}
