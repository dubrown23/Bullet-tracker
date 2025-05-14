

//
//  AddHabitView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedFrequency: String = "daily"
    @State private var customDays: [Int] = []
    @State private var notes: String = ""
    @State private var selectedCollection: Collection?
    @State private var collections: [Collection] = []
    @State private var iconSearchText: String = ""
    @State private var showingIconSheet: Bool = false
    
    // New property for tracking details
    @State private var trackDetails: Bool = false
    @State private var detailType: String = "general"
    
    // New property for multi-state tracking
    @State private var useMultipleStates: Bool = false
    
    // Available color options
    // In AddHabitView.swift, replace the existing colorOptions array with this expanded version:

    // Available color options - expanded selection
    let colorOptions = [
        // Basic colors
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#5856D6", // Purple
        "#FF2D55", // Pink
        "#5AC8FA", // Light Blue
        
        // Extended palette - pastels
        "#AFD0F5", // Pastel Blue
        "#A8E1A8", // Pastel Green
        "#F5A8A8", // Pastel Red
        "#F7D1A8", // Pastel Orange
        "#F7EFA8", // Pastel Yellow
        "#D1A8F7", // Pastel Purple
        "#F7A8D1", // Pastel Pink
        "#A8F5F5", // Pastel Cyan
        
        // Extended palette - darker shades
        "#004080", // Dark Blue
        "#006633", // Dark Green
        "#801A15", // Dark Red
        "#804D00", // Dark Orange
        "#806600", // Dark Yellow
        "#2E2B6B", // Dark Purple
        "#80172B", // Dark Pink
        "#0080A8", // Dark Teal
        
        // Neutral tones
        "#8E8E93", // Gray
        "#48484A", // Dark Gray
        "#636366", // Mid Gray
        "#A8A8A8", // Light Gray
        "#53433D", // Brown
        "#7A6E65", // Tan
        "#B3A395", // Light Brown
        "#D9C7B8"  // Beige
    ]
    
    // Basic icon options shown in main view
    let quickIconOptions = [
        "circle.fill",
        "heart.fill",
        "figure.run",   // Your requested icon
        "fork.knife",   // Your requested icon
        "thermometer.snowflake", // Your requested icon
        "light.strip.2",   // Your requested icon
        "star.fill",
        "bell.fill"
    ]
    
    // Expanded icon options by category
    let expandedIconOptions: [String: [String]] = [
        "Health & Fitness": [
            "heart.fill",
            "lungs.fill",
            "figure.walk",
            "figure.run",  // Your requested icon
            "figure.hiking",
            "figure.yoga",
            "figure.cooldown",
            "figure.strengthtraining.traditional",
            "figure.mind.and.body",
            "dumbbell.fill",
            "sportscourt.fill",
            "bed.double.fill",
            "alarm.fill",
            "pills.fill",
            "cross.fill",
            "leaf.fill",
            "carrot.fill",
            "drop.fill",
            "drop.degreesign.fill",
            "scalemass.fill",
            "brain.head.profile",
            "eye.fill",
            "ear.fill",
            "thermometer.snowflake"  // Your requested icon
        ],
        "Productivity": [
            "list.bullet",
            "checklist",
            "checkmark.circle.fill",
            "calendar",
            "calendar.badge.clock",
            "clock.fill",
            "deskclock.fill",
            "book.fill",
            "book.closed.fill",
            "pencil",
            "pencil.and.outline",
            "doc.text.fill",
            "doc.richtext.fill",
            "doc.text.below.ecg",
            "brain",
            "lightbulb.fill",
            "hammer.fill",
            "briefcase.fill",
            "case.fill",
            "folder.fill",
            "mail.fill",
            "phone.fill",
            "laptopcomputer",
            "desktopcomputer",
            "person.crop.circle.fill"
        ],
        "Lifestyle": [
            "house.fill",
            "house.and.flag.fill",
            "building.2.fill",
            "building.columns.fill",
            "tram.fill",
            "car.fill",
            "bicycle",
            "figure.wave",
            "gamecontroller.fill",
            "tv.fill",
            "theatermasks.fill",
            "music.note",
            "headphones",
            "paintpalette.fill",
            "photo.fill",
            "cart.fill",
            "bag.fill",
            "banknote.fill",
            "creditcard.fill",
            "gift.fill",
            "fork.knife",  // Your requested icon
            "cup.and.saucer.fill",
            "mug.fill",
            "wineglass.fill",
            "airplane",
            "beach.umbrella.fill",
            "pawprint.fill",
            "ladybug.fill",
            "light.strip.2"  // Your requested icon
        ],
        "Nature & Weather": [
            "sun.max.fill",
            "moon.fill",
            "moon.stars.fill",
            "sparkles",
            "cloud.fill",
            "cloud.rain.fill",
            "cloud.snow.fill",
            "cloud.bolt.fill",
            "wind",
            "tornado",
            "flame.fill",
            "thermometer",
            "thermometer.snowflake",  // Your requested icon
            "snowflake",
            "drop.triangle.fill",
            "leaf.fill",
            "tree.fill",
            "mountain.2.fill",
            "globe.americas.fill",
            "hare.fill",
            "tortoise.fill",
            "bird.fill",
            "ant.fill",
            "lizard.fill",
            "fish.fill"
        ],
        "Tech & Science": [
            "lightbulb.fill",
            "light.strip.2",  // Your requested icon
            "network",
            "wifi",
            "antenna.radiowaves.left.and.right",
            "dot.radiowaves.right",
            "bolt.fill",
            "battery.100",
            "xserve",
            "ipod",
            "iphone",
            "ipad",
            "keyboard",
            "desktopcomputer",
            "laptopcomputer",
            "display",
            "printer.fill",
            "tv.fill",
            "gamecontroller.fill",
            "headphones",
            "radio.fill",
            "compass.drawing",
            "gyroscope",
            "sensor.fill",
            "camera.fill",
            "gearshape.fill",
            "hammer.fill",
            "screwdriver.fill",
            "wrench.fill"
        ],
        "Shapes & Symbols": [
            "circle.fill",
            "square.fill",
            "triangle.fill",
            "diamond.fill",
            "octagon.fill",
            "hexagon.fill",
            "seal.fill",
            "shield.fill",
            "star.fill",
            "sparkle",
            "heart.fill",
            "flag.fill",
            "pin.fill",
            "bell.fill",
            "tag.fill",
            "bolt.fill",
            "arrow.up.circle.fill",
            "arrow.down.circle.fill",
            "arrow.left.circle.fill",
            "arrow.right.circle.fill",
            "location.fill",
            "hand.thumbsup.fill",
            "hand.raised.fill",
            "questionmark.circle.fill",
            "exclamationmark.circle.fill"
        ]
    ]
    
    // Combined list of all icons for search
    var allIcons: [String] {
        var icons: [String] = []
        for iconList in expandedIconOptions.values {
            icons.append(contentsOf: iconList)
        }
        return Array(Set(icons)) // Remove duplicates
    }
    
    // Filtered icons based on search
    var filteredIcons: [String] {
        if iconSearchText.isEmpty {
            return allIcons
        } else {
            return allIcons.filter { $0.contains(iconSearchText.lowercased()) }
        }
    }
    
    // Frequency options
    let frequencyOptions = [
        ("daily", "Every Day"),
        ("weekdays", "Weekdays Only"),
        ("weekends", "Weekends Only"),
        ("weekly", "Once a Week"),
        ("custom", "Custom Days")
    ]
    
    // Detail type options
    let detailTypeOptions = [
        ("general", "General Notes"),
        ("workout", "Workout Details"),
        ("reading", "Reading Log"),
        ("mood", "Mood Tracking")
    ]
    
    // Days of the week for custom selection
    let daysOfWeek = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Habit Name", text: $name)
                    
                    // Color selection
                    VStack(alignment: .leading) {
                        Text("Color")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
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
                    
                    // Icon selection with button to show more icons
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
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                
                // Tracking Options Section (replaces the previous "Detail Tracking" section)
                Section(header: Text("Tracking Options")) {
                    // Detail tracking toggle
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
                    
                    // Multi-state tracking toggle (new)
                    Toggle("Use Multiple Completion States", isOn: $useMultipleStates)
                    
                    if useMultipleStates {
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
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadCollections()
                preSelectHabitTrackerCollection()
            }
            .sheet(isPresented: $showingIconSheet) {
                IconSelectorView(selectedIcon: $selectedIcon, selectedColor: $selectedColor, iconOptions: expandedIconOptions)
            }
        }
    }
    
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func preSelectHabitTrackerCollection() {
        // Try to find the Habit Tracker collection and select it by default
        if let habitTrackerCollection = collections.first(where: { $0.name == "Habit Tracker" }) {
            selectedCollection = habitTrackerCollection
        }
    }
    
    private func toggleCustomDay(_ day: Int) {
        if customDays.contains(day) {
            customDays.removeAll { $0 == day }
        } else {
            customDays.append(day)
        }
    }
    
    private func saveHabit() {
        let customDaysString = customDays.sorted().map { String($0) }.joined(separator: ",")
        
        // Create the habit using the existing method but with user defaults for tracking details
        let habit = CoreDataManager.shared.createHabit(
            name: name,
            color: selectedColor,
            icon: selectedIcon,
            frequency: selectedFrequency,
            customDays: customDaysString,
            startDate: Date(),
            notes: notes,
            collection: selectedCollection
        )
        
        // Set the tracking details using the Core Data setValue method
        habit.setValue(trackDetails, forKey: "trackDetails")
        habit.setValue(detailType, forKey: "detailType")
        
        // Set the multi-state tracking property (new)
        habit.setValue(useMultipleStates, forKey: "useMultipleStates")
        
        // Save the context again after adding our custom properties
        CoreDataManager.shared.saveContext()
        
        presentationMode.wrappedValue.dismiss()
    }
}

