import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = WorkoutLoggerViewModel()
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var restTimerHapticFired = false

    // Passed in from WorkoutView
    let workoutName: String
    var template: WorkoutTemplate? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header bar
                    headerBar

                    if viewModel.focusMode {
                        // Focus mode — large gym-floor view
                        WorkoutFocusView(viewModel: viewModel)
                    } else {
                        // Rest timer
                        if viewModel.isRestTimerActive {
                            RestTimerView(
                                restTimeRemaining: viewModel.restTimeRemaining,
                                restDuration: viewModel.restDuration,
                                onSkip: {
                                    viewModel.skipRestTimer()
                                    restTimerHapticFired = false
                                },
                                onExtend: { viewModel.extendRestTimer() }
                            )
                            .padding(.horizontal, Theme.paddingMedium)
                            .padding(.vertical, Theme.paddingSmall)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Exercise list
                        if viewModel.exercises.isEmpty {
                            emptyState
                        } else {
                            ScrollView {
                                LazyVStack(spacing: Theme.paddingMedium) {
                                    ForEach(viewModel.exercises.indices, id: \.self) { exIdx in
                                        ExerciseCard(
                                            exerciseIndex: exIdx,
                                            viewModel: viewModel
                                        )
                                    }
                                }
                                .padding(Theme.paddingMedium)
                                // Bottom padding so FAB doesn't overlap last card
                                .padding(.bottom, 80)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.isRestTimerActive)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showNextExercisePrompt)
                .animation(.easeInOut(duration: 0.3), value: viewModel.focusMode)

                // Floating Add Exercise button (hidden in focus mode)
                if !viewModel.focusMode {
                    VStack {
                        Spacer()
                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Add Exercise")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, Theme.paddingLarge)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .cornerRadius(28)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.bottom, Theme.paddingLarge)
                    }
                }

                // PR Celebration Banner
                if viewModel.showPRCelebration, let pr = viewModel.newPR {
                    VStack {
                        PRCelebrationBanner(pr: pr) {
                            withAnimation { viewModel.showPRCelebration = false }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }

                // Next Exercise Toast
                if viewModel.showNextExercisePrompt {
                    VStack {
                        NextExerciseBanner(
                            completedName: viewModel.completedExerciseName ?? "",
                            nextName: viewModel.nextExerciseSuggestion
                        ) {
                            withAnimation { viewModel.showNextExercisePrompt = false }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { viewModel.showNextExercisePrompt = false }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            let userId = authService.currentUser?.id.uuidString ?? ""
            if let template {
                viewModel.startFromTemplate(template, userId: userId)
            } else {
                viewModel.startWorkout(name: workoutName, userId: userId)
            }
        }
        .onReceive(timer) { _ in
            viewModel.tickRestTimer()
            // Haptic fires once when rest timer crosses zero
            if viewModel.isRestTimerActive && viewModel.restTimeRemaining <= 0 && !restTimerHapticFired {
                restTimerHapticFired = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        .onChange(of: viewModel.isRestTimerActive) { _, isActive in
            if isActive {
                restTimerHapticFired = false
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
            }
        }
        .alert("Discard Workout?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.discardWorkout()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("All logged sets will be lost.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // Discard button
            Button {
                showDiscardAlert = true
            } label: {
                Text("Discard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.destructive)
            }

            Spacer()

            // Timer
            VStack(spacing: 2) {
                Text(viewModel.workoutName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(viewModel.durationString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.accent)
            }

            Spacer()

            // Focus mode toggle
            Button {
                withAnimation { viewModel.focusMode.toggle() }
            } label: {
                Image(systemName: viewModel.focusMode ? "list.bullet" : "eye")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(viewModel.focusMode ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(viewModel.focusMode ? Theme.accent.opacity(0.15) : Theme.textSecondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel(viewModel.focusMode ? "Switch to list view" : "Switch to focus view")

            // Finish button
            Button {
                finishWorkout()
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 70, height: 32)
                        .background(Theme.accent)
                        .cornerRadius(8)
                } else {
                    Text("Finish")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .cornerRadius(8)
                }
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingMedium)
        .background(Theme.cardBackground)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.paddingMedium) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text("No exercises yet")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Tap \"Add Exercise\" to get started")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func finishWorkout() {
        guard let userId = authService.currentUser?.id.uuidString else { return }
        Task {
            await viewModel.finishWorkout(userId: userId)
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - PR Celebration Banner

private struct PRCelebrationBanner: View {
    let pr: PersonalRecord
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 2) {
                Text("New Personal Record!")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
                Text("\(pr.exerciseName) — \(pr.weight.formattedWeight) lbs × \(pr.reps)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingMedium)
        .background(Theme.prGold)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.top, Theme.paddingSmall)
        .shadow(color: Theme.prGold.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let exerciseIndex: Int
    let viewModel: WorkoutLoggerViewModel

    @ViewBuilder
    var body: some View {
        if viewModel.exercises.indices.contains(exerciseIndex) {
            let exercise = viewModel.exercises[exerciseIndex]
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exercise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 4) {
                        ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()

                // Reorder buttons
                if exerciseIndex > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.moveExercise(from: exerciseIndex, direction: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move \(exercise.exercise.name) up")
                }

                if exerciseIndex < viewModel.exercises.count - 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.moveExercise(from: exerciseIndex, direction: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move \(exercise.exercise.name) down")
                }

                Button {
                    viewModel.removeExercise(at: exerciseIndex)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }

            // Column headers
            if !exercise.sets.isEmpty {
                HStack(spacing: Theme.paddingSmall) {
                    Text("SET")
                        .frame(width: 24)
                    Spacer()
                    Text("WEIGHT")
                        .frame(maxWidth: .infinity)
                    Text("")
                        .frame(width: 40)
                    Text("REPS")
                        .frame(maxWidth: .infinity)
                    Text("")
                        .frame(width: 36)
                }
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.paddingMedium)
            }

            // Sets
            ForEach(exercise.sets.indices, id: \.self) { setIdx in
                SetRowView(
                    setNumber: setIdx + 1,
                    workoutSet: exercise.sets[setIdx],
                    onWeightChange: { w in
                        viewModel.updateSet(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIdx,
                            weight: w,
                            reps: viewModel.exercises[exerciseIndex].sets[setIdx].reps
                        )
                    },
                    onRepsChange: { r in
                        viewModel.updateSet(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIdx,
                            weight: viewModel.exercises[exerciseIndex].sets[setIdx].weight,
                            reps: r
                        )
                    },
                    onComplete: {
                        viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    },
                    onDelete: {
                        viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    },
                    onToggleWeightMode: {
                        viewModel.toggleWeightMode(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    }
                )
            }

            // Add Set button
            Button {
                viewModel.addSet(to: exerciseIndex)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Set")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent.opacity(0.08))
                .cornerRadius(Theme.cornerRadiusSmall)
            }
            .padding(.top, 4)
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        }
    }
}

// MARK: - Next Exercise Banner

private struct NextExerciseBanner: View {
    let completedName: String
    let nextName: String?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.paddingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                if let nextName {
                    Text("\(completedName) complete")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Up next: \(nextName)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("\(completedName) complete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.top, Theme.paddingSmall)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
