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

    /// Every persisted model type. `Collection` / `JournalEntry` / `Tag` were
    /// dropped in bt-0003 Wave 1 (the dormant bullet-journal layer was never
    /// wired to UI; live Journal tab uses `Note`).
    static let schema = Schema([
        Habit.self,
        HabitEntry.self,
        Note.self,
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
    ///
    /// ⚠️ CloudKit is temporarily DISABLED (`cloudKitDatabase: .none`) for the
    /// bt-0003 Wave 1 recovery (2026-05-13). The Wave 1 schema-shrink + CloudKit
    /// `HistoryExpired` interaction produced invalidated-instance crashes. The
    /// recovery flow: disable CloudKit → wipe app + iCloud data → reinstall →
    /// restore from JSON backup → verify works → re-enable CloudKit. Flip back
    /// to `.automatic` before any further wave ships. (Do not leave this in
    /// `.none` permanently — the widget + cross-device sync rely on it.)
    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("DataStore: failed to create ModelContainer — \(error)")
        }
    }()
}
