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
    
    // MARK: - State Properties
    
    @State private var completionRate: Double = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name ?? "")
                .font(.subheadline)
            
            HStack {
                progressBar
                
                Text("\(Int(completionRate * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            completionRate = CoreDataManager.shared.getCompletionRateForHabit(habit)
        }
    }
    
    // MARK: - View Components
    
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 8)
                .cornerRadius(4)
            
            Rectangle()
                .fill(Color(hex: habit.color ?? "#007AFF"))
                .frame(width: max(4, CGFloat(completionRate) * 200), height: 8)
                .cornerRadius(4)
                .animation(.easeInOut(duration: 0.3), value: completionRate)
        }
        .frame(width: 200)
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Daily Exercise"
    habit.color = "#34C759"
    
    return HabitProgressView(habit: habit)
        .padding()
}
