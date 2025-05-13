//
//  HabitDetailIndicatorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitDetailIndicatorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

//
//  HabitDetailIndicatorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitDetailIndicatorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitDetailIndicatorView: View {
    let habit: Habit
    let date: Date
    @State private var detailSummary: String = ""
    @State private var hasLoaded: Bool = false
    
    var body: some View {
        VStack {
            if !detailSummary.isEmpty {
                Text(detailSummary)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 100)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .onAppear {
            if !hasLoaded {
                loadDetailSummary()
                hasLoaded = true
            }
        }
    }
    
    private func loadDetailSummary() {
        if let details = CoreDataManager.shared.getHabitEntryDetails(habit: habit, date: date) {
            // Check if it's potentially JSON
            if details.hasPrefix("{") && details.hasSuffix("}") {
                // Try to parse as JSON
                if let data = details.data(using: String.Encoding.utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
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
            } else {
                // Plain text details
                detailSummary = truncateDetails(details)
            }
        }
    }
    
    private func truncateDetails(_ details: String) -> String {
        let maxLength = 20
        if details.count > maxLength {
            let index = details.index(details.startIndex, offsetBy: maxLength)
            return String(details[..<index]) + "..."
        }
        return details
    }
}
