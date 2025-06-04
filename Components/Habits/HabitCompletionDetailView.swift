//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

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
    @State private var entryExists: Bool = false
    
    // Workout-specific fields
    @State private var isWorkout: Bool = false
    @State private var duration: String = ""
    @State private var selectedWorkoutTypes: Set<String> = []
    @State private var intensity: Int = 3
    
    // MARK: - Constants
    
    let workoutTypes = ["Cardio", "Strength", "Functional", "Core/Pre-Hab", "HIIT/Jump", "Other"]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                habitInfoSection
                
                // Only show workout details for success state on workout habits
                if isWorkoutHabit() && useMultipleStates() && completionState == 1 {
                    workoutSection
                } else if isWorkoutHabit() && !useMultipleStates() {
                    // For workout habits without multi-state, always show workout section
                    workoutSection
                }
                
                notesSection
                
                // Clear entry section - only show if entry exists
                if entryExists {
                    Section {
                        Button(role: .destructive, action: {
                            clearEntry()
                        }) {
                            HStack {
                                Spacer()
                                Text("Clear Entry")
                                Spacer()
                            }
                        }
                    }
                }
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
        Section {
            HStack {
                Image(systemName: habit.icon ?? "circle.fill")
                    .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
                
                Text(habit.name ?? "Habit")
                    .font(.headline)
                
                Spacer()
                
                Text(formatDate(date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Only show completion state picker if habit uses multiple states
            if useMultipleStates() {
                Picker("Completion", selection: $completionState) {
                    Text("Success").tag(1)
                    Text("Partial").tag(2)
                    Text("Attempted").tag(3)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var workoutSection: some View {
        Section {
            // Workout types - using native LazyVGrid for organized layout
            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Types")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(workoutTypes, id: \.self) { type in
                        Button(action: {
                            if selectedWorkoutTypes.contains(type) {
                                selectedWorkoutTypes.remove(type)
                            } else {
                                selectedWorkoutTypes.insert(type)
                            }
                            updateNotesWithWorkoutInfo()
                        }) {
                            Text(type)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedWorkoutTypes.contains(type) ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedWorkoutTypes.contains(type) ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Duration - Picker with +5 button
            HStack {
                Picker("Duration", selection: $duration) {
                    Text("15 min").tag("15")
                    Text("30 min").tag("30")
                    Text("45 min").tag("45")
                    Text("60 min").tag("60")
                    Text("75 min").tag("75")
                    Text("90 min").tag("90")
                }
                
                Button(action: {
                    // Add 5 minutes to current duration
                    let currentDuration = Int(duration) ?? 0
                    duration = String(currentDuration + 5)
                    updateNotesWithWorkoutInfo()
                }) {
                    Label("+5", systemImage: "plus.circle.fill")
                        .labelStyle(.titleOnly)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .onChange(of: duration) { _, _ in
                updateNotesWithWorkoutInfo()
            }
            
            // Intensity - Segmented picker for precise selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity")
                    .foregroundStyle(.primary)
                
                Picker("Intensity", selection: $intensity) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .pickerStyle(.segmented)
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
    
    /// Updates the notes field with formatted workout information
    private func updateNotesWithWorkoutInfo() {
        // Only update if we're in a workout context with success state
        guard isWorkoutHabit() && (!useMultipleStates() || completionState == 1) else { return }
        
        // Build the structured format
        var workoutTemplate = ""
        
        // Add duration at the top
        if !duration.isEmpty {
            workoutTemplate = "\(duration) min\n"
        }
        
        // Add each selected workout type with a colon for notes
        for type in selectedWorkoutTypes.sorted() {
            workoutTemplate += "\(type):\n"
        }
        
        // Check if we need to preserve any existing user notes
        let lines = details.components(separatedBy: "\n")
        var preservedContent = ""
        
        // Look for user-added content after the workout types
        var foundUserContent = false
        for line in lines {
            // Skip duration line and workout type lines
            if !line.hasSuffix(" min") && !line.hasSuffix(":") && !line.isEmpty {
                if !foundUserContent {
                    foundUserContent = true
                    preservedContent = line
                } else {
                    preservedContent += "\n" + line
                }
            }
        }
        
        // Update details with template
        if !workoutTemplate.isEmpty {
            details = workoutTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !preservedContent.isEmpty {
                details += "\n" + preservedContent
            }
        }
    }
    
    /// Returns explanation text based on the current completion state
    private func stateExplanation() -> String {
        if isWorkoutHabit() {
            // Custom explanations for workout/movement habits
            switch completionState {
            case 1:
                return "Formal workout completed"
            case 2:
                return "Hit step goal or light movement"
            case 3:
                return "Minimal movement today"
            default:
                return ""
            }
        } else {
            // Generic explanations for other habits
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
    }
    
    /// Checks if multiple states are enabled for this habit
    private func useMultipleStates() -> Bool {
        return (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    /// Determines if this is a workout-related habit
    private func isWorkoutHabit() -> Bool {
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training", "movement"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        let hasWorkoutKeyword = workoutKeywords.contains { keyword in
            habitName.contains(keyword)
        }
        
        return hasWorkoutKeyword || detailType == "workout"
    }
    
    /// Loads existing details for the habit entry
    private func loadExistingDetails() {
        // Check if entry exists
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                          habit, startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let entries = try context.fetch(fetchRequest)
            entryExists = !entries.isEmpty
            
            if let entry = entries.first {
                // Load completion state if using multiple states
                if useMultipleStates() {
                    completionState = (entry.value(forKey: "completionState") as? Int) ?? 1
                }
                
                // Load details
                if let existingDetails = entry.details {
                    details = existingDetails
                    
                    // Try to parse workout data if it's in JSON format
                    if let data = existingDetails.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Load completion state from JSON if available
                        if useMultipleStates(), let jsonState = json["completionState"] as? Int {
                            completionState = jsonState
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
                            // Just use the notes as-is
                            details = notes
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Error loading existing details: \(error)")
            #endif
        }
        
        isLoading = false
    }
    
    /// Saves the details to Core Data
    private func saveDetails() {
        var detailsToSave = details
        
        // For workout habits with success state, save structured data as JSON
        if isWorkoutHabit() && (!useMultipleStates() || completionState == 1) {
            // Extract the actual user notes (after separator) for JSON storage
            let separator = "\n─────────────────────\n"
            var notesToSave = details
            if let separatorRange = details.range(of: separator) {
                notesToSave = String(details[separatorRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            var workoutData: [String: Any] = [
                "types": Array(selectedWorkoutTypes),
                "type": selectedWorkoutTypes.first ?? "",  // Keep single type for backward compatibility
                "duration": duration,
                "intensity": intensity,
                "notes": details  // Save the full formatted text
            ]
            
            // Add completion state if using multiple states
            if useMultipleStates() {
                workoutData["completionState"] = completionState
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: workoutData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                detailsToSave = jsonString
            }
        } else if useMultipleStates() {
            // For non-workout habits or non-success states, just save completion state in JSON
            let stateData: [String: Any] = [
                "completionState": completionState,
                "notes": details
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: stateData),
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
    
    /// Clears the entry and dismisses the view
    private func clearEntry() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                          habit, startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let entries = try context.fetch(fetchRequest)
            
            for entry in entries {
                context.delete(entry)
            }
            
            try context.save()
            dismiss()
        } catch {
            #if DEBUG
            print("Error clearing entry: \(error)")
            #endif
        }
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
    habit.name = "Morning Movement"
    habit.icon = "figure.run"
    habit.color = "#FF3B30"
    habit.setValue(true, forKey: "useMultipleStates")
    habit.setValue(true, forKey: "trackDetails")
    
    return HabitCompletionDetailView(habit: habit, date: Date())
}
