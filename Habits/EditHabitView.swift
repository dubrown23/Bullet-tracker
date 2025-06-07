//
//  EditHabitView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct EditHabitView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    
    // MARK: - State Properties
    
    @State private var name = ""
    @State private var selectedIcon = "circle.fill"
    @State private var selectedColor = "#007AFF"
    @State private var selectedFrequency = "daily"
    @State private var customDays: [Int] = []
    @State private var notes = ""
    @State private var trackDetails = false
    @State private var detailType = "general"
    @State private var useMultipleStates = false
    @State private var isNegativeHabit = false
    @State private var showingIconSheet = false
    @State private var showingDeleteAlert = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                HabitFormView(
                    name: $name,
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor,
                    selectedFrequency: $selectedFrequency,
                    customDays: $customDays,
                    notes: $notes,
                    trackDetails: $trackDetails,
                    detailType: $detailType,
                    useMultipleStates: $useMultipleStates,
                    isNegativeHabit: $isNegativeHabit,
                    showingIconSheet: $showingIconSheet
                )
                
                Section {
                    Button("Delete Habit", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateHabit()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadHabitData()
            }
            .sheet(isPresented: $showingIconSheet) {
                IconSelectorView(
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor
                )
            }
            .alert("Delete Habit", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteHabit()
                }
            } message: {
                Text("Are you sure you want to delete this habit? All tracking data will be lost.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadHabitData() {
        name = habit.name ?? ""
        selectedIcon = habit.icon ?? "circle.fill"
        selectedColor = habit.color ?? "#007AFF"
        selectedFrequency = habit.frequency ?? "daily"
        notes = habit.notes ?? ""
        
        if let customDaysString = habit.customDays, !customDaysString.isEmpty {
            customDays = customDaysString
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        trackDetails = (habit.value(forKey: "trackDetails") as? Bool) ?? false
        detailType = (habit.value(forKey: "detailType") as? String) ?? "general"
        useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
        isNegativeHabit = (habit.value(forKey: "isNegativeHabit") as? Bool) ?? false
    }
    
    private func updateHabit() {
        let customDaysString = customDays.sorted().map(String.init).joined(separator: ",")
        
        CoreDataManager.shared.updateHabit(
            habit,
            name: name,
            color: selectedColor,
            icon: selectedIcon,
            frequency: selectedFrequency,
            customDays: customDaysString,
            notes: notes,
            collection: nil
        )
        
        // Set dynamic properties
        habit.setValue(trackDetails, forKey: "trackDetails")
        habit.setValue(detailType, forKey: "detailType")
        habit.setValue(isNegativeHabit ? false : useMultipleStates, forKey: "useMultipleStates")
        habit.setValue(isNegativeHabit, forKey: "isNegativeHabit")
        
        CoreDataManager.shared.saveContext()
        dismiss()
    }
    
    private func deleteHabit() {
        CoreDataManager.shared.deleteHabit(habit)
        dismiss()
    }
}
