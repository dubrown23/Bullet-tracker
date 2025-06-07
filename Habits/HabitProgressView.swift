//
//  HabitProgressView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitProgressView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    
    // MARK: - Constants
    
    private enum Layout {
        static let barHeight: CGFloat = 8
        static let cornerRadius: CGFloat = 4
        static let backgroundOpacity: Double = 0.3
        static let animationDuration: Double = 0.3
        static let minimumBarWidth: CGFloat = 4
    }
    
    // MARK: - Computed Properties
    
    private var completionRate: Double {
        CoreDataManager.shared.getCompletionRateForHabit(habit)
    }
    
    private var percentageText: String {
        "\(Int(completionRate * 100))%"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name ?? "")
                .font(.subheadline)
            
            HStack {
                GeometryReader { geometry in
                    progressBar(in: geometry.size.width)
                }
                .frame(height: Layout.barHeight)
                
                Text(percentageText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize() // Prevent percentage from being compressed
            }
        }
    }
    
    // MARK: - View Components
    
    private func progressBar(in availableWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color.gray.opacity(Layout.backgroundOpacity))
            
            // Progress fill
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(hex: habit.color ?? "#007AFF"))
                .frame(width: max(Layout.minimumBarWidth, availableWidth * completionRate))
                .animation(.easeInOut(duration: Layout.animationDuration), value: completionRate)
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Daily Exercise"
    habit.color = "#34C759"
    
    return VStack(spacing: 20) {
        // Different widths to show responsiveness
        HabitProgressView(habit: habit)
            .frame(width: 300)
        
        HabitProgressView(habit: habit)
            .frame(width: 200)
        
        HabitProgressView(habit: habit)
            .padding()
    }
    .padding()
}
