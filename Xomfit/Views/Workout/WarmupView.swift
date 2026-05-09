import SwiftUI

/// Pre-workout stretch flow.
///
/// Shows a total countdown at the top and walks the user through ~5-7 stretches,
/// auto-advancing as each per-stretch sub-timer hits zero. Users can skip the
/// remaining time at any point and jump straight into the workout.
struct WarmupView: View {
    let stretches: [Stretch]
    /// Total warmup duration in seconds (default 6 minutes).
    let totalDuration: Int
    /// Called when the user completes or skips the warmup. The caller should
    /// dismiss this view and start the actual workout.
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var totalRemaining: Int
    @State private var stretchRemaining: Int
    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    @State private var isFinished: Bool = false

    init(stretches: [Stretch], totalDuration: Int = 360, onFinish: @escaping () -> Void) {
        self.stretches = stretches
        self.totalDuration = totalDuration
        self.onFinish = onFinish
        _totalRemaining = State(initialValue: totalDuration)
        _stretchRemaining = State(initialValue: stretches.first?.durationSeconds ?? 30)
    }

    private var currentStretch: Stretch? {
        guard currentIndex < stretches.count else { return stretches.last }
        return stretches[currentIndex]
    }

    private var totalProgress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (Double(totalRemaining) / Double(totalDuration))
    }

    private var stretchProgress: Double {
        guard let stretch = currentStretch, stretch.durationSeconds > 0 else { return 0 }
        return 1 - (Double(stretchRemaining) / Double(stretch.durationSeconds))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        totalTimerCard
                        currentStretchCard
                        upcomingList
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 100)
                }

                VStack {
                    Spacer()
                    skipButton
                }
            }
            .navigationTitle("Warmup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.light()
                        stopTimer()
                        dismiss()
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Loosen up first")
                .font(Theme.fontTitle2)
                .foregroundStyle(Theme.textPrimary)
            Text("\(stretches.count) stretches to get you ready")
                .font(Theme.fontSubheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Total timer

    private var totalTimerCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            XomMetricLabel("Total Time")

            ZStack {
                RestTimerRingView(progress: totalProgress, color: Theme.accent, lineWidth: 8)
                Text(formatTime(totalRemaining))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 140, height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total warmup time remaining: \(formatTime(totalRemaining))")
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Current stretch

    @ViewBuilder
    private var currentStretchCard: some View {
        if let stretch = currentStretch {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: stretch.icon)
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now: \(stretch.name)")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(muscleGroupSummary(stretch.targetMuscleGroups))
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    ZStack {
                        RestTimerRingView(progress: stretchProgress, color: Theme.accent, lineWidth: 4)
                        Text("\(stretchRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(width: 56, height: 56)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stretchRemaining) seconds left on this stretch")
                }

                Text(stretch.description)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Haptics.light()
                        advanceToNextStretch()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.fill")
                            Text("Next stretch")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityLabel("Skip to next stretch")
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        } else {
            EmptyView()
        }
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingList: some View {
        if currentIndex + 1 < stretches.count {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Up next")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)

                ForEach(Array(stretches.enumerated()), id: \.element.id) { index, stretch in
                    if index > currentIndex {
                        upcomingRow(index: index, stretch: stretch)
                    }
                }
            }
        }
    }

    private func upcomingRow(index: Int, stretch: Stretch) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))

            Text(stretch.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text("\(stretch.durationSeconds)s")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Up next: \(stretch.name), \(stretch.durationSeconds) seconds")
    }

    // MARK: - Skip button

    private var skipButton: some View {
        Button {
            Haptics.medium()
            finish()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Skip to workout")
            }
        }
        .buttonStyle(AccentButtonStyle())
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .accessibilityLabel("Skip remaining warmup and start workout")
    }

    // MARK: - Timer

    private func startTimer() {
        // Bail early if there are no stretches at all.
        guard !stretches.isEmpty else {
            finish()
            return
        }
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isFinished else { return }

        if totalRemaining > 0 {
            totalRemaining -= 1
        }

        if stretchRemaining > 0 {
            stretchRemaining -= 1
        }

        // Move to next stretch when this one expires.
        if stretchRemaining <= 0 {
            advanceToNextStretch()
        }

        // Total timer hit zero — wrap up and start the workout.
        if totalRemaining <= 0 {
            finish()
        }
    }

    private func advanceToNextStretch() {
        let nextIndex = currentIndex + 1
        if nextIndex < stretches.count {
            currentIndex = nextIndex
            stretchRemaining = stretches[nextIndex].durationSeconds
            Haptics.light()
        } else {
            // No more stretches but the total timer still has time — hold the last stretch
            // until the total timer expires so we don't snap to "Done" too early.
            stretchRemaining = max(totalRemaining, 0)
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        stopTimer()
        Haptics.success()
        onFinish()
        dismiss()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func muscleGroupSummary(_ groups: [MuscleGroup]) -> String {
        let names = groups.prefix(3).map { $0.displayName }
        return names.joined(separator: " · ")
    }
}

// MARK: - Preview

#Preview {
    WarmupView(
        stretches: StretchDatabase.defaultRoutine(target: 360),
        totalDuration: 360,
        onFinish: {}
    )
}
