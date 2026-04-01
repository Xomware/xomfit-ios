import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = WorkoutLoggerViewModel()
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var showFinishSheet = false
    @State private var workoutDescription = ""
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

                    // Rest timer config
                    restTimerConfig

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
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Exercise list
                        if viewModel.exercises.isEmpty {
                            emptyState
                        } else {
                            ScrollView {
                                LazyVStack(spacing: Theme.Spacing.md) {
                                    ForEach(viewModel.exercises.indices, id: \.self) { exIdx in
                                        ExerciseCard(
                                            exerciseIndex: exIdx,
                                            viewModel: viewModel
                                        )
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                // Bottom padding so FAB doesn't overlap last card
                                .padding(.bottom, 80)
                            }
                        }
                    }
                }
                .animation(.xomChill, value: viewModel.isRestTimerActive)
                .animation(.xomChill, value: viewModel.showExerciseTransition)
                .animation(.xomChill, value: viewModel.focusMode)

                // Floating Add Exercise button (hidden in focus mode)
                if !viewModel.focusMode {
                    VStack {
                        Spacer()
                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.body.weight(.bold))
                                Text("Add Exercise")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .clipShape(.rect(cornerRadius: 28))
                            .shadow(color: Theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.bottom, Theme.Spacing.lg)
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

                // Exercise Transition Overlay
                if viewModel.showExerciseTransition {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { viewModel.dismissTransition() } }

                    VStack {
                        Spacer()
                        ExerciseTransitionCard(viewModel: viewModel)
                            .padding(Theme.Spacing.md)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.xomConfident, value: viewModel.showExerciseTransition)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            let userId = authService.currentUser?.id.uuidString.lowercased() ?? ""
            if let template {
                viewModel.startFromTemplate(template, userId: userId)
            } else {
                viewModel.startWorkout(name: workoutName, userId: userId)
            }
        }
        .onReceive(timer) { _ in
            viewModel.tickRestTimer()
            viewModel.tickLiveActivity()
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
        .sheet(isPresented: $showFinishSheet) {
            FinishWorkoutSheet(
                description: $workoutDescription,
                isSaving: viewModel.isSaving,
                onFinish: { finishWorkout() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // Discard button
            Button {
                Haptics.warning()
                showDiscardAlert = true
            } label: {
                Text("Discard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.destructive)
            }

            Spacer()

            // Timer
            VStack(spacing: 2) {
                Text(viewModel.workoutName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(viewModel.durationString)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            // Focus mode toggle
            Button {
                withAnimation { viewModel.focusMode.toggle() }
            } label: {
                Image(systemName: viewModel.focusMode ? "list.bullet" : "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.focusMode ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(viewModel.focusMode ? Theme.accent.opacity(0.15) : Theme.textSecondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel(viewModel.focusMode ? "Switch to list view" : "Switch to focus view")

            // Finish button
            Button {
                Haptics.success()
                workoutDescription = ""
                showFinishSheet = true
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 70, height: 32)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Text("Finish")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
    }

    // MARK: - Rest Timer Config

    private var restTimerConfig: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Theme.accent)
            Text("Rest Timer")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Menu {
                Button("Off") { viewModel.defaultRestDuration = 0 }
                Button("30s") { viewModel.defaultRestDuration = 30 }
                Button("60s") { viewModel.defaultRestDuration = 60 }
                Button("90s") { viewModel.defaultRestDuration = 90 }
                Button("120s") { viewModel.defaultRestDuration = 120 }
                Button("180s") { viewModel.defaultRestDuration = 180 }
            } label: {
                Text(viewModel.defaultRestDuration > 0 ? "\(Int(viewModel.defaultRestDuration))s" : "Off")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No exercises yet")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tap \"Add Exercise\" to get started")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func finishWorkout() {
        guard let user = authService.currentUser else { return }
        let userId = user.id.uuidString.lowercased()
        let notes = workoutDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.finishWorkout(userId: userId, notes: notes.isEmpty ? nil : notes)
            if viewModel.errorMessage == nil {
                showFinishSheet = false
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
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 2) {
                Text("New Personal Record!")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.black)
                Text("\(pr.exerciseName) — \(pr.weight.formattedWeight) lbs × \(pr.reps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.75))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.prGold)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
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
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exercise.name)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 4) {
                        ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }

                Spacer()

                // Reorder buttons
                if exerciseIndex > 0 {
                    Button {
                        withAnimation(.xomConfident) {
                            viewModel.moveExercise(from: exerciseIndex, direction: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move \(exercise.exercise.name) up")
                }

                if exerciseIndex < viewModel.exercises.count - 1 {
                    Button {
                        withAnimation(.xomConfident) {
                            viewModel.moveExercise(from: exerciseIndex, direction: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }

            // Variant config (grip, attachment, position)
            if exercise.exercise.supportedGrips != nil ||
               exercise.exercise.supportedAttachments != nil ||
               exercise.exercise.supportedPositions != nil {
                ExerciseConfigRow(
                    exercise: exercise,
                    onGripChanged: { grip in viewModel.setGrip(exerciseIndex: exerciseIndex, grip: grip) },
                    onAttachmentChanged: { att in viewModel.setAttachment(exerciseIndex: exerciseIndex, attachment: att) },
                    onPositionChanged: { pos in viewModel.setPosition(exerciseIndex: exerciseIndex, position: pos) }
                )
            }

            // Column headers
            if !exercise.sets.isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    Spacer().frame(width: 30) // delete button spacer
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
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
            }

            // Sets — use stable element IDs to prevent state loss on expand/collapse
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIdx, workoutSet in
                SetRowView(
                    setNumber: setIdx + 1,
                    workoutSet: workoutSet,
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
    }
}

// MARK: - Exercise Config Row

private struct ExerciseConfigRow: View {
    let exercise: WorkoutExercise
    let onGripChanged: (GripType) -> Void
    let onAttachmentChanged: (CableAttachment) -> Void
    let onPositionChanged: (ExercisePosition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let grips = exercise.exercise.supportedGrips {
                configSection(label: "Grip") {
                    ForEach(grips) { grip in
                        configPill(
                            label: grip.displayName,
                            isSelected: exercise.selectedGrip == grip
                        ) { onGripChanged(grip) }
                    }
                }
            }
            if let attachments = exercise.exercise.supportedAttachments {
                configSection(label: "Attachment") {
                    ForEach(attachments) { attachment in
                        configPill(
                            label: attachment.displayName,
                            isSelected: exercise.selectedAttachment == attachment
                        ) { onAttachmentChanged(attachment) }
                    }
                }
            }
            if let positions = exercise.exercise.supportedPositions {
                configSection(label: "Position") {
                    ForEach(positions) { position in
                        configPill(
                            label: position.displayName,
                            isSelected: exercise.selectedPosition == position
                        ) { onPositionChanged(position) }
                    }
                }
            }
        }
    }

    private func configSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                content()
            }
        }
    }

    private func configPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Theme.accent : Theme.surfaceSecondary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Exercise Transition Card

private struct ExerciseTransitionCard: View {
    let viewModel: WorkoutLoggerViewModel
    @State private var showRemainingList = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header: completed exercise name
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("\(viewModel.completedExerciseName) Complete")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    withAnimation { viewModel.dismissTransition() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            // Option 1: Do Another Set
            Button {
                withAnimation { viewModel.addAnotherSet() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                    Text("Do Another Set")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .stroke(Theme.accent, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add another set to \(viewModel.completedExerciseName)")

            // Option 2: Move to Next Exercise
            if let nextIdx = viewModel.nextExerciseIndex, let nextEx = viewModel.nextExercise {
                Button {
                    withAnimation { viewModel.moveToExercise(index: nextIdx) }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                            Text("Move to \(nextEx.exercise.name)")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)

                        // Show config hints (grips, attachments, positions)
                        configHints(for: nextEx.exercise)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move to \(nextEx.exercise.name)")
            }

            // Option 3: Choose Different
            if !viewModel.remainingExercises.isEmpty {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.xomConfident) {
                            showRemainingList.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet")
                                .font(.subheadline.weight(.bold))
                            Text("Choose Different")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: showRemainingList ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a different exercise")

                    if showRemainingList {
                        VStack(spacing: 0) {
                            ForEach(viewModel.remainingExercises) { item in
                                Button {
                                    withAnimation { viewModel.moveToExercise(index: item.index) }
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Circle()
                                            .fill(Theme.accent.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                        Text(item.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Switch to \(item.name)")
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: -4)
    }

    @ViewBuilder
    private func configHints(for exercise: Exercise) -> some View {
        let hints = buildConfigHints(for: exercise)
        if !hints.isEmpty {
            Text(hints.joined(separator: " \u{2022} "))
                .font(.caption.weight(.medium))
                .foregroundStyle(.black.opacity(0.6))
        }
    }

    private func buildConfigHints(for exercise: Exercise) -> [String] {
        var hints: [String] = []
        if let attachments = exercise.supportedAttachments {
            hints.append(contentsOf: attachments.prefix(2).map(\.displayName))
        }
        if let grips = exercise.supportedGrips {
            hints.append(contentsOf: grips.prefix(2).map(\.displayName))
        }
        if let positions = exercise.supportedPositions {
            hints.append(contentsOf: positions.prefix(2).map(\.displayName))
        }
        return hints
    }
}

// MARK: - Finish Workout Sheet

private struct FinishWorkoutSheet: View {
    @Binding var description: String
    let isSaving: Bool
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a description")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Optional -- this will appear as a caption on your feed post.")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $description)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(Theme.Spacing.sm)
                        .frame(minHeight: 100, maxHeight: 150)
                        .background(Theme.surface)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                        )

                    Button {
                        Haptics.success()
                        onFinish()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Finish Workout")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .disabled(isSaving)

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
