import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var workoutName = "New Workout"
    @State private var showingExercisePicker = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.paddingMedium) {
                        // Timer
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(Theme.accent)
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            if let workout = viewModel.activeWorkout {
                                Text("\(workout.totalSets) sets · \(workout.formattedVolume) lbs")
                                    .font(Theme.fontCaption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .cardStyle()
                        
                        // Exercises
                        if let workout = viewModel.activeWorkout {
                            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                                ExerciseSetCard(
                                    exercise: exercise,
                                    onAddSet: { weight, reps, rpe in
                                        viewModel.addSet(to: index, weight: weight, reps: reps, rpe: rpe)
                                    }
                                )
                            }
                        }
                        
                        // Add Exercise Button
                        Button(action: { showingExercisePicker = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Exercise")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent.opacity(0.15))
                            .cornerRadius(Theme.cornerRadius)
                        }
                        
                        // Finish Button
                        Button(action: {
                            viewModel.finishWorkout()
                            dismiss()
                        }) {
                            Text("Finish Workout")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accent)
                                .cornerRadius(Theme.cornerRadius)
                        }
                        .padding(.top, Theme.paddingMedium)
                    }
                    .padding(Theme.paddingMedium)
                }
            }
            .navigationTitle(workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelWorkout()
                        dismiss()
                    }
                    .foregroundColor(Theme.destructive)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(exercises: viewModel.exercises) { exercise in
                    viewModel.addExercise(exercise)
                }
            }
            .onAppear {
                viewModel.startWorkout(name: workoutName)
                startTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ExerciseSetCard: View {
    let exercise: WorkoutExercise
    let onAddSet: (Double, Int, Double?) -> Void
    @State private var weight = ""
    @State private var reps = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.exercise.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.accent)
            
            // Set Headers
            HStack {
                Text("SET").frame(width: 35)
                Text("LBS").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("").frame(width: 30)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSecondary)
            
            // Logged Sets
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("\(index + 1)")
                        .frame(width: 35)
                        .foregroundColor(Theme.textSecondary)
                    Text(set.weight.formattedWeight)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Theme.textPrimary)
                    Text("\(set.reps)")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Theme.textPrimary)
                    if set.isPersonalRecord {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Theme.prGold)
                            .frame(width: 30)
                    } else {
                        Text("").frame(width: 30)
                    }
                }
                .font(.system(size: 15))
            }
            
            // Input Row
            HStack {
                Text("\(exercise.sets.count + 1)")
                    .frame(width: 35)
                    .foregroundColor(Theme.textSecondary)
                    .font(.system(size: 15))
                
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                
                TextField("0", text: $reps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                
                Button(action: {
                    guard let w = Double(weight), let r = Int(reps) else { return }
                    onAddSet(w, r, nil)
                    weight = ""
                    reps = ""
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 24))
                }
                .frame(width: 30)
            }
        }
        .cardStyle()
    }
}

struct ExercisePickerView: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button(action: {
                    onSelect(exercise)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(exercise.muscleGroups.map { $0.displayName }.joined(separator: ", "))
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
