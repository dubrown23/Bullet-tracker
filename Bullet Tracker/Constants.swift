//
//  Constants.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import Foundation

// MARK: - Entry Type

/// Represents the different types of bullet journal entries
enum EntryType: String, CaseIterable, Identifiable {
    case task
    case event
    case note
    
    // MARK: - Identifiable
    
    var id: String { self.rawValue }
    
    // MARK: - Computed Properties
    
    /// The bullet symbol for this entry type
    var symbol: String {
        switch self {
        case .task: return "•"
        case .event: return "○"
        case .note: return "—"
        }
    }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .task: return "Task"
        case .event: return "Event"
        case .note: return "Note"
        }
    }
}

// MARK: - Task Status

/// Represents the different statuses a task can have
enum TaskStatus: String, CaseIterable, Identifiable {
    case pending
    case completed
    case migrated
    case scheduled
    
    // MARK: - Identifiable
    
    var id: String { self.rawValue }
    
    // MARK: - Computed Properties
    
    /// The symbol representing this task status
    var symbol: String {
        switch self {
        case .pending: return "•"
        case .completed: return "✓"
        case .migrated: return ">"
        case .scheduled: return "<"
        }
    }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .migrated: return "Migrated"
        case .scheduled: return "Scheduled"
        }
    }
}
