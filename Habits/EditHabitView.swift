//
//  EditHabitView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - Shared Habit Form View Model

@MainActor
@Observable
class HabitFormViewModel {
    // MARK: - Properties

    var name = "" {
        didSet { validateForm() }
    }
    var selectedIcon = "circle.fill"
    var selectedColor = "#FF8C42"
    var selectedFrequency = HabitFrequency.daily.rawValue
    var customDays: [Int] = []
    var notes = ""
    var trackDetails = false
    var detailType = "general"
    var completionStyle: CompletionStyle = .simple
    var showingIconSheet = false
    var isValid = false
    var isSaving = false

    // MARK: - Private Properties

    private var habit: Habit?

    // MARK: - Initialization

    init(habit: Habit? = nil) {
        self.habit = habit

        if let habit = habit {
            loadHabitData(from: habit)
        }

        validateForm()
    }

    // MARK: - Validation

    private func validateForm() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isValid = !trimmedName.isEmpty && trimmedName.count >= 2
    }

    // MARK: - Data Loading

    private func loadHabitData(from habit: Habit) {
        name = habit.name ?? ""
        selectedIcon = habit.icon ?? "circle.fill"
        selectedColor = habit.color ?? "#007AFF"
        selectedFrequency = habit.frequency ?? HabitFrequency.daily.rawValue
        notes = habit.notes ?? ""

        if let customDaysString = habit.customDays, !customDaysString.isEmpty {
            customDays = customDaysString
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }

        trackDetails = habit.trackDetails
        detailType = habit.detailType ?? "general"

        let useMultipleStates = habit.useMultipleStates
        let isNegativeHabit = habit.isNegativeHabit
        completionStyle = CompletionStyle.from(useMultipleStates: useMultipleStates, isNegativeHabit: isNegativeHabit)
    }

    // MARK: - Save Methods

    func saveHabit() async throws {
        guard isValid, !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        let customDaysString = customDays.sorted().map(String.init).joined(separator: ",")
        let bools = completionStyle.asBools

        await MainActor.run {
            if let existingHabit = habit {
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

                existingHabit.trackDetails = trackDetails
                existingHabit.detailType = detailType
                existingHabit.useMultipleStates = bools.useMultipleStates
                existingHabit.isNegativeHabit = bools.isNegativeHabit
            } else {
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

                newHabit.trackDetails = trackDetails
                newHabit.detailType = detailType
                newHabit.useMultipleStates = bools.useMultipleStates
                newHabit.isNegativeHabit = bools.isNegativeHabit
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
    @Environment(\.dismiss) private var dismiss

    let habit: Habit
    @State private var viewModel: HabitFormViewModel
    @State private var showingDeleteAlert = false

    init(habit: Habit) {
        self.habit = habit
        self._viewModel = State(wrappedValue: HabitFormViewModel(habit: habit))
    }

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
                    completionStyle: $viewModel.completionStyle,
                    showingIconSheet: $viewModel.showingIconSheet
                )

                Section {
                    Button("Delete Habit", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHabit()
                    }
                    .fontWeight(.semibold)
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

    private func saveHabit() {
        Task {
            do {
                try await viewModel.saveHabit()
                dismiss()
            } catch { }
        }
    }

    private func deleteHabit() {
        Task {
            do {
                try await viewModel.deleteHabit()
                dismiss()
            } catch { }
        }
    }
}
