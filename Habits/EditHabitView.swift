//
//  EditHabitView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData
import Combine

// MARK: - Shared Habit Form View Model

@MainActor
class HabitFormViewModel: ObservableObject {
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
    private var habit: Habit?
    
    // MARK: - Initialization
    
    init(habit: Habit? = nil) {
        self.habit = habit
        setupValidation()
        setupDebouncing()
        
        if let habit = habit {
            loadHabitData(from: habit)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupValidation() {
        $name
            .map { name in
                !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .assign(to: &$isValid)
    }
    
    private func setupDebouncing() {
        // Debounce name changes
        $name
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
        
        // Debounce notes
        $notes
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { _ in
                // Could trigger auto-save or other actions
            }
            .store(in: &cancellables)
        
        // Debounce custom days changes
        $customDays
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { _ in
                // Could validate custom days selection
            }
            .store(in: &cancellables)
    }
    
    private func validateForm() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isValid = !trimmedName.isEmpty && trimmedName.count >= 2
    }
    
    // MARK: - Data Loading
    
    private func loadHabitData(from habit: Habit) {
        name = habit.name ?? ""
        selectedIcon = habit.icon ?? "circle.fill"
        selectedColor = habit.color ?? "#007AFF"
        selectedFrequency = habit.frequency ?? "daily"
        notes = habit.notes ?? ""
        
        if let customDaysString = habit.customDays, !customDaysString.isEmpty {
            customDays = customDaysString
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        trackDetails = (habit.value(forKey: "trackDetails") as? Bool) ?? false
        detailType = (habit.value(forKey: "detailType") as? String) ?? "general"
        useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
        isNegativeHabit = (habit.value(forKey: "isNegativeHabit") as? Bool) ?? false
    }
    
    // MARK: - Save Methods
    
    func saveHabit() async throws {
        guard isValid, !isSaving else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let customDaysString = customDays.sorted().map(String.init).joined(separator: ",")
        
        await MainActor.run {
            if let existingHabit = habit {
                // Update existing habit
                CoreDataManager.shared.updateHabit(
                    existingHabit,
                    name: name,
                    color: selectedColor,
                    icon: selectedIcon,
                    frequency: selectedFrequency,
                    customDays: customDaysString,
                    notes: notes,
                    collection: nil
                )
                
                // Set dynamic properties
                existingHabit.setValue(trackDetails, forKey: "trackDetails")
                existingHabit.setValue(detailType, forKey: "detailType")
                existingHabit.setValue(isNegativeHabit ? false : useMultipleStates, forKey: "useMultipleStates")
                existingHabit.setValue(isNegativeHabit, forKey: "isNegativeHabit")
            } else {
                // Create new habit
                let newHabit = CoreDataManager.shared.createHabit(
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
                newHabit.setValue(trackDetails, forKey: "trackDetails")
                newHabit.setValue(detailType, forKey: "detailType")
                newHabit.setValue(isNegativeHabit ? false : useMultipleStates, forKey: "useMultipleStates")
                newHabit.setValue(isNegativeHabit, forKey: "isNegativeHabit")
            }
            
            CoreDataManager.shared.saveContext()
        }
    }
    
    func deleteHabit() async throws {
        guard let habit = habit else { return }
        
        await MainActor.run {
            CoreDataManager.shared.deleteHabit(habit)
        }
    }
}

// MARK: - Edit Habit View

struct EditHabitView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    
    // MARK: - State Properties
    
    @StateObject private var viewModel: HabitFormViewModel
    @State private var showingDeleteAlert = false
    
    // MARK: - Initialization
    
    init(habit: Habit) {
        self.habit = habit
        self._viewModel = StateObject(wrappedValue: HabitFormViewModel(habit: habit))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
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
    
    private func deleteHabit() {
        Task {
            do {
                try await viewModel.deleteHabit()
                dismiss()
            } catch {
                // Handle error if needed
            }
        }
    }
}
