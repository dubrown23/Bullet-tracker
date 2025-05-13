//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitCompletionDetailView: View {
    @ObservedObject var habit: Habit
    let date: Date
    @Environment(\.presentationMode) var presentationMode
    
    @State private var details: String = ""
    @State private var isLoading: Bool = true
    @State private var completionState: Int = 1  // Added for multi-stage support: 0: none, 1: success, 2: partial, 3: failure
    
    // Workout-specific fields (for workout habits)
    @State private var isWorkout: Bool = false
    @State private var duration: String = ""
    @State private var selectedWorkoutTypes: Set<String> = []
    @State private var intensity: Int = 3
    
    let workoutTypes = ["Cardio", "Strength", "Flexibility", "HIIT", "Yoga", "Sports", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Completion Details")) {
                    HStack {
                        Image(systemName: habit.icon ?? "circle.fill")
                            .foregroundColor(Color(hex: habit.color ?? "#007AFF"))
                        
                        Text(habit.name ?? "Habit")
                            .font(.headline)
                    }
                    
                    Text(formatDate(date))
                        .foregroundColor(.secondary)
                    
                    // Only show completion state picker if habit uses multiple states
                    if useMultipleStates() {
                        Picker("Completion", selection: $completionState) {
                            Text("Success").tag(1)
                            Text("Partial").tag(2)
                            Text("Attempted").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        // State-specific explanation
                        Text(stateExplanation())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Detect if this is a workout habit and show specific fields
                if isWorkoutHabit() {
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
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                        
                        // Summary of selected types
                        if !selectedWorkoutTypes.isEmpty {
                            Text("Selected: \(selectedWorkoutTypes.sorted().joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
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
    
    // Helper function to get explanation text based on the current state
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
    
    // Helper method to check if multiple states are used
    private func useMultipleStates() -> Bool {
        return (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private func isWorkoutHabit() -> Bool {
        // Check if the habit name contains workout keywords or detailType is workout
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        let hasWorkoutKeyword = workoutKeywords.contains { keyword in
            habitName.contains(keyword)
        }
        
        return hasWorkoutKeyword || detailType == "workout"
    }
    
    private func loadExistingDetails() {
        if let existingDetails = CoreDataManager.shared.getHabitEntryDetails(habit: habit, date: date) {
            details = existingDetails
            
            // Try to parse workout data if it's in JSON format
            if let data = existingDetails.data(using: String.Encoding.utf8),
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
                
                if let duration = json["duration"] as? String {
                    self.duration = duration
                }
                if let intensity = json["intensity"] as? Int {
                    self.intensity = intensity
                }
                if let notes = json["notes"] as? String {
                    self.details = notes
                }
            }
        }
        
        isLoading = false
    }
    
    private func saveDetails() {
        var detailsToSave = details
        
        // For workout habits, save structured data as JSON
        if isWorkoutHabit() {
            var workoutData: [String: Any] = [
                "types": Array(selectedWorkoutTypes),  // Store all selected types as array
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
               let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) {
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
        if useMultipleStates() && entry != nil {
            entry?.setValue(completionState, forKey: "completionState")
            CoreDataManager.shared.saveContext()
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
