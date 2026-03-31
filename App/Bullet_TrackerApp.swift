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
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        // Setup on first launch
        coreDataManager.setupDefaultData()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
        }
    }
}
