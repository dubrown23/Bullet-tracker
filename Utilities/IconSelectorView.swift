//
//  IconSelectorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/6/25.
//


//
//  IconSelectorView.swift
//  Bullet Tracker
//
//  Icon selection view for habits
//

import SwiftUI

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