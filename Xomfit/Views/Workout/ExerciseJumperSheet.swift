import SwiftUI

/// Bottom-sheet exercise jumper for mid-workout switching (#253).
///
/// Lists every exercise in the active workout with completion state and
/// per-set dots. Tapping a row jumps focus and dismisses the sheet, then
/// hands the picked index back to the parent via `onJump` so list mode can
/// scroll to the corresponding card.
///
/// Distinct from the post-set transition card and the focus-mode entry
/// picker — this sheet is reachable any time during the workout via the
/// persistent current-exercise pill.
struct ExerciseJumperSheet: View {
    let viewModel: WorkoutLoggerViewModel
    /// Called with the picked index after the VM jump completes. Parent uses
    /// this to scroll the list-mode `ScrollViewReader` to the card.
    var onJump: (Int) -> Void
    /// Called when the user taps the toolbar `+` button. Parent should dismiss
    /// this sheet and present the existing exercise picker. Optional so older
    /// call sites without an add-exercise integration keep compiling.
    var onAddExercise: (() -> Void)? = nil
    /// Called when the user taps the toolbar reorder button. Parent should
    /// dismiss this sheet and present the reorder sheet. Optional for back-compat.
    var onReorder: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var pendingRemovalIndex: Int?
    @State private var showRemoveConfirm = false
    @State private var swipeResetCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { idx, exercise in
                            row(idx: idx, exercise: exercise)
                                .swipeToDelete(
                                    accessibilityActionName: "Remove \(exercise.exercise.name) from workout"
                                ) {
                                    if viewModel.hasLoggedSets(at: idx) {
                                        pendingRemovalIndex = idx
                                        showRemoveConfirm = true
                                    } else {
                                        Haptics.warning()
                                        viewModel.removeExercise(at: idx)
                                    }
                                }
                                // The swipe row slides itself off-screen before
                                // calling back; a cancelled confirm rebuilds it.
                                .id("\(exercise.id)-\(swipeResetCount)")
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .confirmationDialog(
                "Remove Exercise?",
                isPresented: $showRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    guard let idx = pendingRemovalIndex else { return }
                    Haptics.warning()
                    viewModel.removeExercise(at: idx)
                    pendingRemovalIndex = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its logged sets will be removed from this workout.")
            }
            // Covers Cancel and tapping outside alike: anything that closes the
            // dialog without removing puts the swiped row back.
            .onChange(of: showRemoveConfirm) { _, isShown in
                guard !isShown, pendingRemovalIndex != nil else { return }
                pendingRemovalIndex = nil
                swipeResetCount += 1
            }
            .navigationTitle("Switch Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                // Trailing controls — reorder + add. Each dismisses the sheet
                // first so the parent can present its own sheet without a
                // sheet-on-sheet stack. Rendered only when their callback is
                // wired (back-compat for call sites that don't route them).
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let onReorder {
                        Button {
                            Haptics.light()
                            dismiss()
                            // Defer so this sheet finishes dismissing before the
                            // reorder sheet slides up on top of the parent.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onReorder()
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Reorder exercises")
                        .accessibilityHint("Opens a list where you can drag exercises into a new order")
                    }

                    if let onAddExercise {
                        Button {
                            Haptics.light()
                            dismiss()
                            // Defer so the dismissal animation completes before
                            // the picker slides up on top of the parent.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onAddExercise()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Add exercise to workout")
                        .accessibilityHint("Opens the exercise picker")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(idx: Int, exercise: WorkoutExercise) -> some View {
        let allComplete = !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != Date.distantPast }
        let isCurrent = idx == viewModel.focusExerciseIndex
        let completedCount = exercise.sets.filter { $0.completedAt != Date.distantPast }.count
        let totalCount = exercise.sets.count

        Button {
            Haptics.selection()
            viewModel.jumpToExercise(index: idx)
            onJump(idx)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Leading status icon
                Image(systemName: leadingIconName(allComplete: allComplete, completedCount: completedCount))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(leadingIconColor(allComplete: allComplete, completedCount: completedCount))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(exercise.exercise.name)
                            .font(Theme.fontBodyEmphasized)
                            .foregroundStyle(allComplete ? Theme.textSecondary : Theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if isCurrent {
                            Text("Current")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, Theme.Spacing.tighter)
                                .background(Theme.accent)
                                .clipShape(.capsule)
                        }
                    }

                    HStack(spacing: 6) {
                        // Per-set dots
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIdx, set in
                            let setDone = set.completedAt != Date.distantPast
                            Circle()
                                .strokeBorder(setDone ? Color.clear : Theme.textSecondary.opacity(0.6), lineWidth: 1)
                                .background(
                                    Circle().fill(setDone ? Theme.accent : Color.clear)
                                )
                                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                                .accessibilityHidden(true)
                                .id(setIdx)
                        }

                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.leading, Theme.Spacing.tight)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minHeight: 56)
            .background(rowBackground(isCurrent: isCurrent, allComplete: allComplete))
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(isCurrent ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(
            name: exercise.exercise.name,
            completed: completedCount,
            total: totalCount,
            isCurrent: isCurrent,
            allComplete: allComplete
        ))
        .accessibilityHint("Switches focus to this exercise")
    }

    // MARK: - Styling helpers

    private func leadingIconName(allComplete: Bool, completedCount: Int) -> String {
        if allComplete { return "checkmark.circle.fill" }
        if completedCount > 0 { return "circle.lefthalf.filled" }
        return "circle"
    }

    private func leadingIconColor(allComplete: Bool, completedCount: Int) -> Color {
        if allComplete { return Theme.accent }
        if completedCount > 0 { return Theme.accent }
        return Theme.textSecondary
    }

    private func rowBackground(isCurrent: Bool, allComplete: Bool) -> Color {
        if isCurrent { return Theme.accent.opacity(0.10) }
        if allComplete { return Theme.surface.opacity(0.5) }
        return Theme.surface
    }

    private func accessibilityLabel(name: String, completed: Int, total: Int, isCurrent: Bool, allComplete: Bool) -> String {
        var parts: [String] = [name]
        if isCurrent { parts.append("current exercise") }
        if allComplete {
            parts.append("all \(total) sets complete")
        } else {
            parts.append("\(completed) of \(total) sets complete")
        }
        return parts.joined(separator: ", ")
    }
}
