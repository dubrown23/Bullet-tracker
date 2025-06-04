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
    
    // MARK: - Initialization
    
    init() {
        setupApplication()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
                .onAppear(perform: handleContentViewAppear)
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
    }
}
