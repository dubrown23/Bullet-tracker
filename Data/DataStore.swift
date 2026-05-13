//
//  DataStore.swift
//  Bullet Tracker
//
//  The SwiftData stack (bt-0002). Replaces CoreDataManager's
//  `NSPersistentCloudKitContainer`. Opens the SAME App-Group store file
//  (`BulletTracker.sqlite`) so the existing iCloud-synced data carries over in
//  place; CloudKit mirroring continues via `cloudKitDatabase: .automatic` — the
//  app's entitlements list a single iCloud container (`iCloud.db23.BulletTracker`).
//
//  ⚠️ The `storeURL` + `cloudKitDatabase` lines are the highest-risk lines in the
//  whole migration. Before trusting them: test against a COPY of real data, and
//  keep a JSON backup (Settings → export) as the fallback.
//

import Foundation
import SwiftData

enum DataStore {

    /// App Group shared between the main app and the widget extension.
    static let appGroupIdentifier = "group.db23.Bullet-Tracker"

    /// Every persisted model type.
    static let schema = Schema([
        Habit.self,
        HabitEntry.self,
        Collection.self,
        JournalEntry.self,
        Note.self,
        Tag.self,
    ])

    /// File URL of the store inside the shared App Group container — the same path
    /// the old Core Data stack used (`<AppGroup>/BulletTracker.sqlite`).
    static var storeURL: URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            fatalError("DataStore: cannot access App Group container \(appGroupIdentifier)")
        }
        return container.appendingPathComponent("BulletTracker.sqlite")
    }

    /// The shared model container. The app installs it via `.modelContainer(DataStore.shared)`;
    /// the widget extension uses the same instance so both read/write one store.
    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("DataStore: failed to create ModelContainer — \(error)")
        }
    }()
}
