//
//  AddHabitView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData
import Combine

// MARK: - View Model

@MainActor
class AddHabitViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var name = ""
    @Published var selectedIcon = "circle.fill"
    @Published var selectedColor = "#007AFF"
    @Published var selectedFrequency = "daily"
    @Published var customDays: [Int] = []
    @Published var notes = ""
    @Published var trackDetails = false
    @Published var detailType = "general"
    @Published var useMultipleStates = false
    @Published var isNegativeHabit = false
    @Published var showingIconSheet = false
    @Published var isValid = false
    @Published var isSaving = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupValidation()
        setupDebouncing()
    }
    
    // MARK: - Validation
    
    private func setupValidation() {
        // Combine publishers for validation
        $name
            .map { name in
                !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .assign(to: &$isValid)
    }
    
    private func setupDebouncing() {
        // Debounce name changes to avoid excessive validation
        $name
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
        
        // Debounce notes to avoid excessive updates
        $notes
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { _ in
                // Could trigger auto-save or other actions
            }
            .store(in: &cancellables)
    }
    
    private func validateForm() {
        // Additional validation logic if needed
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isValid = !trimmedName.isEmpty && trimmedName.count >= 2
    }
    
    // MARK: - Public Methods
    
    func saveHabit() async throws {
        guard isValid, !isSaving else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let customDaysString = customDays.sorted().map(String.init).joined(separator: ",")
        
        await MainActor.run {
            let habit = CoreDataManager.shared.createHabit(
                name: name,
                color: selectedColor,
                icon: selectedIcon,
                frequency: selectedFrequency,
                customDays: customDaysString,
                startDate: Date(),
                notes: notes,
                collection: nil
            )
            
            // Set dynamic properties
            habit.setValue(trackDetails, forKey: "trackDetails")
            habit.setValue(detailType, forKey: "detailType")
            habit.setValue(isNegativeHabit ? false : useMultipleStates, forKey: "useMultipleStates")
            habit.setValue(isNegativeHabit, forKey: "isNegativeHabit")
            
            CoreDataManager.shared.saveContext()
        }
    }
    
    func resetForm() {
        name = ""
        selectedIcon = "circle.fill"
        selectedColor = "#007AFF"
        selectedFrequency = "daily"
        customDays = []
        notes = ""
        trackDetails = false
        detailType = "general"
        useMultipleStates = false
        isNegativeHabit = false
    }
}

// MARK: - Main View

struct AddHabitView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @StateObject private var viewModel = AddHabitViewModel()
    
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
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveHabit()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
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
        ["book.fill", "dumbbell.fill", "leaf.fill", "moon.fill", "sun.max.fill"],
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
