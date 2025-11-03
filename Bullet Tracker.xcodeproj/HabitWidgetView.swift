//
//  HabitWidgetView.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import SwiftUI
import WidgetKit

struct HabitWidgetView: View {
    let entry: HabitWidgetEntry
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            // Habits List
            if entry.isEmpty {
                emptyStateView
            } else {
                habitsListView
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Habits")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(formatDate(entry.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Completion summary
            if !entry.isEmpty {
                completionSummary
            }
        }
    }
    
    private var completionSummary: some View {
        let completedCount = entry.habits.filter { $0.isCompleted }.count
        let totalCount = entry.habits.count
        
        return HStack(spacing: 4) {
            Text("\(completedCount)/\(totalCount)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(completedCount == totalCount ? .green : .secondary)
        }
    }
    
    // MARK: - Habits List View
    
    private var habitsListView: some View {
        VStack(spacing: 8) {
            ForEach(entry.habits) { habit in
                HabitRowView(habit: habit)
            }
            
            if entry.habits.count < 5 {
                Spacer()
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            
            Text("No habits for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Open app to create habits")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openApp()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func openApp() {
        guard let url = URL(string: "bullettracker://habits") else { return }
        // This will be handled by the app's URL scheme
    }
}

// MARK: - Habit Row View

struct HabitRowView: View {
    let habit: WidgetHabit
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(intent: CompleteHabitIntent(habitID: habit.id.uuidString, habitName: habit.name)) {
                completionIndicator
            }
            .buttonStyle(PlainButtonStyle())
            
            // Habit Info
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if habit.needsDetails && habit.isCompleted {
                    Text("Tap to add details")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status Icon
            if habit.needsDetails {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if habit.needsDetails {
                openHabitDetail()
            }
        }
    }
    
    private var completionIndicator: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                )
                .frame(width: 24, height: 24)
            
            completionIcon
        }
    }
    
    private var backgroundColor: Color {
        switch habit.completionState {
        case 1: return .green  // Success
        case 2: return .yellow // Partial
        case 3: return .red    // Attempted
        default: return .clear // None
        }
    }
    
    private var borderColor: Color {
        if habit.completionState == 0 {
            return Color(hex: habit.color) ?? .blue
        } else {
            return backgroundColor
        }
    }
    
    @ViewBuilder
    private var completionIcon: some View {
        switch habit.completionState {
        case 1:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        case 2:
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        case 3:
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        default:
            EmptyView()
        }
    }
    
    private func openHabitDetail() {
        guard let url = URL(string: "bullettracker://habit/\(habit.id.uuidString)") else { return }
        // This will be handled by the app's URL scheme
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}