import SwiftUI
import PhotosUI

struct ActiveWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
    /// Mid-workout exercise jumper (#253). Reachable any time via the persistent pill.
    @State private var showExerciseJumper = false
    /// Set after `jumpToExercise` runs; consumed by the list-mode `ScrollViewReader`
    /// to scroll to the picked card, then cleared.
    @State private var pendingScrollIndex: Int?

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header bar
                    headerBar

                    // Persistent current-exercise pill (#253). Sits below the header so it
                    // doesn't fight any other header controls (pause button, etc.).
                    if !viewModel.exercises.isEmpty {
                        currentExercisePill
                    }

                    // Rest timer config — hidden when rest timer is running (redundant with the active card)
                    if !viewModel.isRestTimerActive && !viewModel.focusMode {
                        restTimerConfig
                    }

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
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(spacing: Theme.Spacing.md) {
                                        ForEach(viewModel.exercises.indices, id: \.self) { exIdx in
                                            ExerciseCard(
                                                exerciseIndex: exIdx,
                                                viewModel: viewModel
                                            )
                                            .id(exIdx)
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
                                .onChange(of: pendingScrollIndex) { _, newValue in
                                    guard let idx = newValue else { return }
                                    withAnimation(.xomChill) {
                                        proxy.scrollTo(idx, anchor: .top)
                                    }
                                    // Clear after the scroll has been kicked off.
                                    pendingScrollIndex = nil
                                }
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
            // Push the header below any active Dynamic Island (#289). Even with the
            // existing top safe-area, an active island (e.g. music app) can still
            // occlude the workout header — bump everything down deterministically.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Empty — just ensures keyboard inset is respected; actual toolbar is above
                Color.clear.frame(height: 0)
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
        .sheet(isPresented: $showExerciseJumper) {
            ExerciseJumperSheet(viewModel: viewModel) { idx in
                // Trigger list-mode scroll. In focus mode this is harmless —
                // `.id(viewModel.focusExerciseIndex)` on the focus view drives
                // the visual transition independently.
                pendingScrollIndex = idx
            }
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
        // Tighten horizontal spacing between adjacent controls so the rest pill
        // doesn't get squeezed into multiple lines (#287).
        HStack(spacing: Theme.Spacing.xs) {
            // Discard button — compact
            Button {
                Haptics.warning()
                showDiscardAlert = true
            } label: {
                Text("Discard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.destructive)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: Theme.Spacing.xs)

            // Timer cluster — total time prominent + rest timer chip so both stay visible
            // around the Dynamic Island. Name is secondary (can be hidden by island).
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(viewModel.durationString)
                            .font(Theme.fontNumberMedium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(Theme.accent)

                    if viewModel.isRestTimerActive {
                        let isOvertime = viewModel.restTimeRemaining <= 0
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text(headerRestString)
                                .font(Theme.fontNumberMedium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(isOvertime ? Theme.destructive : Theme.textPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill((isOvertime ? Theme.destructive : Theme.accent).opacity(0.15))
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(viewModel.workoutName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .animation(.xomChill, value: viewModel.isRestTimerActive)

            Spacer(minLength: Theme.Spacing.xs)

            // Pause / Resume toggle — freezes elapsed time + rest timer
            // Visually narrower (32pt) but keeps a 44pt tap target via contentShape.
            Button {
                Haptics.light()
                withAnimation(.xomChill) {
                    viewModel.togglePause()
                }
            } label: {
                Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.isPaused ? Theme.accent : Theme.textPrimary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(viewModel.isPaused ? "Resume workout" : "Pause workout")
            .accessibilityHint(viewModel.isPaused
                ? "Resumes the elapsed timer and rest countdown"
                : "Freezes the elapsed timer and rest countdown")

            // Focus mode toggle — visually narrower, 44pt tap area enforced.
            Button {
                withAnimation {
                    viewModel.focusMode.toggle()
                    if viewModel.focusMode {
                        viewModel.syncFocusToCurrentExercise()
                        if viewModel.completedSets == 0 && viewModel.exercises.count > 1 {
                            showStartingExercisePicker = true
                        }
                    }
                }
            } label: {
                Image(systemName: viewModel.focusMode ? "list.bullet" : "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.focusMode ? Theme.accent : Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(viewModel.focusMode ? Theme.accent.opacity(0.15) : Theme.textSecondary.opacity(0.15))
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(viewModel.focusMode ? "Switch to list view" : "Switch to focus view")

            // Finish button — compact (smaller font + tighter padding to free up header space).
            Button {
                Haptics.success()
                workoutDescription = ""
                showFinishSheet = true
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 60, height: 28)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Text("Finish")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Finish workout")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(Theme.surface)
    }

    // MARK: - Current Exercise Pill (#253)

    /// Persistent, tappable indicator of the current exercise + set.
    /// Sits directly below the header bar (intentionally not inside the headerBar
    /// to avoid colliding with other header controls).
    private var currentExercisePill: some View {
        Button {
            Haptics.selection()
            showExerciseJumper = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                if viewModel.allExercisesComplete {
                    Text("All exercises complete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                } else if let name = viewModel.currentExerciseName {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text("\u{2022}")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)

                    Text("Set \(viewModel.currentSetNumber)/\(max(viewModel.currentExerciseTotalSets, 1))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .accessibilityLabel(pillAccessibilityLabel)
        .accessibilityHint("Opens the exercise list to switch exercises")
    }

    /// Voice-over label that names the current exercise + set context.
    private var pillAccessibilityLabel: String {
        if viewModel.allExercisesComplete {
            return "All exercises complete. Tap to switch exercises."
        }
        guard let name = viewModel.currentExerciseName else {
            return "No current exercise. Tap to choose one."
        }
        let total = max(viewModel.currentExerciseTotalSets, 1)
        return "Current exercise: \(name), set \(viewModel.currentSetNumber) of \(total). Tap to switch exercises."
    }

    /// Compact rest countdown string for the header chip (matches RestTimerView format).
    private var headerRestString: String {
        let remaining = viewModel.restTimeRemaining
        let total = Int(abs(remaining))
        let mins = total / 60
        let secs = total % 60
        let prefix = remaining < 0 ? "-" : ""
        return prefix + String(format: "%d:%02d", mins, secs)
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

    @State private var showDetails = false
    @State private var showSupersetActionSheet = false

    private var isInSuperset: Bool {
        viewModel.exercises.indices.contains(exerciseIndex)
            && viewModel.exercises[exerciseIndex].supersetGroupId != nil
    }

    private var supersetLetter: String? {
        viewModel.supersetLetter(forExercise: exerciseIndex)
    }

    private var canGroupWithNext: Bool {
        guard exerciseIndex + 1 < viewModel.exercises.count else { return false }
        return viewModel.exercises[exerciseIndex].supersetGroupId == nil
            || viewModel.exercises[exerciseIndex].supersetGroupId
                != viewModel.exercises[exerciseIndex + 1].supersetGroupId
    }

    @ViewBuilder
    var body: some View {
        if viewModel.exercises.indices.contains(exerciseIndex) {
            let exercise = viewModel.exercises[exerciseIndex]
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let letter = supersetLetter {
                            Text("Superset \(letter)")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent)
                                .clipShape(.capsule)
                                .accessibilityLabel("Superset \(letter)")
                        }
                        Text(exercise.exercise.name)
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
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

                Button {
                    Haptics.selection()
                    showDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show details for \(exercise.exercise.name)")

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
                    onAddDropSet: {
                        viewModel.addDropSet(exerciseIndex: exerciseIndex, parentSetIndex: setIdx)
                    },
                    lateralityLabel: exercise.selectedLaterality != .bilateral ? (exercise.exercise.muscleGroups.contains(where: { [.quads, .hamstrings, .glutes, .calves].contains($0) }) ? "/leg" : "/arm") : nil,
                    lastSet: viewModel.lastSetForExercise(exercise.exercise.id),
                    personalRecord: viewModel.personalRecordForExercise(exercise.exercise.id)
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
        .overlay(alignment: .leading) {
            // Vertical accent bar marking superset members
            if isInSuperset {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 4)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .onLongPressGesture(minimumDuration: 0.5) {
            // Only present the menu when there is something actionable
            guard isInSuperset || canGroupWithNext else { return }
            Haptics.selection()
            showSupersetActionSheet = true
        }
        .confirmationDialog(
            exercise.exercise.name,
            isPresented: $showSupersetActionSheet,
            titleVisibility: .visible
        ) {
            if isInSuperset {
                Button("Ungroup Superset", role: .destructive) {
                    Haptics.light()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            }
            if canGroupWithNext {
                Button("Group with Next Exercise") {
                    Haptics.success()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isInSuperset
                 ? "This exercise is part of a superset."
                 : "Group this exercise with the next one for back-to-back sets.")
        }
        .sheet(isPresented: $showDetails) {
            ExerciseDetailSheet(exercise: exercise.exercise)
        }
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
