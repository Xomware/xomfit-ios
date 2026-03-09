import SwiftUI

struct ExerciseLibraryView: View {
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var selectedExercise: Exercise?
    
    var filteredExercises: [Exercise] {
        var results = ExerciseDatabase.all
        if let group = selectedMuscleGroup {
            results = results.filter { $0.muscleGroups.contains(group) }
        }
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return results
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Muscle Group Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedMuscleGroup == nil) {
                            selectedMuscleGroup = nil
                        }
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            FilterChip(title: group.displayName, isSelected: selectedMuscleGroup == group) {
                                selectedMuscleGroup = selectedMuscleGroup == group ? nil : group
                            }
                        }
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.vertical, Theme.paddingSmall)
                }
                
                // Exercise List
                List(filteredExercises) { exercise in
                    Button(action: { selectedExercise = exercise }) {
                        ExerciseRow(exercise: exercise)
                    }
                    .listRowBackground(Theme.cardBackground)
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search \(ExerciseDatabase.all.count) exercises")
            }
        }
        .navigationTitle("Exercise Library")
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Muscle group icon
            Image(systemName: exercise.muscleGroups.first?.icon ?? "figure.strengthtraining.traditional")
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                HStack(spacing: 8) {
                    Text(exercise.muscleGroups.map { $0.displayName }.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    
                    Text("·")
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(exercise.equipment.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent.opacity(0.7))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.accent : Theme.cardBackground)
                .cornerRadius(20)
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.paddingLarge) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: exercise.muscleGroups.first?.icon ?? "figure.strengthtraining.traditional")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.accent)
                            
                            Text(exercise.name)
                                .font(Theme.fontTitle)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 12) {
                                Label(exercise.equipment.displayName, systemImage: "wrench.and.screwdriver")
                                Label(exercise.category.displayName, systemImage: "tag")
                            }
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.paddingLarge)
                        
                        // Muscle Groups
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Muscles")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 8) {
                                ForEach(exercise.muscleGroups, id: \.self) { group in
                                    HStack(spacing: 4) {
                                        Image(systemName: group.icon)
                                            .font(.system(size: 12))
                                        Text(group.displayName)
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.accent.opacity(0.15))
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How To")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(exercise.description)
                                .font(Theme.fontBody)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Tips
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tips")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            
                            ForEach(exercise.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.accent)
                                        .font(.system(size: 14))
                                        .padding(.top, 2)
                                    Text(tip)
                                        .font(Theme.fontBody)
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                        
                        // Placeholder for stick figure animation
                        VStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.accent.opacity(0.3))
                            Text("Animation coming in V1")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.paddingMedium)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
