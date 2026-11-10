//
//  Bullet_TrackerApp.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import SwiftData

@main
struct BulletTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(DataStore.shared)
    }
}

/// bt-0027 — HealthKit's background wake-up for a new workout needs its
/// observer set up before launch finishes, including a launch in the
/// background with no window. Nothing else lives here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        HealthCopy.shared.startBackgroundDelivery()
        return true
    }
}
