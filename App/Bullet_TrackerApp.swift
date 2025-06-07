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
    
    private let coreDataManager = CoreDataManager.shared
    private let collectionManager = CollectionManager()
    @StateObject private var migrationManager = MigrationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Initialization
    
    init() {
        // Setup on first launch
        coreDataManager.setupDefaultData()
        collectionManager.createCurrentTimeCollections()
        collectionManager.cleanupOldAutomaticCollections()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
                .environmentObject(migrationManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        migrationManager.performDailyMigration()
                    }
                }
                .alert("Old Tasks Found", isPresented: $migrationManager.showOldTaskAlert) {
                    Button("Move All to Future Log") {
                        migrationManager.moveTasksToFutureLog(migrationManager.oldTasksToReview)
                        migrationManager.oldTasksToReview = []
                    }
                    Button("Keep in Daily Log", role: .cancel) {
                        migrationManager.oldTasksToReview = []
                    }
                } message: {
                    Text("You have \(migrationManager.oldTasksToReview.count) tasks that are over 5 days old. Would you like to move them to the Future Log?")
                }
        }
    }
}
