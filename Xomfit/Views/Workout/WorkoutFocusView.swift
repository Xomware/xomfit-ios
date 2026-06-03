import SwiftUI

/// Full-screen "gym mode" view showing one exercise and set at a time with large, tappable controls.
struct WorkoutFocusView: View {
    let viewModel: WorkoutLoggerViewModel
    @State private var isEditingWeight = false
    @State private var isEditingReps = false
    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var weightFieldFocused: Bool
    @FocusState private var repsFieldFocused: Bool
    @State private var showExercisePicker = false
    /// Minimized rest-timer state lives on the VM (#409) so the header chip
    /// in `ActiveWorkoutView` can tap-to-expand the fullscreen overlay. Local
    /// `@State` is gone — read/write through `viewModel.isRestTimerMinimized`.
    @AppStorage("restTimerSound") private var restTimerSound = false

    /// Set pill index targeted by a long-press, used to drive the delete
    /// confirmation dialog (#344 C). Distinct from `focusSetIndex` so the
    /// long-press path doesn't fight the tap-to-focus path.
    @State private var pendingDeleteSetIndex: Int?
    @State private var showDeleteSetConfirm = false

    /// True when EITHER the weight or reps numeric field has the keyboard.
    /// Drives the compact-mode collapse of the header + nav rows so the
    /// keyboard never overlaps the active input (#411 bug 6).
    private var keyboardCompactMode: Bool {
        weightFieldFocused || repsFieldFocused
    }

    private var exercise: WorkoutExercise? { viewModel.focusExercise }
    private var currentSet: WorkoutSet? { viewModel.focusSet }

    /// Position-aware superset badge ("A1", "A2", "B1", ...) for the focused
    /// exercise. Returns nil when the focused exercise isn't part of a superset
    /// group. Computed locally (instead of on the VM) per #344 constraints —
    /// no logger VM internals are touched (#344 E2).
    private var supersetBadge: String? {
        let idx = viewModel.focusExerciseIndex
        guard viewModel.exercises.indices.contains(idx),
              let letter = viewModel.supersetLetter(forExercise: idx),
              let members = viewModel.supersetMembers(forExercise: idx),
              let pos = members.firstIndex(of: idx) else { return nil }
        return "\(letter)\(pos + 1)"
    }

