//
//  Constants.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import Foundation

enum EntryType: String, CaseIterable, Identifiable {
    case task
    case event
    case note
    
    var id: String { self.rawValue }
    
    var symbol: String {
        switch self {
        case .task: return "•"
        case .event: return "○"
        case .note: return "—"
        }
    }
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case pending
    case completed
    case migrated
    case scheduled
    
    var id: String { self.rawValue }
    
    var symbol: String {
        switch self {
        case .pending: return "•"
        case .completed: return "✓"
        case .migrated: return ">"
        case .scheduled: return "<"
        }
    }
}
