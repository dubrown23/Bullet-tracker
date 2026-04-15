//
//  AddHabitView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - Main View

struct AddHabitView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @State private var viewModel = HabitFormViewModel()
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                HabitFormView(
                    name: $viewModel.name,
                    selectedIcon: $viewModel.selectedIcon,
                    selectedColor: $viewModel.selectedColor,
                    selectedFrequency: $viewModel.selectedFrequency,
                    customDays: $viewModel.customDays,
                    notes: $viewModel.notes,
                    trackDetails: $viewModel.trackDetails,
                    detailType: $viewModel.detailType,
                    useMultipleStates: $viewModel.useMultipleStates,
                    isNegativeHabit: $viewModel.isNegativeHabit,
                    showingIconSheet: $viewModel.showingIconSheet
                )
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveHabit()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(Color(hex: "#FF8C42"))
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(viewModel.isValid ? Color(hex: "#FF8C42") : Color(UIColor.tertiaryLabel))
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $viewModel.showingIconSheet) {
                IconSelectorView(
                    selectedIcon: $viewModel.selectedIcon,
                    selectedColor: $viewModel.selectedColor
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveHabit() {
        Task {
            do {
                try await viewModel.saveHabit()
                dismiss()
            } catch {
                // Handle error if needed
            }
        }
    }
}

// MARK: - Async Icon Selector

struct AsyncIconSelectorView: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    @State private var isLoading = true
    @State private var loadedIcons: [String] = []
    
    // Common SF Symbols for habits - loaded progressively
    private let iconBatches = [
        // First batch - most common
        ["circle.fill", "checkmark.circle.fill", "star.fill", "heart.fill", "flag.fill"],
        // Second batch
        ["book.fill", "dumbbell.fill", "leaf.fill", "moon.fill", "sun.max.fill", "dog.fill"],
        // Third batch
        ["drop.fill", "flame.fill", "bolt.fill", "brain", "lungs.fill"],
        // Fourth batch
        ["figure.walk", "figure.run", "bicycle", "car.fill", "airplane"],
        // Fifth batch
        ["bed.double.fill", "cup.and.saucer.fill", "fork.knife", "pills.fill", "cross.fill"]
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Loading icons...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                        ForEach(loadedIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                VStack {
                                    Image(systemName: icon)
                                        .font(.system(size: 30))
                                        .foregroundColor(Color(hex: selectedColor))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(selectedIcon == icon ? Color(hex: selectedColor) : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadIconsProgressively()
            }
        }
    }
    
    private func loadIconsProgressively() {
        Task {
            isLoading = true
            
            // Load icons in batches for better perceived performance
            for (index, batch) in iconBatches.enumerated() {
                await MainActor.run {
                    loadedIcons.append(contentsOf: batch)
                    
                    // Show content after first batch
                    if index == 0 {
                        isLoading = false
                    }
                }
                
                // Small delay between batches
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
}
