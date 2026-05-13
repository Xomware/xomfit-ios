import SwiftUI

/// Simplified runner for `.timedCircuit` workouts (#370). No per-set reps or
/// weight — just a countdown ring, the current exercise, and a tap-to-advance
/// rotation. Designed for "do X for N minutes" prompts like ab circuits.
///
/// Behaviour:
/// - Big countdown ring up top showing time remaining toward `durationGoalMinutes`.
/// - The active exercise is named in the center with a check pip for the
///   current round.
/// - Exercises auto-advance every `autoAdvanceSeconds` (30s by default) so the
///   user can keep their hands free, but a "Next" button supports manual cycling.
/// - "Done" finishes the workout, saving however many rounds the user actually
///   marked complete (`WorkoutLoggerViewModel.circuitCompletedRounds`).
struct TimedCircuitView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// One-second tick driving the ring + auto-advance.
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// Seconds the current exercise has been on-screen. Resets on advance.
    @State private var secondsOnCurrent: Int = 0
    /// True while the finish flow is in-flight (saves, dismiss).
    @State private var isFinishing = false
    @State private var showDiscardAlert = false
    @State private var timeUpHapticFired = false

    /// How long each exercise holds before auto-advancing. Mirrors the issue's
    /// "every 30s OR manual tap" requirement.
    private let autoAdvanceSeconds = 30

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    headerBar

                    Spacer(minLength: 0)

                    countdownRing

                    exerciseCard

                    Spacer(minLength: 0)

                    controlsBar
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("End Circuit?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.discardWorkout()
                    dismiss()
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your progress so far will be lost.")
            }
        }
        .onReceive(timer) { _ in
            tick()
        }
        .onChange(of: viewModel.circuitExerciseIndex) { _, _ in
            secondsOnCurrent = 0
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.warning()
                showDiscardAlert = true
            } label: {
                Text("Discard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.destructive)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Discard circuit workout")

            Spacer()

            VStack(spacing: Theme.Spacing.tighter) {
                Text(viewModel.workoutName.isEmpty ? "Timed Circuit" : viewModel.workoutName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(roundLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Button {
                Haptics.success()
                finish()
            } label: {
                Text(isFinishing ? "" : "Done")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(minWidth: 60, minHeight: 32)
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        if isFinishing {
                            ProgressView()
                                .tint(.black)
                        }
                    }
            }
            .disabled(isFinishing)
            .accessibilityLabel("Finish circuit and save")
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Countdown Ring

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.surface, lineWidth: 14)

            Circle()
                .trim(from: 0, to: max(0.001, 1 - viewModel.circuitProgress))
                .stroke(
                    ringTint,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: viewModel.circuitProgress)

            VStack(spacing: Theme.Spacing.tighter) {
                Text(timeRemainingString)
                    .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityLabel(accessibilityTimeLabel)
                Text("remaining")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityElement(children: .combine)
    }

    private var ringTint: Color {
        viewModel.circuitTimeUp ? Theme.accent : Theme.accent
    }

    private var timeRemainingString: String {
        let total = viewModel.circuitRemainingSeconds
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var accessibilityTimeLabel: String {
        let total = viewModel.circuitRemainingSeconds
        let mins = total / 60
        let secs = total % 60
        if mins > 0 && secs > 0 {
            return "\(mins) minute\(mins == 1 ? "" : "s") and \(secs) second\(secs == 1 ? "" : "s") remaining"
        }
        if mins > 0 {
            return "\(mins) minute\(mins == 1 ? "" : "s") remaining"
        }
        return "\(secs) second\(secs == 1 ? "" : "s") remaining"
    }

    // MARK: - Exercise Card

    private var exerciseCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let exercise = viewModel.currentCircuitExercise {
                Text(exercise.exercise.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if !exercise.exercise.muscleGroups.isEmpty {
                    HStack(spacing: Theme.Spacing.tight) {
                        ForEach(exercise.exercise.muscleGroups.prefix(3), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, Theme.Spacing.tighter)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(.capsule)
                        }
                    }
                }

                roundCheckmarkButton
            } else {
                Text("No exercises queued")
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var roundCheckmarkButton: some View {
        Button {
            Haptics.medium()
            viewModel.toggleCurrentCircuitRoundComplete()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: viewModel.currentCircuitRoundIsComplete
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(Theme.fontTitle3)
                Text(viewModel.currentCircuitRoundIsComplete
                     ? "Round \(viewModel.circuitRound + 1) complete"
                     : "Mark round \(viewModel.circuitRound + 1) complete")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(viewModel.currentCircuitRoundIsComplete ? Theme.accent : Theme.textSecondary)
            .frame(minHeight: 44)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(viewModel.currentCircuitRoundIsComplete
                          ? Theme.accent.opacity(0.15)
                          : Theme.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.currentCircuitRoundIsComplete
                            ? "Unmark round \(viewModel.circuitRound + 1)"
                            : "Mark round \(viewModel.circuitRound + 1) complete")
    }

    // MARK: - Controls

    private var controlsBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Auto-advance countdown hint
            if !viewModel.circuitTimeUp, viewModel.exercises.count > 1 {
                let until = max(0, autoAdvanceSeconds - secondsOnCurrent)
                Text("Next exercise in \(until)s")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }

            HStack(spacing: Theme.Spacing.sm) {
                XomButton(
                    "Next",
                    variant: .secondary,
                    icon: "arrow.right"
                ) {
                    Haptics.selection()
                    secondsOnCurrent = 0
                    viewModel.advanceCircuitExercise()
                }
                .disabled(viewModel.exercises.count < 2)

                XomButton(
                    "Done",
                    variant: .primary,
                    icon: "checkmark",
                    isLoading: isFinishing
                ) {
                    Haptics.success()
                    finish()
                }
            }
        }
    }

    // MARK: - Derived

    private var roundLabel: String {
        let round = viewModel.circuitRound + 1
        if viewModel.exercises.isEmpty {
            return "Round \(round)"
        }
        let pos = viewModel.circuitExerciseIndex + 1
        return "Round \(round) • \(pos) of \(viewModel.exercises.count)"
    }

    // MARK: - Tick

    private func tick() {
        viewModel.tickLiveActivity()

        guard !viewModel.circuitTimeUp else {
            if !timeUpHapticFired {
                timeUpHapticFired = true
                Haptics.success()
            }
            return
        }

        secondsOnCurrent += 1
        if secondsOnCurrent >= autoAdvanceSeconds && viewModel.exercises.count > 1 {
            secondsOnCurrent = 0
            Haptics.selection()
            viewModel.advanceCircuitExercise()
        }
    }

    // MARK: - Actions

    private func finish() {
        guard !isFinishing else { return }
        guard let user = authService.currentUser else {
            // No auth — just dismiss locally without saving.
            viewModel.discardWorkout()
            dismiss()
            return
        }
        let userId = user.id.uuidString.lowercased()
        isFinishing = true
        Task {
            await viewModel.finishWorkout(userId: userId, notes: nil, photoURLs: nil)
            isFinishing = false
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}
