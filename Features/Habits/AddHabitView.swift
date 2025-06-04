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
    
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - State Properties
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedFrequency: String = "daily"
    @State private var customDays: [Int] = []
    @State private var notes: String = ""
    @State private var iconSearchText: String = ""
    @State private var showingIconSheet: Bool = false
    @State private var trackDetails: Bool = false
    @State private var detailType: String = "general"
    @State private var useMultipleStates: Bool = false
    @State private var isNegativeHabit: Bool = false
    
    // MARK: - Constants
    
    /// Available color options for habits - includes basic colors, pastels, dark shades, and neutrals
    private let colorOptions = [
        // Basic colors
        "#007AFF", "#34C759", "#FF3B30", "#FF9500", "#FFCC00", "#5856D6", "#FF2D55", "#5AC8FA",
        // Pastel colors
        "#AFD0F5", "#A8E1A8", "#F5A8A8", "#F7D1A8", "#F7EFA8", "#D1A8F7", "#F7A8D1", "#A8F5F5",
        // Dark shades
        "#004080", "#006633", "#801A15", "#804D00", "#806600", "#2E2B6B", "#80172B", "#0080A8",
        // Neutral tones
        "#8E8E93", "#48484A", "#636366", "#A8A8A8", "#53433D", "#7A6E65", "#B3A395", "#D9C7B8"
    ]
    
    /// Quick access icons shown in the main form
    private let quickIconOptions = [
        "circle.fill",
        "heart.fill",
        "figure.run",
        "fork.knife",
        "thermometer.snowflake",
        "light.strip.2",
        "star.fill",
        "bell.fill"
    ]
    
    /// Frequency options for habit scheduling
    private let frequencyOptions = [
        ("daily", "Every Day"),
        ("weekdays", "Weekdays Only"),
        ("weekends", "Weekends Only"),
        ("weekly", "Once a Week"),
        ("custom", "Custom Days")
    ]
    
    /// Detail type options for habits that track additional information
    private let detailTypeOptions = [
        ("general", "General Notes"),
        ("workout", "Workout Details"),
        ("reading", "Reading Log"),
        ("mood", "Mood Tracking")
    ]
    
    /// Days of the week for custom frequency selection
    private let daysOfWeek = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    // MARK: - Computed Properties
    
    /// Determines if the form is valid for saving
    private var formIsValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                habitDetailsSection
                scheduleSection
                trackingOptionsSection
                notesSection
            }
            .navigationTitle("New Habit")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingIconSheet) {
                IconSelectorView(
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor
                )
            }
        }
    }
    
    // MARK: - View Components
    
    /// Habit details section containing name, color, and icon selection
    private var habitDetailsSection: some View {
        Section(header: Text("Habit Details")) {
            TextField("Habit Name", text: $name)
            
            colorPicker
            iconPicker
        }
    }
    
    /// Color selection component with horizontal scrolling
    private var colorPicker: some View {
        VStack(alignment: .leading) {
            Text("Color")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { color in
                        colorCircle(for: color)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    /// Creates a selectable color circle
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
    
    /// Icon selection component with quick options and browse button
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
                    ForEach(quickIconOptions, id: \.self) { icon in
                        iconButton(for: icon)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    /// Creates a selectable icon button
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
    
    /// Schedule section for frequency selection
    private var scheduleSection: some View {
        Section(header: Text("Schedule")) {
            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(frequencyOptions, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            
            if selectedFrequency == "custom" {
                customDaysList
            }
        }
    }
    
    /// Custom days selection list
    private var customDaysList: some View {
        ForEach(daysOfWeek, id: \.0) { day in
            Button(action: {
                toggleCustomDay(day.0)
            }) {
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
    }
    
    /// Tracking options section for detail tracking and multi-state options
    private var trackingOptionsSection: some View {
        Section(header: Text("Tracking Options")) {
            negativeHabitToggle
            detailTrackingToggle
            multiStateTrackingToggle
        }
    }
    
    /// Negative habit toggle
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
    
    /// Detail tracking toggle and options
    private var detailTrackingToggle: some View {
        Group {
            Toggle("Track Additional Details", isOn: $trackDetails)
            
            if trackDetails {
                Picker("Detail Type", selection: $detailType) {
                    ForEach(detailTypeOptions, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                
                Text("You'll be prompted to add details each time you complete this habit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Multi-state tracking toggle and explanation
    private var multiStateTrackingToggle: some View {
        Group {
            // Don't show multi-state option for negative habits
            if !isNegativeHabit {
                Toggle("Use Multiple Completion States", isOn: $useMultipleStates)
                
                if useMultipleStates {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This habit will track success, partial success, and failure states separately.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Success (✓): Full completion")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("• Partial (⚬): Did some but not all")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("• Failure (✗): Attempted but struggled")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    /// Notes section for additional habit information
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextEditor(text: $notes)
                .frame(height: 100)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                saveHabit()
            }
            .disabled(!formIsValid)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Toggles a custom day selection
    private func toggleCustomDay(_ day: Int) {
        if customDays.contains(day) {
            customDays.removeAll { $0 == day }
        } else {
            customDays.append(day)
        }
    }
    
    /// Saves the habit to Core Data
    private func saveHabit() {
        let customDaysString = customDays.sorted().map { String($0) }.joined(separator: ",")
        
        // Create the habit with basic properties (removed collection parameter)
        let habit = CoreDataManager.shared.createHabit(
            name: name,
            color: selectedColor,
            icon: selectedIcon,
            frequency: selectedFrequency,
            customDays: customDaysString,
            startDate: Date(),
            notes: notes,
            collection: nil  // Always nil now
        )
        
        // Set dynamic properties for tracking options
        habit.setValue(trackDetails, forKey: "trackDetails")
        habit.setValue(detailType, forKey: "detailType")
        habit.setValue(isNegativeHabit ? false : useMultipleStates, forKey: "useMultipleStates") // Negative habits don't use multi-state
        habit.setValue(isNegativeHabit, forKey: "isNegativeHabit")
        
        // Save changes
        CoreDataManager.shared.saveContext()
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - IconSelectorView

/// Full-screen icon browser with search functionality
struct IconSelectorView: View {
    // MARK: - Bindings
    
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    
    // MARK: - Environment
    
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - State
    
    @State private var searchText: String = ""
    
    // MARK: - Constants
    
    /// Expanded icon options organized by category
    private let expandedIconOptions: [String: [String]] = [
        "Health & Fitness": [
            "heart.fill", "lungs.fill", "figure.walk", "figure.run", "figure.hiking",
            "figure.yoga", "figure.cooldown", "figure.strengthtraining.traditional",
            "figure.mind.and.body", "dumbbell.fill", "sportscourt.fill", "bed.double.fill",
            "alarm.fill", "pills.fill", "cross.fill", "leaf.fill", "carrot.fill",
            "drop.fill", "drop.degreesign.fill", "scalemass.fill", "brain.head.profile",
            "eye.fill", "ear.fill", "thermometer.snowflake"
        ],
        "Productivity": [
            "list.bullet", "checklist", "checkmark.circle.fill", "calendar",
            "calendar.badge.clock", "clock.fill", "deskclock.fill", "book.fill",
            "book.closed.fill", "pencil", "pencil.and.outline", "doc.text.fill",
            "doc.richtext.fill", "doc.text.below.ecg", "brain", "lightbulb.fill",
            "hammer.fill", "briefcase.fill", "case.fill", "folder.fill",
            "mail.fill", "phone.fill", "laptopcomputer", "desktopcomputer",
            "person.crop.circle.fill"
        ],
        "Lifestyle": [
            "house.fill", "house.and.flag.fill", "building.2.fill", "building.columns.fill",
            "tram.fill", "car.fill", "bicycle", "figure.wave", "gamecontroller.fill",
            "tv.fill", "theatermasks.fill", "music.note", "headphones", "paintpalette.fill",
            "photo.fill", "cart.fill", "bag.fill", "banknote.fill", "creditcard.fill",
            "gift.fill", "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
            "airplane", "beach.umbrella.fill", "pawprint.fill", "ladybug.fill", "light.strip.2"
        ],
        "Nature & Weather": [
            "sun.max.fill", "moon.fill", "moon.stars.fill", "sparkles", "cloud.fill",
            "cloud.rain.fill", "cloud.snow.fill", "cloud.bolt.fill", "wind", "tornado",
            "flame.fill", "thermometer", "thermometer.snowflake", "snowflake",
            "drop.triangle.fill", "leaf.fill", "tree.fill", "mountain.2.fill",
            "globe.americas.fill", "hare.fill", "tortoise.fill", "bird.fill",
            "ant.fill", "lizard.fill", "fish.fill"
        ],
        "Tech & Science": [
            "lightbulb.fill", "light.strip.2", "network", "wifi",
            "antenna.radiowaves.left.and.right", "dot.radiowaves.right", "bolt.fill",
            "battery.100", "xserve", "ipod", "iphone", "ipad", "keyboard",
            "desktopcomputer", "laptopcomputer", "display", "printer.fill", "tv.fill",
            "gamecontroller.fill", "headphones", "radio.fill", "compass.drawing",
            "gyroscope", "sensor.fill", "camera.fill", "gearshape.fill", "hammer.fill",
            "screwdriver.fill", "wrench.fill"
        ],
        "Shapes & Symbols": [
            "circle.fill", "square.fill", "triangle.fill", "diamond.fill", "octagon.fill",
            "hexagon.fill", "seal.fill", "shield.fill", "star.fill", "sparkle",
            "heart.fill", "flag.fill", "pin.fill", "bell.fill", "tag.fill", "bolt.fill",
            "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.left.circle.fill",
            "arrow.right.circle.fill", "location.fill", "hand.thumbsup.fill",
            "hand.raised.fill", "questionmark.circle.fill", "exclamationmark.circle.fill"
        ]
    ]
    
    // MARK: - Computed Properties
    
    /// All unique icons from all categories
    private var allIcons: [String] {
        var icons: [String] = []
        for iconList in expandedIconOptions.values {
            icons.append(contentsOf: iconList)
        }
        return Array(Set(icons)).sorted()
    }
    
    /// Icons filtered by search text
    private var filteredIcons: [String] {
        guard !searchText.isEmpty else { return [] }
        return allIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                searchBar
                
                if searchText.isEmpty {
                    categorizedIconList
                } else {
                    searchResultsGrid
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// Search bar for filtering icons
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search icons", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    /// List of icons organized by category
    private var categorizedIconList: some View {
        List {
            ForEach(expandedIconOptions.keys.sorted(), id: \.self) { category in
                Section(header: Text(category)) {
                    iconGrid(icons: expandedIconOptions[category] ?? [])
                }
            }
        }
    }
    
    /// Grid of search results
    private var searchResultsGrid: some View {
        ScrollView {
            iconGrid(icons: filteredIcons)
                .padding()
        }
    }
    
    /// Creates a grid of icon buttons
    private func iconGrid(icons: [String]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
            spacing: 12
        ) {
            ForEach(icons, id: \.self) { icon in
                IconButton(
                    icon: icon,
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor,
                    onSelect: {
                        selectedIcon = icon
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - IconButton

/// Reusable icon button component
struct IconButton: View {
    // MARK: - Properties
    
    let icon: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    let onSelect: () -> Void
    
    // MARK: - Computed Properties
    
    private var isSelected: Bool {
        selectedIcon == icon
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onSelect) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: selectedColor))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.gray.opacity(0.2) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color(hex: selectedColor) : Color.clear, lineWidth: 2)
                )
        }
    }
}
