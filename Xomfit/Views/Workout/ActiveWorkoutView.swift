import SwiftUI
import PhotosUI

struct ActiveWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = WorkoutLoggerViewModel()
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var showFinishSheet = false
    @State private var workoutDescription = ""
    @State private var saveAsTemplate = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var restTimerHapticFired = false
    @State private var showStartingExercisePicker = false

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
                            .onTapGesture {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
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
                        XomButton("Add Exercise", variant: .primary, icon: "plus") {
                            showExercisePicker = true
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: Theme.Radius.xl))
                        .padding(.bottom, Theme.Spacing.md)
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
                        ExerciseTransitionCard(
                            viewModel: viewModel,
                            onAddExercise: { showExercisePicker = true },
                            onFinishWorkout: {
                                Haptics.success()
                                workoutDescription = ""
                                showFinishSheet = true
                            }
                        )
                            .padding(Theme.Spacing.md)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.xomConfident, value: viewModel.showExerciseTransition)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Empty — just ensures keyboard inset is respected; actual toolbar is above
                Color.clear.frame(height: 0)
            }
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.recalculateRestTimer()
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
                location: $viewModel.location,
                rating: $viewModel.rating,
                saveAsTemplate: $saveAsTemplate,
                selectedPhotos: $selectedPhotos,
                photoImages: $photoImages,
                isSaving: viewModel.isSaving,
                onFinish: { finishWorkout() }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartingExercisePicker) {
            NavigationStack {
                List {
                    let incomplete = Array(viewModel.exercises.enumerated()).filter { _, ex in
                        ex.sets.contains { $0.completedAt == Date.distantPast }
                    }
                    if incomplete.isEmpty {
                        Text("All exercises complete!")
                            .foregroundStyle(Theme.textSecondary)
                            .font(Theme.fontBody)
                    } else {
                        ForEach(incomplete, id: \.element.id) { idx, exercise in
                            let remaining = exercise.sets.filter { $0.completedAt == Date.distantPast }.count
                            Button {
                                viewModel.focusExerciseIndex = idx
                                viewModel.focusSetIndex = 0
                                showStartingExercisePicker = false
                            } label: {
                                HStack {
                                    Text(exercise.exercise.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(remaining) sets left")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Start With")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("First") {
                            showStartingExercisePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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

            // Timer — fontNumberLarge monospaced + metric label
            VStack(spacing: 1) {
                Text(viewModel.workoutName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(viewModel.durationString)
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            // Focus mode toggle
            Button {
                withAnimation {
                    viewModel.focusMode.toggle()
                    if viewModel.focusMode {
                        // Default to first incomplete exercise
                        if let firstIncomplete = viewModel.exercises.firstIndex(where: { ex in
                            ex.sets.contains { $0.completedAt == Date.distantPast }
                        }) {
                            viewModel.focusExerciseIndex = firstIncomplete
                            viewModel.focusSetIndex = 0
                        } else {
                            viewModel.syncFocusToCurrentExercise()
                        }
                        if viewModel.exercises.count > 1 {
                            showStartingExercisePicker = true
                        }
                    }
                }
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
            XomBadge(
                "Rest Timer",
                icon: "timer",
                color: viewModel.defaultRestDuration > 0 ? Theme.accent : Theme.textSecondary,
                variant: .display
            )

            Spacer()

            Menu {
                Button("Off") { viewModel.defaultRestDuration = 0 }
                Button("30s") { viewModel.defaultRestDuration = 30 }
                Button("60s") { viewModel.defaultRestDuration = 60 }
                Button("90s") { viewModel.defaultRestDuration = 90 }
                Button("120s") { viewModel.defaultRestDuration = 120 }
                Button("180s") { viewModel.defaultRestDuration = 180 }
            } label: {
                XomBadge(
                    viewModel.defaultRestDuration > 0 ? "\(Int(viewModel.defaultRestDuration))s" : "Off",
                    color: viewModel.defaultRestDuration > 0 ? Theme.accent : Theme.textSecondary,
                    variant: .interactive,
                    isActive: viewModel.defaultRestDuration > 0
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            XomEmptyState(
                symbolStack: ["dumbbell.fill", "figure.strengthtraining.traditional"],
                title: "No exercises yet",
                subtitle: "Tap \"Add Exercise\" to get started.",
                floatingLoop: true
            )
            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func finishWorkout() {
        guard !viewModel.isSaving else { return }
        guard let user = authService.currentUser else { return }
        viewModel.isSaving = true
        let userId = user.id.uuidString.lowercased()
        let notes = workoutDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save as template if requested
        if saveAsTemplate {
            let templateExercises = viewModel.exercises.map { ex in
                WorkoutTemplate.TemplateExercise(
                    id: UUID().uuidString,
                    exercise: ex.exercise,
                    targetSets: ex.sets.count,
                    targetReps: ex.bestSet.map { "\($0.reps)" } ?? "8",
                    notes: ex.notes
                )
            }
            let template = WorkoutTemplate(
                id: UUID().uuidString,
                name: viewModel.workoutName,
                description: notes.isEmpty ? "Custom template" : notes,
                exercises: templateExercises,
                estimatedDuration: Int(Date().timeIntervalSince(viewModel.startTime) / 60),
                category: .custom,
                isCustom: true
            )
            TemplateService.shared.saveCustomTemplate(template)
        }

        Task {
            // Upload photos if any were selected
            var uploadedURLs: [String]?
            if !photoImages.isEmpty {
                uploadedURLs = try? await PhotoService.shared.uploadWorkoutPhotos(
                    photoImages,
                    workoutId: UUID().uuidString,
                    userId: userId
                )
            }

            await viewModel.finishWorkout(userId: userId, notes: notes.isEmpty ? nil : notes, photoURLs: uploadedURLs)
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
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface.opacity(0.5))
                            .clipShape(Circle())
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
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface.opacity(0.5))
                            .clipShape(Circle())
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

            // Variant config (grip, attachment, position, laterality)
            if exercise.exercise.supportedGrips != nil ||
               exercise.exercise.supportedAttachments != nil ||
               exercise.exercise.supportedPositions != nil ||
               exercise.exercise.supportsUnilateral {
                ExerciseConfigRow(
                    exercise: exercise,
                    onGripChanged: { grip in viewModel.setGrip(exerciseIndex: exerciseIndex, grip: grip) },
                    onAttachmentChanged: { att in viewModel.setAttachment(exerciseIndex: exerciseIndex, attachment: att) },
                    onPositionChanged: { pos in viewModel.setPosition(exerciseIndex: exerciseIndex, position: pos) },
                    onLateralityChanged: { lat in viewModel.setLaterality(exerciseIndex: exerciseIndex, laterality: lat) }
                )
            }

            // Laterality badge
            if exercise.exercise.supportsUnilateral && exercise.selectedLaterality != .bilateral {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                    Text(exercise.selectedLaterality.displayName)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.capsule)
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
                    },
                    lateralityLabel: exercise.selectedLaterality != .bilateral ? (exercise.exercise.muscleGroups.contains(where: { [.quads, .hamstrings, .glutes, .calves].contains($0) }) ? "/leg" : "/arm") : nil
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

// MARK: - Exercise Transition Card

private struct ExerciseTransitionCard: View {
    let viewModel: WorkoutLoggerViewModel
    var onAddExercise: (() -> Void)?
    var onFinishWorkout: (() -> Void)?
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

            // All exercises complete — prompt to add or finish
            if viewModel.allExercisesComplete {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.body)
                            .foregroundStyle(Theme.accent)
                        Text("All exercises complete!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("Add another exercise or finish your workout.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    // Add Exercise
                    if let onAddExercise {
                        Button {
                            withAnimation { viewModel.dismissTransition() }
                            onAddExercise()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                Text("Add Exercise")
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
                    }

                    // Finish Workout
                    if let onFinishWorkout {
                        Button {
                            withAnimation { viewModel.dismissTransition() }
                            onFinishWorkout()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.bold))
                                Text("Finish Workout")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
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
    @Binding var location: String
    @Binding var rating: Int
    @Binding var saveAsTemplate: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoImages: [UIImage]
    let isSaving: Bool
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Star Rating
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How was your workout?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        withAnimation(.xomChill) {
                                            rating = rating == star ? 0 : star
                                        }
                                    } label: {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                                }
                                Spacer()
                            }
                        }

                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("Gym name", text: $location)
                                    .font(Theme.fontBody)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .padding(Theme.Spacing.sm)
                            .background(Theme.surface)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Optional — appears on your feed post.")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        TextEditor(text: $description)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .frame(minHeight: 80, maxHeight: 120)
                            .background(Theme.surface)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                            )

                        // Save as template toggle
                        Toggle(isOn: $saveAsTemplate) {
                            HStack(spacing: 8) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Theme.accent)
                                Text("Save as Template")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .tint(Theme.accent)

                        // Photos
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Add up to 4 photos from your workout.")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)

                            if !photoImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(photoImages.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: photoImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(.rect(cornerRadius: 8))

                                                Button {
                                                    photoImages.remove(at: index)
                                                    if index < selectedPhotos.count {
                                                        selectedPhotos.remove(at: index)
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundStyle(.white)
                                                        .shadow(radius: 2)
                                                }
                                                .offset(x: 4, y: -4)
                                            }
                                        }
                                    }
                                }
                            }

                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 4,
                                matching: .images
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(photoImages.isEmpty ? "Add Photos" : "Change Photos")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.accent.opacity(0.12))
                                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            }
                            .onChange(of: selectedPhotos) { _, newItems in
                                Task {
                                    photoImages = await PhotoService.shared.loadImages(from: newItems)
                                }
                            }
                        }

                        // Finish button
                        Button {
                            Haptics.workoutComplete()
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
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
