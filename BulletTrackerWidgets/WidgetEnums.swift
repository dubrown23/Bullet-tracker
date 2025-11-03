//
//  WidgetEnums.swift
//  BulletTrackerWidgets
//
//  Created for widget compatibility
//

import Foundation

// MARK: - Stub Enums for Widget
// These are simplified versions of the main app enums
// that satisfy CoreDataManager dependencies

enum EntryType: String, CaseIterable {
    case task = "task"
    case note = "note"
    case event = "event"
}

enum TaskStatus: String, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case cancelled = "cancelled"
}
