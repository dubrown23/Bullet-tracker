//
//  AddHabitView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct AddHabitView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
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
    
    // MARK: - Computed Properties
    
    private var formIsValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
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
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(!formIsValid)
                }
            }
            .sheet(isPresented: $showingIconSheet) {
                IconSelectorView(
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveHabit() {
        let customDaysString = customDays.sorted().map(String.init).joined(separator: ",")
        
        let habit = CoreDataManager.shared.createHabit(
            name: name,
            color: selectedColor,
            icon: selectedIcon,
            frequency: selectedFrequency,
            customDays: customDaysString,
            startDate: Date(),
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
}
