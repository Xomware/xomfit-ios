import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup? = nil
    @State private var selectedEquipment: Equipment? = nil

    private static let recentKey = "recentExerciseIds"

    private var recentExercises: [Exercise] {
        let ids = UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? []
        return ids.compactMap { id in ExerciseDatabase.all.first(where: { $0.id == id }) }
    }

    private static func recordRecent(_ exercise: Exercise) {
        var ids = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        ids.removeAll { $0 == exercise.id }
        ids.insert(exercise.id, at: 0)
        UserDefaults.standard.set(Array(ids.prefix(10)), forKey: recentKey)
    }

    private var filtered: [Exercise] {
        var exercises = ExerciseDatabase.all
        if let mg = selectedMuscleGroup {
            exercises = exercises.filter { $0.muscleGroups.contains(mg) }
        }
        if let eq = selectedEquipment {
            exercises = exercises.filter { $0.equipment == eq }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            exercises = exercises.filter {
                $0.name.lowercased().contains(query) ||
                $0.muscleGroups.map { $0.rawValue }.joined().contains(query) ||
                $0.equipment.rawValue.contains(query)
            }
        }
        return exercises.sorted { $0.name < $1.name }
    }

    private var groupedByMuscle: [(String, [Exercise])] {
        let dict = Dictionary(grouping: filtered) { ex in
            ex.muscleGroups.first?.displayName ?? "Other"
        }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textSecondary)
                        TextField("Search exercises...", text: $searchText)
                            .foregroundStyle(Theme.textPrimary)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                    // Muscle group filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            FilterChip(label: "All", isSelected: selectedMuscleGroup == nil) {
                                selectedMuscleGroup = nil
                            }
                            ForEach(MuscleGroup.allCases, id: \.self) { mg in
                                FilterChip(label: mg.displayName, isSelected: selectedMuscleGroup == mg) {
                                    selectedMuscleGroup = selectedMuscleGroup == mg ? nil : mg
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                    }

                    // Equipment filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            FilterChip(label: "All Equipment", isSelected: selectedEquipment == nil) {
                                selectedEquipment = nil
                            }
                            ForEach(Equipment.allCases, id: \.self) { eq in
                                FilterChip(label: eq.displayName, isSelected: selectedEquipment == eq) {
                                    selectedEquipment = selectedEquipment == eq ? nil : eq
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)
                    }

                    // Exercise list
                    List {
                        // Recently used section
                        if searchText.isEmpty && selectedMuscleGroup == nil && selectedEquipment == nil && !recentExercises.isEmpty {
                            Section {
                                ForEach(recentExercises) { exercise in
                                    ExerciseRow(exercise: exercise) {
                                        Haptics.selection()
                                        Self.recordRecent(exercise)
                                        onSelect(exercise)
                                        dismiss()
                                    }
                                    .listRowBackground(Theme.surface)
                                    .listRowSeparatorTint(Theme.textSecondary.opacity(0.2))
                                }
                            } header: {
                                Text("Recently Used")
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.accent)
                                    .textCase(nil)
                            }
                        }

                        ForEach(groupedByMuscle, id: \.0) { groupName, exercises in
                            Section {
                                ForEach(exercises) { exercise in
                                    ExerciseRow(exercise: exercise) {
                                        Haptics.selection()
                                        Self.recordRecent(exercise)
                                        onSelect(exercise)
                                        dismiss()
                                    }
                                    .listRowBackground(Theme.surface)
                                    .listRowSeparatorTint(Theme.textSecondary.opacity(0.2))
                                }
                            } header: {
                                Text(groupName)
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.accent : Theme.surface)
                .clipShape(.rect(cornerRadius: 20))
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: exercise.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text(exercise.equipment.displayName)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surfaceSecondary)
                            .clipShape(.rect(cornerRadius: 4))
                        ForEach(exercise.muscleGroups.prefix(2), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.surfaceSecondary)
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
