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
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedFrequency: String = "daily"
    @State private var customDays: [Int] = []
    @State private var notes: String = ""
    @State private var selectedCollection: Collection?
    @State private var collections: [Collection] = []
    @State private var showingDeleteAlert = false
    
    // Tracking options
    @State private var trackDetails: Bool = false
    @State private var detailType: String = "general"
    @State private var useMultipleStates: Bool = false
    
    // MARK: - Constants
    
    let colorOptions = [
        "#007AFF", // Blue
        "#FF3B30", // Red
        "#34C759", // Green
        "#FF9500", // Orange
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5AC8FA", // Light Blue
        "#FFCC00"  // Yellow
    ]
    
    let iconOptions = [
        "circle.fill",
        "heart.fill",
        "star.fill",
        "bell.fill",
        "drop.fill",
        "flame.fill",
        "bolt.fill",
        "sun.max.fill",
        "moon.fill",
        "book.fill",
        "music.note",
        "sportscourt.fill",
        "figure.walk",
        "pills.fill",
        "house.fill",
        "cart.fill",
        "calendar",
        "bed.double.fill",
        "fork.knife",
        "leaf.fill"
    ]
    
    let frequencyOptions = [
        ("daily", "Every Day"),
        ("weekdays", "Weekdays Only"),
        ("weekends", "Weekends Only"),
        ("weekly", "Once a Week"),
        ("custom", "Custom Days")
    ]
    
    let detailTypeOptions = [
        ("general", "General Notes"),
        ("workout", "Workout Details"),
        ("reading", "Reading Log"),
        ("mood", "Mood Tracking")
    ]
    
    let daysOfWeek = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Habit Name", text: $name)
                    
                    // Color selection
                    VStack(alignment: .leading) {
                        Text("Color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(colorOptions, id: \.self) { color in
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                                .padding(1)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Icon selection
                    VStack(alignment: .leading) {
                        Text("Icon")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .foregroundStyle(Color(hex: selectedColor))
                                        .frame(width: 30, height: 30)
                                        .background(
                                            Circle()
                                                .fill(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                                        )
                                        .onTapGesture {
                                            selectedIcon = icon
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section(header: Text("Schedule")) {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(frequencyOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    
                    if selectedFrequency == "custom" {
                        ForEach(daysOfWeek, id: \.0) { day in
                            Button(action: {
                                toggleCustomDay(day.0)
                            }) {
                                HStack {
                                    Text(day.1)
                                    Spacer()
                                    if customDays.contains(day.0) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                
                Section(header: Text("Tracking Options")) {
                    Toggle("Track Additional Details", isOn: $trackDetails)
                    
                    if trackDetails {
                        Picker("Detail Type", selection: $detailType) {
                            ForEach(detailTypeOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        
                        Text("You'll be prompted to add details each time you complete this habit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Toggle("Use Multiple Completion States", isOn: $useMultipleStates)
                    
                    if useMultipleStates {
                        Text("This habit will track success, partial success, and failure states separately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("• Success (✓): Full completion")
                            .font(.caption)
                            .foregroundStyle(.green)
                        
                        Text("• Partial (⚬): Did some but not all")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("• Failure (✗): Attempted but struggled")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section(header: Text("Collection")) {
                    Picker("Add to Collection", selection: $selectedCollection) {
                        Text("None").tag(nil as Collection?)
                        ForEach(collections, id: \.self) { collection in
                            Text(collection.name ?? "").tag(collection as Collection?)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
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
                loadCollections()
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
        selectedCollection = habit.collection
        
        if let customDaysString = habit.customDays, !customDaysString.isEmpty {
            customDays = customDaysString.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        trackDetails = (habit.value(forKey: "trackDetails") as? Bool) ?? false
        detailType = (habit.value(forKey: "detailType") as? String) ?? "general"
        useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func toggleCustomDay(_ day: Int) {
        if customDays.contains(day) {
            customDays.removeAll { $0 == day }
        } else {
            customDays.append(day)
        }
    }
    
    private func updateHabit() {
        let customDaysString = customDays.sorted().map { String($0) }.joined(separator: ",")
        
        CoreDataManager.shared.updateHabit(
            habit,
            name: name,
            color: selectedColor,
            icon: selectedIcon,
            frequency: selectedFrequency,
            customDays: customDaysString,
            notes: notes,
            collection: selectedCollection
        )
        
        habit.setValue(trackDetails, forKey: "trackDetails")
        habit.setValue(detailType, forKey: "detailType")
        habit.setValue(useMultipleStates, forKey: "useMultipleStates")
        
        CoreDataManager.shared.saveContext()
        
        dismiss()
    }
    
    private func deleteHabit() {
        CoreDataManager.shared.deleteHabit(habit)
        dismiss()
    }
}
