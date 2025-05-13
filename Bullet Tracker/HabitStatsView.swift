//
//  HabitStatsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct HabitStatsView: View {
    let habits: [Habit]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Progress")
                .font(.headline)
            
            ForEach(habits) { habit in
                HabitProgressView(habit: habit)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}