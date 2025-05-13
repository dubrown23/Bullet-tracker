//
//  Bullet_TrackerApp.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

@main
struct BulletTrackerApp: App {
    let coreDataManager = CoreDataManager.shared
    
    init() {
        // Create default collections on first launch
        coreDataManager.setupDefaultData()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
        }
    }
}
