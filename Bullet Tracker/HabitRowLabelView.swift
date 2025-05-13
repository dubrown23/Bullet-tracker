//
//  HabitRowLabelView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


// HabitRowLabelView.swift
// HabitRowLabelView.swift
import SwiftUI
import CoreData

struct HabitRowLabelView: View {
    @ObservedObject var habit: Habit
    
    var body: some View {
        HStack {
            Image(systemName: habit.icon ?? "circle")
                .foregroundColor(Color(hex: habit.color ?? "#007AFF"))
            
            Text(habit.name ?? "")
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding(.leading, 8)
        .contentShape(Rectangle())
    }
}
