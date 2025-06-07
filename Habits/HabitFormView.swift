//
//  HabitFormView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/6/25.
//


//
//  HabitFormView.swift
//  Bullet Tracker
//
//  Shared form component for AddHabitView and EditHabitView
//

import SwiftUI
import CoreData

// MARK: - Shared Form Component

struct HabitFormView: View {
    // MARK: - Bindings
    
    @Binding var name: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    @Binding var selectedFrequency: String
    @Binding var customDays: [Int]
    @Binding var notes: String
    @Binding var trackDetails: Bool
    @Binding var detailType: String
    @Binding var useMultipleStates: Bool
    @Binding var isNegativeHabit: Bool
    @Binding var showingIconSheet: Bool
    
    // MARK: - Body
    
    var body: some View {
        Group {
            habitDetailsSection
            scheduleSection
            trackingOptionsSection
            notesSection
        }
        .onChange(of: isNegativeHabit) { _, newValue in
            if newValue {
                useMultipleStates = false
            }
        }
    }
    
    // MARK: - Sections
    
    private var habitDetailsSection: some View {
        Section(header: Text("Habit Details")) {
            TextField("Habit Name", text: $name)
            colorPicker
            iconPicker
        }
    }
    
    private var colorPicker: some View {
        VStack(alignment: .leading) {
            Text("Color")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HabitConstants.colorOptions, id: \.self) { color in
                        colorCircle(for: color)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func colorCircle(for color: String) -> some View {
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
    
    private var iconPicker: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Icon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Browse More") {
                    showingIconSheet = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HabitConstants.quickIconOptions, id: \.self) { icon in
                        iconButton(for: icon)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func iconButton(for icon: String) -> some View {
        Image(systemName: icon)
            .foregroundColor(Color(hex: selectedColor))
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onTapGesture {
                selectedIcon = icon
            }
    }
    
    private var scheduleSection: some View {
        Section(header: Text("Schedule")) {
            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(HabitConstants.frequencyOptions, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            
            if selectedFrequency == "custom" {
                ForEach(HabitConstants.daysOfWeek, id: \.0) { day in
                    customDayRow(day: day)
                }
            }
        }
    }
    
    private func customDayRow(day: (Int, String)) -> some View {
        Button(action: { toggleCustomDay(day.0) }) {
            HStack {
                Text(day.1)
                Spacer()
                if customDays.contains(day.0) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }
    
    private var trackingOptionsSection: some View {
        Section(header: Text("Tracking Options")) {
            negativeHabitToggle
            detailTrackingToggle
            if !isNegativeHabit {
                multiStateTrackingToggle
            }
        }
    }
    
    private var negativeHabitToggle: some View {
        Group {
            Toggle("This is something I'm avoiding", isOn: $isNegativeHabit)
            
            if isNegativeHabit {
                Text("Checking this habit means you did the thing you're trying to avoid. Leave it unchecked for success.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var detailTrackingToggle: some View {
        Group {
            Toggle("Track Additional Details", isOn: $trackDetails)
            
            if trackDetails {
                Picker("Detail Type", selection: $detailType) {
                    ForEach(HabitConstants.detailTypeOptions, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                
                Text("You'll be prompted to add details each time you complete this habit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var multiStateTrackingToggle: some View {
        Group {
            Toggle("Use Multiple Completion States", isOn: $useMultipleStates)
            
            if useMultipleStates {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This habit will track success, partial success, and failure states separately.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach([
                        ("Success (✓)", "Full completion", Color.green),
                        ("Partial (⚬)", "Did some but not all", Color.orange),
                        ("Failure (✗)", "Attempted but struggled", Color.red)
                    ], id: \.0) { item in
                        Text("• \(item.0): \(item.1)")
                            .font(.caption)
                            .foregroundColor(item.2)
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextEditor(text: $notes)
                .frame(height: 100)
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleCustomDay(_ day: Int) {
        if let index = customDays.firstIndex(of: day) {
            customDays.remove(at: index)
        } else {
            customDays.append(day)
        }
    }
}

// MARK: - Constants

struct HabitConstants {
    static let colorOptions = [
        // Basic colors
        "#007AFF", "#34C759", "#FF3B30", "#FF9500", "#FFCC00", "#5856D6", "#FF2D55", "#5AC8FA",
        // Pastel colors
        "#AFD0F5", "#A8E1A8", "#F5A8A8", "#F7D1A8", "#F7EFA8", "#D1A8F7", "#F7A8D1", "#A8F5F5",
        // Dark shades
        "#004080", "#006633", "#801A15", "#804D00", "#806600", "#2E2B6B", "#80172B", "#0080A8",
        // Neutral tones
        "#8E8E93", "#48484A", "#636366", "#A8A8A8", "#53433D", "#7A6E65", "#B3A395", "#D9C7B8"
    ]
    
    static let quickIconOptions = [
        "circle.fill", "heart.fill", "figure.run", "fork.knife",
        "thermometer.snowflake", "light.strip.2", "star.fill", "bell.fill"
    ]
    
    static let frequencyOptions = [
        ("daily", "Every Day"),
        ("weekdays", "Weekdays Only"),
        ("weekends", "Weekends Only"),
        ("weekly", "Once a Week"),
        ("custom", "Custom Days")
    ]
    
    static let detailTypeOptions = [
        ("general", "General Notes"),
        ("workout", "Workout Details"),
        ("reading", "Reading Log"),
        ("mood", "Mood Tracking")
    ]
    
    static let daysOfWeek = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]
}