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
    
    // Workout-specific fields (for workout habits)
    @State private var isWorkout: Bool = false
    @State private var duration: String = ""
    @State private var workoutType: String = "Cardio"
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
                }
                
                // Detect if this is a workout habit and show specific fields
                if isWorkoutHabit() {
                    Section(header: Text("Workout Information")) {
                        Picker("Type", selection: $workoutType) {
                            ForEach(workoutTypes, id: \.self) {
                                Text($0)
                            }
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
                if let workoutType = json["type"] as? String {
                    self.workoutType = workoutType
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
            let workoutData: [String: Any] = [
                "type": workoutType,
                "duration": duration,
                "intensity": intensity,
                "notes": details
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: workoutData),
               let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) {
                detailsToSave = jsonString
            }
        }
        
        // Save the details to Core Data
        _ = CoreDataManager.shared.updateHabitEntryDetails(
            habit: habit,
            date: date,
            details: detailsToSave
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