// View for browsing and selecting icons
struct IconSelectorView: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    let iconOptions: [String: [String]]
    @State private var searchText: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
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
                
                if searchText.isEmpty {
                    // Show categories
                    List {
                        ForEach(iconOptions.keys.sorted(), id: \.self) { category in
                            Section(header: Text(category)) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                    ForEach(iconOptions[category] ?? [], id: \.self) { icon in
                                        IconButton(icon: icon, selectedIcon: $selectedIcon, selectedColor: $selectedColor, onSelect: {
                                            selectedIcon = icon
                                            presentationMode.wrappedValue.dismiss()
                                        })
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                } else {
                    // Show search results
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16) {
                            ForEach(filteredIcons, id: \.self) { icon in
                                IconButton(icon: icon, selectedIcon: $selectedIcon, selectedColor: $selectedColor, onSelect: {
                                    selectedIcon = icon
                                    presentationMode.wrappedValue.dismiss()
                                })
                            }
                        }
                        .padding()
                    }
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
    
    // Filter icons based on search text
    var filteredIcons: [String] {
        if searchText.isEmpty {
            return []
        }
        
        var allIcons: [String] = []
        for icons in iconOptions.values {
            allIcons.append(contentsOf: icons)
        }
        
        return allIcons.filter { $0.contains(searchText.lowercased()) }
    }
}

// Icon button component
struct IconButton: View {
    let icon: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: selectedColor))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(selectedIcon == icon ? Color(hex: selectedColor) : Color.clear, lineWidth: 2)
                )
        }
    }
}
