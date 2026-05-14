//
//  AddHabitView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HabitFormViewModel()

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
                    detailKind: $viewModel.detailKind,
                    completionStyle: $viewModel.completionStyle,
                    showingIconSheet: $viewModel.showingIconSheet
                )
            }
            .navigationTitle("New Habit")
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
        }
    }

    private func saveHabit() {
        viewModel.saveHabit(in: modelContext)
        dismiss()
    }
}
