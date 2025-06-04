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
    
    // MARK: - State Properties
    
    @State private var detailSummary: String = ""
    @State private var hasLoaded: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if !detailSummary.isEmpty {
                detailSummaryView
            }
        }
        .onAppear {
            if !hasLoaded {
                loadDetailSummary()
                hasLoaded = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var detailSummaryView: some View {
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
    
    // MARK: - Helper Methods
    
    /// Loads and formats the detail summary for display
    private func loadDetailSummary() {
        guard let details = CoreDataManager.shared.getHabitEntryDetails(habit: habit, date: date) else {
            return
        }
        
        // Check if it's potentially JSON
        if details.hasPrefix("{") && details.hasSuffix("}") {
            parseJSONDetails(details)
        } else {
            // Plain text details
            detailSummary = truncateDetails(details)
        }
    }
    
    /// Parses JSON-formatted details and creates a summary
    private func parseJSONDetails(_ details: String) {
        guard let data = details.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            detailSummary = truncateDetails(details)
            return
        }
        
        // Handle multiple workout types
        if let types = json["types"] as? [String], !types.isEmpty {
            let typesList = types.prefix(2).joined(separator: ", ")
            let moreIndicator = types.count > 2 ? "+" : ""
            
            if let duration = json["duration"] as? String {
                detailSummary = "\(typesList)\(moreIndicator) • \(duration) min"
            } else {
                detailSummary = "\(typesList)\(moreIndicator)"
            }
        }
        // Fallback to old single type format
        else if let type = json["type"] as? String, let duration = json["duration"] as? String {
            detailSummary = "\(type) • \(duration) min"
        } else if let notes = json["notes"] as? String, !notes.isEmpty {
            // Just show truncated notes
            detailSummary = truncateDetails(notes)
        }
    }
    
    /// Truncates details to a maximum length
    private func truncateDetails(_ details: String) -> String {
        let maxLength = 20
        if details.count > maxLength {
            let index = details.index(details.startIndex, offsetBy: maxLength)
            return String(details[..<index]) + "..."
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
