//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitCompletionDetailView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    let date: Date
    
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @State private var details: String = ""
    @State private var isLoading: Bool = true
    @State private var completionState: Int = 1  // 0: none, 1: success, 2: partial, 3: failure
    
    // Workout-specific fields
    @State private var isWorkout: Bool = false
    @State private var duration: String = ""
    @State private var selectedWorkoutTypes: Set<String> = []
    @State private var intensity: Int = 3
    
    // MARK: - Constants
    
    let workoutTypes = ["Cardio", "Strength", "Functional", "Core/Pre-Hab", "HIIT/Jump", "Sports", "Other"]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                habitInfoSection
                
                if isWorkoutHabit() {
                    workoutSection
                }
                
                notesSection
            }
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDetails()
                    }
                }
            }
            .onAppear {
                loadExistingDetails()
            }
        }
    }
    
    // MARK: - View Components
    
    private var habitInfoSection: some View {
        Section(header: Text("Completion Details")) {
            HStack {
                Image(systemName: habit.icon ?? "circle.fill")
                    .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
                
                Text(habit.name ?? "Habit")
                    .font(.headline)
            }
            
            Text(formatDate(date))
                .foregroundStyle(.secondary)
            
            // Only show completion state picker if habit uses multiple states
            if useMultipleStates() {
                Picker("Completion", selection: $completionState) {
                    Text("Success").tag(1)
                    Text("Partial").tag(2)
                    Text("Attempted").tag(3)
                }
                .pickerStyle(.segmented)
                
                Text(stateExplanation())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var workoutSection: some View {
        Section(header: Text("Workout Information")) {
            // Multi-select workout types
            ForEach(workoutTypes, id: \.self) { workoutType in
                Button(action: {
                    if selectedWorkoutTypes.contains(workoutType) {
                        selectedWorkoutTypes.remove(workoutType)
                    } else {
                        selectedWorkoutTypes.insert(workoutType)
                    }
                }) {
                    HStack {
                        Text(workoutType)
                        Spacer()
                        if selectedWorkoutTypes.contains(workoutType) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            
            // Summary of selected types
            if !selectedWorkoutTypes.isEmpty {
                Text("Selected: \(selectedWorkoutTypes.sorted().joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            HStack {
                Text("Duration")
                Spacer()
                TextField("Minutes", text: $duration)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("min")
            }
            
            VStack(alignment: .leading) {
                Text("Intensity")
                HStack {
                    Text("Light")
                    Slider(value: .init(get: {
                        Double(intensity)
                    }, set: { newValue in
                        intensity = Int(newValue)
                    }), in: 1...5, step: 1)
                    Text("Intense")
                }
                Text("\(intensity) / 5")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextEditor(text: $details)
                .frame(minHeight: 100)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns explanation text based on the current completion state
    private func stateExplanation() -> String {
        switch completionState {
        case 1:
            return "Full completion - you did everything planned!"
        case 2:
            return "Partial completion - you did some but not all of it."
        case 3:
            return "Attempted but struggled - you made an effort but had difficulty."
        default:
            return ""
        }
    }
    
    /// Checks if multiple states are enabled for this habit
    private func useMultipleStates() -> Bool {
        return (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    /// Determines if this is a workout-related habit
    private func isWorkoutHabit() -> Bool {
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        let hasWorkoutKeyword = workoutKeywords.contains { keyword in
            habitName.contains(keyword)
        }
        
        return hasWorkoutKeyword || detailType == "workout"
    }
    
    /// Loads existing details for the habit entry
    private func loadExistingDetails() {
        guard let existingDetails = CoreDataManager.shared.getHabitEntryDetails(habit: habit, date: date) else {
            isLoading = false
            return
        }
        
        details = existingDetails
        
        // Try to parse workout data if it's in JSON format
        if let data = existingDetails.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Load completion state if using multiple states
            if useMultipleStates() {
                completionState = json["completionState"] as? Int ?? 1
            }
            
            // Load multiple workout types if available
            if let types = json["types"] as? [String] {
                selectedWorkoutTypes = Set(types)
            } else if let type = json["type"] as? String {
                // Fallback to single type for backward compatibility
                selectedWorkoutTypes = [type]
            }
            
            if let durationValue = json["duration"] as? String {
                duration = durationValue
            }
            if let intensityValue = json["intensity"] as? Int {
                intensity = intensityValue
            }
            if let notes = json["notes"] as? String {
                details = notes
            }
        }
        
        isLoading = false
    }
    
    /// Saves the details to Core Data
    private func saveDetails() {
        var detailsToSave = details
        
        // For workout habits, save structured data as JSON
        if isWorkoutHabit() {
            var workoutData: [String: Any] = [
                "types": Array(selectedWorkoutTypes),
                "type": selectedWorkoutTypes.first ?? "",  // Keep single type for backward compatibility
                "duration": duration,
                "intensity": intensity,
                "notes": details
            ]
            
            // Add completion state if using multiple states
            if useMultipleStates() {
                workoutData["completionState"] = completionState
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: workoutData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                detailsToSave = jsonString
            }
        }
        
        // Save the details to Core Data
        let entry = CoreDataManager.shared.updateHabitEntryDetails(
            habit: habit,
            date: date,
            details: detailsToSave
        )
        
        // Set completion state directly on the entry if using multiple states
        if useMultipleStates(), let entry = entry {
            entry.setValue(completionState, forKey: "completionState")
            CoreDataManager.shared.saveContext()
        }
        
        dismiss()
    }
    
    /// Formats the date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Morning Workout"
    habit.icon = "figure.run"
    habit.color = "#FF3B30"
    
    return HabitCompletionDetailView(habit: habit, date: Date())
}