    /// Index of the most-recently-completed non-drop set in the focused exercise,
    /// or nil if none has been completed yet. Used to gate the "+ drop set"
    /// capsule (#344 D) AND to choose the insertion point when the user taps it.
    private var lastCompletedNonDropSetIndex: Int? {
        guard let exercise = viewModel.focusExercise else { return nil }
        let candidates = exercise.sets.enumerated().filter { _, s in
            s.completedAt != Date.distantPast && !s.isDropSet
        }
        guard !candidates.isEmpty else { return nil }
        // Prefer the latest by `completedAt`; tie-break by index so we still get
        // a deterministic answer if timestamps collide.
        return candidates.max(by: { lhs, rhs in
            if lhs.element.completedAt != rhs.element.completedAt {
                return lhs.element.completedAt < rhs.element.completedAt
            }
            return lhs.offset < rhs.offset
        })?.offset
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
                .onTapGesture { dismissKeyboard() }

            if let exercise, let currentSet {
                // Pinned top + flexible middle + pinned bottom (#344-A).
                // The top header (exerciseHeader + config + set indicator)
                // collapses when a text field is focused so the keyboard
                // never overlaps the active input (#411 bug 6). The middle
                // (weight/reps/done) absorbs slack via `.frame(maxHeight:
                // .infinity)`. The bottom slot is exerciseNavigation; the
                // minimized rest banner now lives in a sibling `.safeAreaInset`
                // (#411 bug 3) so it never steals vertical space from DONE.
                VStack(spacing: Theme.Spacing.md) {
                    // TOP — exercise header + config + set indicator.
                    // Hidden while a numeric field is focused so the keyboard
                    // can never overlap the active input (#411 bug 6).
                    if !keyboardCompactMode {
                        VStack(spacing: Theme.Spacing.md) {
                            exerciseHeader(exercise: exercise)

                            // Variant config (grip, attachment, position, laterality) + per-session extras
                            // (notes / rest override). Shown unconditionally so the extras pills are
                            // always reachable from focus mode.
                            ExerciseConfigRow(
                                exercise: exercise,
                                onGripChanged: { grip in viewModel.setGrip(exerciseIndex: viewModel.focusExerciseIndex, grip: grip) },
                                onAttachmentChanged: { att in viewModel.setAttachment(exerciseIndex: viewModel.focusExerciseIndex, attachment: att) },
                                onPositionChanged: { pos in viewModel.setPosition(exerciseIndex: viewModel.focusExerciseIndex, position: pos) },
                                onLateralityChanged: { lat in viewModel.setLaterality(exerciseIndex: viewModel.focusExerciseIndex, laterality: lat) },
                                onNotesChanged: { notes in viewModel.setNotes(exerciseIndex: viewModel.focusExerciseIndex, notes: notes) },
                                onRestSecondsChanged: { secs in viewModel.setRestSeconds(exerciseIndex: viewModel.focusExerciseIndex, seconds: secs) },
                                defaultRestSeconds: Int(viewModel.defaultRestDuration)
                            )

                            setIndicator(exercise: exercise)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // Compact-mode marker: just the exercise name so the
                        // user still knows what they're logging. No config
                        // row, no set chips — keyboard has full vertical real
                        // estate.
                        Text(exercise.exercise.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }

                    // MIDDLE — weight / reps / done. Absorbs slack so the top
                    // header stays pinned under the Dynamic Island regardless of
                    // whether the minimized rest banner is showing (#344-A).
                    VStack(spacing: Theme.Spacing.md) {
                        weightDisplay(currentSet: currentSet)
                        repsDisplay(currentSet: currentSet)
                        doneButton(currentSet: currentSet)
                    }
                    .frame(maxHeight: .infinity)

                    // BOTTOM — exercise navigation (prev/next/add + rest config).
                    // The minimized rest banner used to live here (#402) but is
                    // now rendered via `.safeAreaInset(edge: .bottom)` below
                    // (#411 bug 3) so DONE always has guaranteed bottom
                    // clearance. Bottom nav is hidden in compact keyboard mode.
                    if !keyboardCompactMode {
                        exerciseNavigation
                            .transition(.opacity)
                    }
                }
                .id(viewModel.focusExerciseIndex)
                .transition(.push(from: .trailing))
                .animation(.easeInOut(duration: 0.3), value: viewModel.focusExerciseIndex)
                .padding(.top, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.xomChill, value: viewModel.isRestTimerMinimized)
                .animation(.xomChill, value: viewModel.isRestTimerActive)
                .animation(.xomChill, value: keyboardCompactMode)

                // Full-screen rest timer — only when the timer is active AND not minimized.
                // The minimized banner is rendered via `.safeAreaInset(edge: .bottom)`
                // below so it reserves its own row instead of shrinking the header.
                if viewModel.isRestTimerActive && !viewModel.isRestTimerMinimized {
                    fullScreenRestTimer
                        .transition(.opacity)
                }
            } else {
                emptyFocusState
            }
        }
        // Push content below any active Dynamic Island (#289/#402). Bumps
        // content down deterministically when an island is present.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: Theme.Spacing.sm)
        }
        // Minimized rest banner — rendered as a bottom safe-area inset so it
        // reserves its own layout row OUTSIDE the main VStack (#411 bug 3).
        // This guarantees DONE never gets visually overlapped by the banner.
        // Adds Theme.Spacing.sm of bottom padding so the banner sits above
        // the home indicator with breathing room.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isRestTimerActive
                && viewModel.isRestTimerMinimized
                && !keyboardCompactMode {
                minimizedRestTimerBanner
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.xomChill, value: viewModel.isRestTimerMinimized)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
                // Jump focus to the newly added exercise
                viewModel.focusExerciseIndex = viewModel.exercises.count - 1
                viewModel.focusSetIndex = 0
            }
        }
        // Long-press-to-delete confirmation (#344 C). Driven by `pendingDeleteSetIndex`
        // so the focused set index can still drive tap-to-focus without interference.
        .confirmationDialog(
            "Delete this set?",
            isPresented: $showDeleteSetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete set", role: .destructive) {
                guard let idx = pendingDeleteSetIndex else { return }
                Haptics.warning()
                let exIdx = viewModel.focusExerciseIndex
                viewModel.removeSet(exerciseIndex: exIdx, setIndex: idx)
                // Keep `focusSetIndex` in bounds after the deletion.
                if viewModel.exercises.indices.contains(exIdx) {
                    let total = viewModel.exercises[exIdx].sets.count
                    viewModel.focusSetIndex = min(viewModel.focusSetIndex, max(total - 1, 0))
                }
                pendingDeleteSetIndex = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSetIndex = nil
            }
        } message: {
            Text("Removes this set from the current exercise.")
        }
        // `WorkoutLoggerViewModel.startRestTimer` + `skipRestTimer` now own the
        // minimize-state reset, so the previous local `onChange(isRestTimerActive)`
        // handler is gone (#409).
        #if DEBUG
        .onAppear {
            // Agent screenshot helper (#411 bug 6): auto-focus the weight
            // field so the keyboard pops and the compact-mode collapse can
            // be captured from a cold launch.
            if ProcessInfo.processInfo.environment["XOMFIT_AUTO_FOCUS_WEIGHT"] == "1" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    let w = viewModel.focusSet?.weight ?? 0
                    weightText = w > 0 ? w.formattedWeight : ""
                    isEditingWeight = true
                    // Defer the focus assignment one frame so the TextField
                    // is in the view hierarchy before @FocusState binds.
                    try? await Task.sleep(for: .milliseconds(200))
                    weightFieldFocused = true
                }
            }
        }
        #endif
    }

    // MARK: - Exercise Header

    private func exerciseHeader(exercise: WorkoutExercise) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            HStack(spacing: Theme.Spacing.sm) {
                // Superset rotation badge (#344 E2) — e.g. "A1", "A2" so the
                // lifter can see which slot of a paired group is in focus.
                if let badge = supersetBadge {
                    Text(badge)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, Theme.Spacing.tighter)
                        .background(Theme.accent)
                        .clipShape(.capsule)
                        .accessibilityLabel("Superset \(badge)")
                }

                Text(exercise.exercise.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(spacing: Theme.Spacing.tight) {
                ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                    Text(mg.displayName)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, Theme.Spacing.tighter)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 4))
                }
                // Laterality badge when not bilateral
                if exercise.exercise.supportsUnilateral && exercise.selectedLaterality != .bilateral {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.and.right")
                            .font(Theme.fontCaption2)
                        Text(exercise.selectedLaterality.displayName)
                            .font(Theme.fontSmall)
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, Theme.Spacing.tighter)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.capsule)
                }
            }
        }
    }

    // MARK: - Set Indicator

    private func setIndicator(exercise: WorkoutExercise) -> some View {
        // The drop-set capsule used to live at the tail of this scrollable row,
        // which pushed the row off-screen with longer set counts (#384 A). It
        // now lives in its own dedicated row under the reps card via
        // `dropSetCapsuleRow(exercise:)` so this scroller only carries pills
        // and the trailing `+ Set` affordance.
        let canDelete = exercise.sets.count > 1

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, set in
                    let isCompleted = set.completedAt != Date.distantPast
                    let isFocused = idx == viewModel.focusSetIndex
                    Button {
                        viewModel.focusSetIndex = idx
                    } label: {
                        ZStack {
                            // Outer pulse ring for the currently-focused
                            // incomplete set — makes the active set
                            // unmistakable on the gym floor (#411 bug 4).
                            if isFocused && !isCompleted {
                                Circle()
                                    .stroke(Theme.accent.opacity(0.35), lineWidth: 4)
                                    .frame(width: 46, height: 46)
                            }
                            Circle()
                                .fill(isCompleted
                                      ? Theme.accent
                                      : (isFocused ? Theme.accent.opacity(0.22) : Color.clear))
                                .frame(width: 36, height: 36)
                            if !isCompleted {
                                Circle()
                                    .stroke(isFocused ? Theme.accent : Theme.textSecondary.opacity(0.5),
                                            lineWidth: isFocused ? 2.5 : 1.5)
                                    .frame(width: 36, height: 36)
                            }
                            Text("\(idx + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isCompleted ? .black : (isFocused ? Theme.accent : Theme.textSecondary))
                        }
                        // Scale the active chip up so it pops above its
                        // siblings — `.animation(.xomChill)` smooths the
                        // transition as the user advances sets.
                        .scaleEffect(isFocused && !isCompleted ? 1.1 : 1.0)
                        .animation(.xomChill, value: isFocused)
                        // Ensure 44pt min touch target around the 36pt visual
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Long-press to delete (#344 C). Guarded so the last
                    // remaining set is never deletable — every exercise needs
                    // at least one set in focus mode. Surfaced as both
                    // long-press AND a context menu so the affordance is
                    // discoverable (#411 bug 5).
                    .onLongPressGesture(minimumDuration: 0.5) {
                        guard canDelete else { return }
                        Haptics.selection()
                        pendingDeleteSetIndex = idx
                        showDeleteSetConfirm = true
                    }
                    .contextMenu {
                        if canDelete {
                            Button(role: .destructive) {
                                Haptics.warning()
                                pendingDeleteSetIndex = idx
                                showDeleteSetConfirm = true
                            } label: {
                                Label("Remove set", systemImage: "trash")
                            }
                        }
                    }
                    .accessibilityLabel("Set \(idx + 1)\(isCompleted ? ", completed" : "")\(isFocused ? ", current" : "")")
                    .accessibilityHint(canDelete
                        ? "Long press or use the context menu to delete this set"
                        : "Add another set before this one can be deleted")
                }

                // + Set menu — offers PR, PR+5, Drop Set, Same Set options
                addSetMenu(exercise: exercise)
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    // MARK: - Add Set Menu

    /// Menu for adding a new set with different prefill options:
    /// PR (personal record weight), PR+5, Drop Set, Same Set (copy last set).
    /// Reps are adjusted based on weight using progressive overload formula.
    @ViewBuilder
    private func addSetMenu(exercise: WorkoutExercise) -> some View {
        let exerciseId = exercise.exercise.id
        let prSet = viewModel.personalRecordForExercise(exerciseId)
        let lastSet = exercise.sets.last

        Menu {
            // PR - use personal record weight, adjust reps based on weight diff from last
            if let pr = prSet, pr.weight > 0 {
                let prReps = adjustedReps(targetWeight: pr.weight, baseWeight: lastSet?.weight ?? pr.weight, baseReps: lastSet?.reps ?? pr.reps)
                Button {
                    addSetWithValues(weight: pr.weight, reps: prReps)
                } label: {
                    Label("PR (\(formatWeightCompact(pr.weight)) × \(prReps))", systemImage: "trophy")
                }

                // PR + 5 - heavier weight = fewer reps
                let pr5Weight = pr.weight + 5
                let pr5Reps = adjustedReps(targetWeight: pr5Weight, baseWeight: lastSet?.weight ?? pr.weight, baseReps: lastSet?.reps ?? pr.reps)
                Button {
                    addSetWithValues(weight: pr5Weight, reps: pr5Reps)
                } label: {
                    Label("PR+5 (\(formatWeightCompact(pr5Weight)) × \(pr5Reps))", systemImage: "trophy.fill")
                }
            }

            // Drop Set - only if a non-drop set has been completed
            if let parentIdx = lastCompletedNonDropSetIndex {
                Button {
                    dismissKeyboard()
                    Haptics.light()
                    let exerciseIndex = viewModel.focusExerciseIndex
                    viewModel.addDropSet(exerciseIndex: exerciseIndex, parentSetIndex: parentIdx)
                    // Point focus at newly inserted drop set
                    if viewModel.exercises.indices.contains(exerciseIndex),
                       viewModel.exercises[exerciseIndex].sets.indices.contains(parentIdx + 1) {
                        viewModel.focusSetIndex = parentIdx + 1
                    }
                } label: {
                    Label("Drop Set", systemImage: "arrow.down.right")
                }
            }

            // Same Set - copy last set values exactly
            Button {
                addSetWithValues(weight: lastSet?.weight ?? 0, reps: lastSet?.reps ?? 0)
            } label: {
                if let last = lastSet, last.weight > 0 {
                    Label("Same (\(formatWeightCompact(last.weight)) × \(last.reps))", systemImage: "doc.on.doc")
                } else {
                    Label("Empty Set", systemImage: "plus")
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                Text("Set")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Theme.accent.opacity(0.15))
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
        .accessibilityLabel("Add set")
        .accessibilityHint("Opens menu to add a new set with PR, PR+5, Drop Set, or Same Set options")
    }

    /// Adjusts reps based on weight change using progressive overload formula.
    /// Rule: For every 5 lbs increase, subtract ~1 rep. For every 5 lbs decrease, add ~2 reps.
    /// Clamped to 1-20 rep range.
    private func adjustedReps(targetWeight: Double, baseWeight: Double, baseReps: Int) -> Int {
        guard baseWeight > 0, baseReps > 0 else { return baseReps > 0 ? baseReps : 8 }

        let weightDiff = targetWeight - baseWeight
        // Roughly 1 rep per 5 lbs for increases, 2 reps per 5 lbs for decreases (drop sets benefit from higher reps)
        let repAdjustment: Int
        if weightDiff > 0 {
            // Heavier = fewer reps (1 rep per 5 lbs)
            repAdjustment = -Int(round(weightDiff / 5.0))
        } else {
            // Lighter = more reps (2 reps per 5 lbs for drop set style)
            repAdjustment = Int(round(abs(weightDiff) / 5.0 * 1.5))
        }

        return max(1, min(20, baseReps + repAdjustment))
    }

    /// Helper to add a set with specific weight/reps values
    private func addSetWithValues(weight: Double, reps: Int) {
        dismissKeyboard()
        Haptics.light()
        let exerciseIndex = viewModel.focusExerciseIndex
        guard viewModel.exercises.indices.contains(exerciseIndex) else { return }

        let exercise = viewModel.exercises[exerciseIndex]
        let newSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: exercise.exercise.id,
            weight: weight,
            reps: reps,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: Date.distantPast
        )
        viewModel.exercises[exerciseIndex].sets.append(newSet)
        viewModel.focusSetIndex = viewModel.exercises[exerciseIndex].sets.count - 1
    }

    /// Compact weight format for menu labels
    private func formatWeightCompact(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    // MARK: - Weight Display

    private func weightDisplay(currentSet: WorkoutSet) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            Text("WEIGHT")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

            if isEditingWeight {
                TextField("0", text: $weightText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($weightFieldFocused)
                    .onSubmit { commitWeight() }
                    .onChange(of: weightFieldFocused) { _, focused in
                        if !focused { commitWeight() }
                    }
                    .frame(maxWidth: 200)
            } else {
                Button {
                    weightText = currentSet.weight > 0 ? currentSet.weight.formattedWeight : ""
                    isEditingWeight = true
                    weightFieldFocused = true
                } label: {
                    Text(currentSet.weight.formattedWeight)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Weight: \(currentSet.weight.formattedWeight) pounds. Tap to edit.")
            }

            // Per-side indicator
            if currentSet.weightMode == .perSide {
                Text("lbs x2 (per side)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            } else {
                Text("lbs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Reps Display

    private func repsDisplay(currentSet: WorkoutSet) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            Text("REPS")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

            if isEditingReps {
                TextField("0", text: $repsText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($repsFieldFocused)
                    .onSubmit { commitReps() }
                    .onChange(of: repsFieldFocused) { _, focused in
                        if !focused { commitReps() }
                    }
                    .frame(maxWidth: 200)
            } else {
                Button {
                    repsText = currentSet.reps > 0 ? "\(currentSet.reps)" : ""
                    isEditingReps = true
                    repsFieldFocused = true
                } label: {
                    Text("\(currentSet.reps)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Reps: \(currentSet.reps). Tap to edit.")
            }

            if let exercise = viewModel.focusExercise, exercise.selectedLaterality != .bilateral {
                let isLeg = exercise.exercise.muscleGroups.contains(where: { [.quads, .hamstrings, .glutes, .calves].contains($0) })
                Text(isLeg ? "per leg" : "per arm")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Done Button

    private func doneButton(currentSet: WorkoutSet) -> some View {
        let isCompleted = currentSet.completedAt != Date.distantPast
        return Button {
            dismissKeyboard()
            if !isCompleted {
                viewModel.completeFocusedSet()
            }
        } label: {
            Text(isCompleted ? "COMPLETED" : "DONE")
                .font(.title3.weight(.black))
                .foregroundStyle(isCompleted ? Theme.textSecondary : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isCompleted ? Theme.surface : Theme.accent)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .disabled(isCompleted)
        .accessibilityLabel(isCompleted ? "Set completed" : "Complete set")
    }

    // MARK: - Exercise Navigation

    private var exerciseNavigation: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.lg) {
                Button {
                    dismissKeyboard()
                    viewModel.focusPreviousExercise()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(viewModel.focusExerciseIndex > 0 ? Theme.textPrimary : Theme.textSecondary.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .disabled(viewModel.focusExerciseIndex <= 0)
                .accessibilityLabel("Previous exercise")

                Text("\(viewModel.focusExerciseIndex + 1) / \(viewModel.exercises.count)")
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(Theme.textSecondary)

                Button {
                    dismissKeyboard()
                    viewModel.focusNextExercise()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(viewModel.focusExerciseIndex < viewModel.exercises.count - 1 ? Theme.textPrimary : Theme.textSecondary.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .disabled(viewModel.focusExerciseIndex >= viewModel.exercises.count - 1)
                .accessibilityLabel("Next exercise")

                // Add exercise button
                Button {
                    showExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add exercise")
            }

            // Rest timer config (compact, visible in focus mode)
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(Theme.fontCaption2)
                    .foregroundStyle(Theme.accent)
                Text("Rest:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Menu {
                    Button("Off") { viewModel.defaultRestDuration = 0 }
                    Button("30s") { viewModel.defaultRestDuration = 30 }
                    Button("60s") { viewModel.defaultRestDuration = 60 }
                    Button("90s") { viewModel.defaultRestDuration = 90 }
                    Button("120s") { viewModel.defaultRestDuration = 120 }
                    Button("180s") { viewModel.defaultRestDuration = 180 }
                } label: {
                    Text(viewModel.defaultRestDuration > 0 ? "\(Int(viewModel.defaultRestDuration))s" : "Off")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(.capsule)
                }
            }
        }
    }

    // MARK: - Minimized Rest Timer Banner (inline)

    /// Compact rest-timer banner rendered via `.safeAreaInset(edge: .bottom)`
    /// on the parent ZStack so it reserves its own layout row instead of
    /// compressing the top header under the Dynamic Island (#344-A).
    ///
    /// Layout reimagined in #384 B — single ~64pt row, no truncation:
    /// `[↗ expand]  [-1:41]  [REST]    ........    [+30s]  [Lift]`
    /// Tapping anywhere on the background (not on a button) expands back to
    /// the full-screen rest timer. Skip is intentionally absent — Lift is the
    /// same action (skip rest + advance set).
    private var minimizedRestTimerBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Expand glyph — far left, 44pt hit target.
            Button {
                Haptics.light()
                withAnimation(.xomChill) { viewModel.isRestTimerMinimized = false }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expand rest timer")

            // Countdown — focal point. Large monospaced digits, red on overtime.
            Text(restTimeString)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restIsOvertime ? Theme.destructive : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel("Rest time remaining \(restTimeString)")

            // REST caption next to countdown.
            Text("REST")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)

            Spacer(minLength: Theme.Spacing.sm)

            // +30s — secondary, accent-tinted capsule.
            Button {
                Haptics.light()
                viewModel.extendRestTimer()
            } label: {
                Text("+30s")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(minHeight: 44)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add 30 seconds to rest timer")

            // Lift — primary CTA. Same action as the old Skip (end rest +
            // advance to next set), so Skip was dropped entirely (#384 B).
            Button {
                Haptics.success()
                viewModel.skipRestTimer()
            } label: {
                Text("Lift")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(minHeight: 44)
                    .background(Theme.accent)
                    .clipShape(.capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lift — end rest and start next set")
            .accessibilityHint("Ends the rest timer immediately")
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(
            // Tap-anywhere-on-background expands the banner. Restricted to a
            // background layer so the buttons keep their own hit handling.
            Theme.surface
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.light()
                    withAnimation(.xomChill) { viewModel.isRestTimerMinimized = false }
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var restIsOvertime: Bool { viewModel.restTimeRemaining <= 0 }

    private var restProgress: Double {
        guard viewModel.restDuration > 0 else { return 0 }
        if restIsOvertime { return 1.0 }
        return 1 - (viewModel.restTimeRemaining / viewModel.restDuration)
    }

    private var restTimeString: String {
        if restIsOvertime {
            let total = Int(abs(viewModel.restTimeRemaining))
            return String(format: "-%d:%02d", total / 60, total % 60)
        }
        let total = Int(viewModel.restTimeRemaining)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Fullscreen rest-timer overlay. Layout reimagined in #402: minimize
    /// chevron pinned to the TOP-LEFT corner; LIFT button pinned to the
    /// BOTTOM with explicit bottom padding that always clears the home
    /// indicator. The middle (ring + NEXT UP + +30s) sits inside a
    /// Spacer-padded VStack so it centers between the two anchored slots.
    ///
    /// Uses inline layout (NOT `.safeAreaInset`) because the overlay is
    /// already a sibling inside the focus view's ZStack — adding additional
    /// safe-area insets there would push the button below the visible bounds.
    ///
    /// Fixed #448: Content was pushed below Dynamic Island and LIFT button
    /// was pushed off screen. Now uses GeometryReader to respect safe areas
    /// properly and reduces fixed padding to prevent overflow.
    private var fullScreenRestTimer: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP — minimize chevron on the left. Positioned below Dynamic Island.
                    HStack {
                        Button {
                            Haptics.light()
                            withAnimation(.xomChill) { viewModel.isRestTimerMinimized = true }
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(Theme.surface.opacity(0.6))
                                .clipShape(Circle())
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Minimize rest timer")
                        .accessibilityHint("Collapses the rest timer to a banner so you can see the next set")

                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, geometry.safeAreaInsets.top + Theme.Spacing.xs)

                    Spacer(minLength: Theme.Spacing.sm)

                    // Large circular ring - scales down on smaller screens
                    let ringSize: CGFloat = min(200, geometry.size.height * 0.28)
                    ZStack {
                        Circle()
                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 10)

                        Circle()
                            .trim(from: 0, to: restProgress)
                            .stroke(restIsOvertime ? Theme.destructive : Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: restProgress)

                        VStack(spacing: Theme.Spacing.tight) {
                            Text("REST")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                            Text(restTimeString)
                                .font(.system(size: min(56, ringSize * 0.28), weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(restIsOvertime ? Theme.destructive : .white)
                        }
                    }
                    .frame(width: ringSize, height: ringSize)
                    .padding(.vertical, Theme.Spacing.sm)

                    // Next set context - always show what exercise/set is coming up
                    restTimerNextUpSection

                    // +30s button
                    Button {
                        Haptics.light()
                        viewModel.extendRestTimer()
                    } label: {
                        Text("+30s")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(.capsule)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Add 30 seconds to rest timer")

                    Spacer(minLength: Theme.Spacing.sm)

                    // LIFT — anchored to the bottom with safe area clearance
                    Button {
                        Haptics.success()
                        viewModel.skipRestTimer()
                    } label: {
                        Text("LIFT")
                            .font(.title.weight(.black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.accent)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                            .contentShape(Rectangle())
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .accessibilityLabel("Skip rest timer and start the next set")
                    .accessibilityHint("Ends the rest timer immediately and returns to the lift")

                    // Bottom clearance: respect safe area + small buffer
                    Color.clear.frame(height: max(geometry.safeAreaInsets.bottom, 20) + Theme.Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Rest Timer Next Up Section

    /// Contextual info shown in the fullscreen rest timer: exercise name,
    /// set number, typical weight, and PR proximity.
    @ViewBuilder
    private var restTimerNextUpSection: some View {
        // When the current exercise is fully done, show the next exercise.
        // Otherwise show the focused exercise (user is resting before their next set).
        if let nextEx = viewModel.upcomingExercise {
            // Current exercise done - show what's coming next
            VStack(spacing: Theme.Spacing.tight) {
                Text("NEXT UP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text(nextEx.exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.bottom, Theme.Spacing.sm)
        } else if let focusEx = viewModel.focusExercise {
            // Still on current exercise - show upcoming set context
            let exerciseId = focusEx.exercise.id
            let totalSets = focusEx.sets.count
            let nextSetNumber = viewModel.focusSetIndex + 1
            let lastSet = viewModel.lastSetForExercise(exerciseId)
            let prSet = viewModel.personalRecordForExercise(exerciseId)

            VStack(spacing: Theme.Spacing.xs) {
                // Exercise name
                Text(focusEx.exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                // Set number
                Text("Set \(nextSetNumber) of \(totalSets)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)

                // Typical weight (from last workout)
                if let last = lastSet, last.weight > 0 {
                    Text("Last: \(formatWeight(last.weight)) x \(last.reps)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                // PR proximity hint
                if let pr = prSet, pr.weight > 0 {
                    let currentWeight = viewModel.focusSet?.weight ?? 0
                    if currentWeight > 0 && currentWeight >= pr.weight {
                        Text("PR territory!")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    } else if currentWeight > 0 {
                        let diff = pr.weight - currentWeight
                        if diff <= 10 {
                            Text("\(formatWeight(diff)) from PR")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        }
                    } else {
                        // No current weight entered yet, just show the PR
                        Text("PR: \(formatWeight(pr.weight)) x \(pr.reps)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.sm)
        }
    }

    /// Formats a weight value, removing trailing decimals if whole number.
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) lbs"
        }
        return String(format: "%.1f lbs", weight)
    }

    // MARK: - Empty State

    private var emptyFocusState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No exercises yet")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Add an exercise to use Focus Mode")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func commitWeight() {
        isEditingWeight = false
        guard let value = Double(weightText) else { return }
        viewModel.updateSet(
            exerciseIndex: viewModel.focusExerciseIndex,
            setIndex: viewModel.focusSetIndex,
            weight: value,
            reps: viewModel.focusSet?.reps ?? 0
        )
    }

    private func commitReps() {
        isEditingReps = false
        guard let value = Int(repsText) else { return }
        viewModel.updateSet(
            exerciseIndex: viewModel.focusExerciseIndex,
            setIndex: viewModel.focusSetIndex,
            weight: viewModel.focusSet?.weight ?? 0,
            reps: value
        )
    }

    private func dismissKeyboard() {
        if isEditingWeight { commitWeight() }
        if isEditingReps { commitReps() }
        weightFieldFocused = false
        repsFieldFocused = false
    }
}
