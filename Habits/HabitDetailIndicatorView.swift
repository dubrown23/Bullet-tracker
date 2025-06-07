//
//  HabitDetailIndicatorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitDetailIndicatorView: View {
    // MARK: - Properties
    
    let habit: Habit
    let date: Date
    
    // MARK: - Constants
    
    private let maxSummaryLength = 20
    private let maxTypesToShow = 2
    
    // MARK: - Computed Properties
    
    private var detailSummary: String {
        guard let details = CoreDataManager.shared.getHabitEntryDetails(habit: habit, date: date) else {
            return ""
        }
        
        // Check if it's JSON
        if details.hasPrefix("{") && details.hasSuffix("}") {
            return parseJSONDetails(details)
        } else {
            // Plain text details
            return truncateDetails(details)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if !detailSummary.isEmpty {
                Text(detailSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 100)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Parses JSON-formatted details and creates a summary
    private func parseJSONDetails(_ details: String) -> String {
        guard let data = details.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return truncateDetails(details)
        }
        
        // Handle multiple workout types
        if let types = json["types"] as? [String], !types.isEmpty {
            let typesList = types.prefix(maxTypesToShow).joined(separator: ", ")
            let moreIndicator = types.count > maxTypesToShow ? "+" : ""
            
            if let duration = json["duration"] as? String {
                return "\(typesList)\(moreIndicator) • \(duration) min"
            } else {
                return "\(typesList)\(moreIndicator)"
            }
        }
        // Fallback to old single type format
        else if let type = json["type"] as? String, let duration = json["duration"] as? String {
            return "\(type) • \(duration) min"
        }
        // Show truncated notes if available
        else if let notes = json["notes"] as? String, !notes.isEmpty {
            return truncateDetails(notes)
        }
        
        return ""
    }
    
    /// Truncates details to a maximum length
    private func truncateDetails(_ details: String) -> String {
        if details.count > maxSummaryLength {
            return details.prefix(maxSummaryLength) + "..."
        }
        return details
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Morning Workout"
    
    return HabitDetailIndicatorView(habit: habit, date: Date())
        .padding()
}
