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
                    // Search bar — hairline border, surface fill, textTertiary placeholder
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textTertiary)
                        TextField("Search exercises...", text: $searchText)
                            .foregroundStyle(Theme.textPrimary)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                    // Muscle group filter chips — XomBadge interactive
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Button { selectedMuscleGroup = nil } label: {
                                XomBadge("All", variant: .interactive, isActive: selectedMuscleGroup == nil)
                            }
                            .buttonStyle(.plain)
                            ForEach(MuscleGroup.allCases, id: \.self) { mg in
                                Button { selectedMuscleGroup = selectedMuscleGroup == mg ? nil : mg } label: {
                                    XomBadge(mg.displayName, variant: .interactive, isActive: selectedMuscleGroup == mg)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                    }

                    // Equipment filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Button { selectedEquipment = nil } label: {
                                XomBadge("All Equipment", variant: .interactive, isActive: selectedEquipment == nil)
                            }
                            .buttonStyle(.plain)
                            ForEach(Equipment.allCases, id: \.self) { eq in
                                Button { selectedEquipment = selectedEquipment == eq ? nil : eq } label: {
                                    XomBadge(eq.displayName, variant: .interactive, isActive: selectedEquipment == eq)
                                }
                                .buttonStyle(.plain)
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

private struct ExerciseRow: View {
    let exercise: Exercise
    let onTap: () -> Void

    @State private var showDetails = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: exercise.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 4) {
                        XomBadge(exercise.equipment.displayName, variant: .secondary)
                        ForEach(exercise.muscleGroups.prefix(2), id: \.self) { mg in
                            XomBadge(mg.displayName, variant: .secondary)
                        }
                    }
                }
                Spacer()

                Button {
                    Haptics.selection()
                    showDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show details for \(exercise.name)")

                Image(systemName: "plus.circle")
                    .foregroundStyle(Theme.accent)
            }
            .frame(minHeight: 48)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            ExerciseDetailSheet(exercise: exercise)
        }
    }
}
