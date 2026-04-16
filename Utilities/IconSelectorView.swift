//
//  IconSelectorView.swift
//  Bullet Tracker
//
//  Icon selection view for habits
//

import SwiftUI

struct IconSelectorView: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // MARK: - Icon Data

    private static let iconsByCategory: [String: [String]] = [
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
            "ant.fill", "lizard.fill", "fish.fill", "dog.fill"
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

    private static let allIcons: [String] = {
        var icons: [String] = []
        for iconList in iconsByCategory.values {
            icons.append(contentsOf: iconList)
        }
        return Array(Set(icons)).sorted()
    }()

    private var filteredIcons: [String] {
        guard !searchText.isEmpty else { return [] }
        return Self.allIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    categorizedList
                } else {
                    searchResults
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Views

    private var categorizedList: some View {
        List {
            ForEach(Self.iconsByCategory.keys.sorted(), id: \.self) { category in
                Section(category) {
                    iconGrid(icons: Self.iconsByCategory[category] ?? [])
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var searchResults: some View {
        ScrollView {
            if filteredIcons.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                iconGrid(icons: filteredIcons)
                    .padding()
            }
        }
    }

    private func iconGrid(icons: [String]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                    dismiss()
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: selectedColor))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedIcon == icon ? Color(hex: selectedColor) : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
