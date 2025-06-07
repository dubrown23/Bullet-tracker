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
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State Properties
    
    @State private var details: String = ""
    @State private var completionState: Int = 1
    @State private var entryExists: Bool = false
    
    // Workout-specific fields
    @State private var duration: String = ""
    @State private var selectedWorkoutTypes: Set<String> = []
    @State private var intensity: Int = 3
    
    // MARK: - Constants
    
    private let workoutTypes = ["Cardio", "Strength", "Functional", "Core/Pre-Hab", "HIIT/Jump", "Other"]
    
    // MARK: - Computed Properties
    
    private var useMultipleStates: Bool {
        (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private var isWorkoutHabit: Bool {
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training", "movement"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        return workoutKeywords.contains { habitName.contains($0) } || detailType == "workout"
    }
    
    private var shouldShowWorkoutSection: Bool {
        isWorkoutHabit && (!useMultipleStates || completionState == 1)
    }
    
    // MARK: - Static Formatters
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                habitInfoSection
                
                if shouldShowWorkoutSection {
                    workoutSection
                }
                
                notesSection
                
                if entryExists {
                    clearEntrySection
                }
            }
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveDetails)
                }
            }
            .onAppear(perform: loadExistingDetails)
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
                
                Text(date, formatter: Self.dateFormatter)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if useMultipleStates {
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
            workoutTypesView
            durationView
            intensityView
        }
    }
    
    private var workoutTypesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Types")
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(workoutTypes, id: \.self) { type in
                    workoutTypeButton(for: type)
                }
            }
        }
    }
    
    private func workoutTypeButton(for type: String) -> some View {
        Button(action: { toggleWorkoutType(type) }) {
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
    
    private var durationView: some View {
        HStack {
            Picker("Duration", selection: $duration) {
                Text("15 min").tag("15")
                Text("30 min").tag("30")
                Text("45 min").tag("45")
                Text("60 min").tag("60")
                Text("75 min").tag("75")
                Text("90 min").tag("90")
            }
            
            Button(action: addFiveMinutes) {
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
    }
    
    private var intensityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intensity")
                .foregroundStyle(.primary)
            
            Picker("Intensity", selection: $intensity) {
                ForEach(1...5, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextEditor(text: $details)
                .frame(minHeight: 100)
        }
    }
    
    private var clearEntrySection: some View {
        Section {
            Button(role: .destructive, action: clearEntry) {
                HStack {
                    Spacer()
                    Text("Clear Entry")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleWorkoutType(_ type: String) {
        if selectedWorkoutTypes.contains(type) {
            selectedWorkoutTypes.remove(type)
        } else {
            selectedWorkoutTypes.insert(type)
        }
        updateNotesWithWorkoutInfo()
    }
    
    private func addFiveMinutes() {
        let currentDuration = Int(duration) ?? 0
        duration = String(currentDuration + 5)
        updateNotesWithWorkoutInfo()
    }
    
    private func updateNotesWithWorkoutInfo() {
        guard shouldShowWorkoutSection else { return }
        
        var workoutTemplate = ""
        
        if !duration.isEmpty {
            workoutTemplate = "\(duration) min\n"
        }
        
        for type in selectedWorkoutTypes.sorted() {
            workoutTemplate += "\(type):\n"
        }
        
        // Preserve user content
        let existingLines = details.components(separatedBy: "\n")
        let userContent = existingLines
            .filter { !$0.hasSuffix(" min") && !$0.hasSuffix(":") && !$0.isEmpty }
            .joined(separator: "\n")
        
        details = workoutTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userContent.isEmpty {
            details += "\n" + userContent
        }
    }
    
    private func loadExistingDetails() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit, startOfDay as NSDate, endOfDay as NSDate
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let entries = try viewContext.fetch(fetchRequest)
            entryExists = !entries.isEmpty
            
            if let entry = entries.first {
                loadEntryData(from: entry)
            }
        } catch {
            // Handle error silently in production
        }
    }
    
    private func loadEntryData(from entry: HabitEntry) {
        if useMultipleStates {
            completionState = (entry.value(forKey: "completionState") as? Int) ?? 1
        }
        
        guard let existingDetails = entry.details else { return }
        details = existingDetails
        
        // Try to parse JSON data
        guard let data = existingDetails.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if useMultipleStates, let jsonState = json["completionState"] as? Int {
            completionState = jsonState
        }
        
        // Load workout types
        if let types = json["types"] as? [String] {
            selectedWorkoutTypes = Set(types)
        } else if let type = json["type"] as? String {
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
    
    private func saveDetails() {
        let detailsToSave = createDetailsJSON()
        
        let entry = CoreDataManager.shared.updateHabitEntryDetails(
            habit: habit,
            date: date,
            details: detailsToSave
        )
        
        if useMultipleStates, let entry = entry {
            entry.setValue(completionState, forKey: "completionState")
            CoreDataManager.shared.saveContext()
        }
        
        dismiss()
    }
    
    private func createDetailsJSON() -> String {
        if shouldShowWorkoutSection {
            var workoutData: [String: Any] = [
                "types": Array(selectedWorkoutTypes),
                "type": selectedWorkoutTypes.first ?? "",
                "duration": duration,
                "intensity": intensity,
                "notes": details
            ]
            
            if useMultipleStates {
                workoutData["completionState"] = completionState
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: workoutData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } else if useMultipleStates {
            let stateData: [String: Any] = [
                "completionState": completionState,
                "notes": details
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: stateData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        }
        
        return details
    }
    
    private func clearEntry() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit, startOfDay as NSDate, endOfDay as NSDate
        )
        
        do {
            let entries = try viewContext.fetch(fetchRequest)
            entries.forEach(viewContext.delete)
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error silently in production
        }
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
