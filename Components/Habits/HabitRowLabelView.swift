//
//  HabitRowLabelView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct HabitRowLabelView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            Image(systemName: habit.icon ?? "circle")
                .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
            
            Text(habit.name ?? "")
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding(.leading, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Morning Meditation"
    habit.icon = "leaf.fill"
    habit.color = "#34C759"
    
    return HabitRowLabelView(habit: habit)
        .padding()
        .frame(width: 300)
}
