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
    @State private var showSupersetPicker = false
    @State private var showReorderSheet = false
    @State private var showSwapPicker = false
    @State private var showRemoveConfirm = false
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
                // Scrollable content with the classic GeometryReader minHeight
                // pattern: the inner VStack is pinned to AT LEAST the visible
                // height (so the flexible middle still absorbs slack and the
                // bottom nav sits at the bottom), but can grow and scroll when
                // the keyboard or extra rows push it past the screen. This
                // replaces the old fixed ZStack + dual `.safeAreaInset` hacks
                // that fought the Dynamic Island and clipped DONE (#411).
                GeometryReader { proxy in
                ScrollView {
                // Pinned top + flexible middle + pinned bottom (#344-A).
                // The top header (exerciseHeader + config + set indicator)
                // collapses when a text field is focused so the keyboard
                // never overlaps the active input (#411 bug 6). The middle
                // (weight/reps/done) absorbs slack via `.frame(maxHeight:
                // .infinity)`. The bottom slot is exerciseNavigation; the
                // minimized rest banner is an in-flow bottom row below it.
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

                    // Flexible top spacer — expands to vertically center the
                    // weight/reps/done block when content fits, collapses to its
                    // minLength so the VStack can grow past `proxy.size.height`
                    // (and the ScrollView takes over) when the minimized rest
                    // banner or keyboard pushes content past the screen. This
                    // replaces the old `.frame(maxHeight: .infinity)` on the
                    // middle block, which fought the scroll layout and crushed
                    // the cards together when the banner appeared.
                    Spacer(minLength: Theme.Spacing.md)

                    // MIDDLE — weight / reps / done at natural content height.
                    VStack(spacing: Theme.Spacing.md) {
                        weightDisplay(currentSet: currentSet)
                        repsDisplay(currentSet: currentSet)
                        doneButton(currentSet: currentSet)
                    }

                    // Flexible bottom spacer — mirrors the top spacer so the
                    // middle block stays centered between the pinned header and
                    // the bottom navigation when there's slack.
                    Spacer(minLength: Theme.Spacing.md)

                    // BOTTOM — exercise navigation (prev/next/add + rest config).
                    // Hidden in compact keyboard mode.
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
                .padding(.bottom, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .animation(.xomChill, value: viewModel.isRestTimerMinimized)
                .animation(.xomChill, value: viewModel.isRestTimerActive)
                .animation(.xomChill, value: keyboardCompactMode)
                }
                .scrollBounceBehavior(.basedOnSize)
                }
            } else {
                emptyFocusState
            }
        }
        // Real navigation bar. Focus mode is a pushed screen now, so it gets
        // the system back button (and back-swipe) instead of a bespoke toggle,
        // and the bar handles the Dynamic Island — which is what the parent's
        // hand-rolled 130pt spacer and mode-dependent top padding existed to
        // work around.
        .navigationTitle(exercise?.exercise.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Exercise-level actions in one visible place.
            //
            // Reordering was behind a long-press on the list screen's pill,
            // which is invisible, and removing or swapping an exercise could
            // not be done from here at all — the only route was backing out to
            // the list.
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        Haptics.light()
                        showSwapPicker = true
                    } label: {
                        Label("Change Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        Haptics.light()
                        showSupersetPicker = true
                    } label: {
                        Label(
                            viewModel.supersetMembers(forExercise: viewModel.focusExerciseIndex) == nil
                                ? "Superset with…"
                                : "Add to Superset…",
                            systemImage: "link"
                        )
                    }

                    Button {
                        Haptics.light()
                        showReorderSheet = true
                    } label: {
                        Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }

                    Button {
                        Haptics.light()
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Haptics.light()
                        showRemoveConfirm = true
                    } label: {
                        Label("Remove This Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Exercise options")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(viewModel.durationString)
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                        .animation(.xomSnappy, value: viewModel.durationString)

                    Button {
                        Haptics.light()
                        viewModel.togglePause()
                    } label: {
                        Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(viewModel.isPaused ? Theme.accent : Theme.textPrimary)
                    }
                    .accessibilityLabel(viewModel.isPaused ? "Resume workout" : "Pause workout")
                }
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            ExerciseReorderSheet(viewModel: viewModel)
        }
        // Swap keeps this exercise's position in the workout and replaces what
        // it is, which is what "I picked the wrong machine" means. Removing and
        // re-adding would send it to the end of the list.
        .sheet(isPresented: $showSwapPicker) {
            ExercisePickerView { picked in
                viewModel.replaceExercise(at: viewModel.focusExerciseIndex, with: picked)
                showSwapPicker = false
            }
        }
        .confirmationDialog(
            "Remove \(exercise?.exercise.name ?? "this exercise")?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                let index = viewModel.focusExerciseIndex
                viewModel.removeExercise(at: index)
                // Nothing left to focus on, so go back to the list rather than
                // showing an empty exercise screen.
                if viewModel.exercises.isEmpty {
                    viewModel.focusMode = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its logged sets will be removed from this workout.")
        }
        .sheet(isPresented: $showSupersetPicker) {
            SupersetPickerSheet(
                viewModel: viewModel,
                exerciseIndex: viewModel.focusExerciseIndex
            )
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

    /// The tier the current set's numbers would earn, or nil when the lift is
    /// not weight-ranked or the lifter has not given a bodyweight.
    private var currentRank: StrengthRank? {
        guard let exercise, let set = viewModel.focusSet, set.weight > 0 else { return nil }
        return StrengthLevelService.shared.rank(
            exerciseId: exercise.exercise.id,
            weight: set.weight,
            reps: max(set.reps, 1)
        )
    }

    /// Badges only — the exercise name lives in the navigation bar now that
    /// focus mode is a pushed screen, and printing it twice was both redundant
    /// and a waste of the vertical space the big weight/reps controls want.
    private func exerciseHeader(exercise: WorkoutExercise) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            // Superset rotation badge (#344 E2) — e.g. "A1", "A2" so the
            // lifter can see which slot of a paired group is in focus.
            if let badge = supersetBadge {
                Text("Superset \(badge)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, Theme.Spacing.tighter)
                    .background(Theme.accent)
                    .clipShape(.capsule)
                    .accessibilityLabel("Superset \(badge)")
            }

            // Where this set puts you, live.
            //
            // Tiers only appeared on the profile and in the exercise detail
            // sheet, so the number that decides them was never next to them —
            // the lifter could not see that five more pounds was a new tier at
            // the moment they were choosing the weight.
            if let rank = currentRank {
                HStack(spacing: Theme.Spacing.tighter) {
                    StrengthTierBadge(tier: rank.tier, size: .small)
                    if let next = rank.nextTier, let target = rank.nextTierTarget {
                        Text("\(target.formattedWeight) for \(next.displayName)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
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
            // PR - use personal record weight and reps exactly as achieved
            if let pr = prSet, pr.weight > 0 {
                Button {
                    addSetWithValues(weight: pr.weight, reps: pr.reps)
                } label: {
                    Label("PR (\(formatWeightCompact(pr.weight)) × \(pr.reps))", systemImage: "trophy")
                }

                // PR + 5 - heavier weight, adjust reps down from PR
                let pr5Weight = pr.weight + 5
                let pr5Reps = adjustedReps(targetWeight: pr5Weight, baseWeight: pr.weight, baseReps: pr.reps)
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
                        .contentTransition(.numericText())
                        .animation(.xomSnappy, value: currentSet.weight)
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
                        .contentTransition(.numericText())
                        .animation(.xomSnappy, value: currentSet.reps)
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
        let isSkipped = currentSet.isSkipped
        return VStack(spacing: Theme.Spacing.sm) {
            Button {
                dismissKeyboard()
                if !isCompleted && !isSkipped {
                    viewModel.completeFocusedSet()
                }
            } label: {
                Text(isSkipped ? "SKIPPED" : (isCompleted ? "COMPLETED" : "DONE"))
                    .font(.title3.weight(.black))
                    .foregroundStyle(isCompleted || isSkipped ? Theme.textSecondary : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isCompleted || isSkipped ? Theme.surface : Theme.accent)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            }
            .disabled(isCompleted || isSkipped)
            .accessibilityLabel(isSkipped ? "Set skipped" : (isCompleted ? "Set completed" : "Complete set"))

            // Not every planned set gets done. Without this the only ways out
            // of a set you're not doing were to fake-complete it or delete it,
            // and an untouched set blocked the exercise from ever completing.
            Button {
                dismissKeyboard()
                Haptics.light()
                viewModel.toggleSkip(
                    exerciseIndex: viewModel.focusExerciseIndex,
                    setIndex: viewModel.focusSetIndex
                )
            } label: {
                HStack(spacing: Theme.Spacing.tight) {
                    Image(systemName: isSkipped ? "arrow.uturn.backward" : "forward.end")
                        .font(.caption.weight(.bold))
                    Text(isSkipped ? "Undo skip" : "Skip this set")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isSkipped
                ? "Puts this set back into the workout"
                : "Marks this set as not done and moves on")
        }
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

    // Rest-timer rendering lives in `RestTimerBar`, shared with list mode.
    //
    // This file used to carry two of its own: a full-screen overlay and a
    // separate minimized banner. Together with the inline card in
    // `ActiveWorkoutView` that was three renderings of one timer, which is
    // why resting looked and behaved differently depending on which view
    // the lifter happened to be in.

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
