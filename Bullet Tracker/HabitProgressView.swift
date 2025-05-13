//
//  HabitProgressView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct HabitProgressView: View {
    @ObservedObject var habit: Habit
    @State private var completionRate: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name ?? "")
                .font(.subheadline)
            
            HStack {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color(hex: habit.color ?? "#007AFF"))
                        .frame(width: max(4, CGFloat(completionRate) * 200), height: 8)
                        .cornerRadius(4)
                }
                .frame(width: 200)
                
                Text("\(Int(completionRate * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            completionRate = CoreDataManager.shared.getCompletionRateForHabit(habit)
        }
    }
}