import SwiftUI

/// Pre-workout stretch flow.
///
/// Two phases:
/// 1. Preview — vertical list of suggested stretches with names, durations, and
///    target-muscle captions. User can tap a row for the full stretch detail,
///    hit "Start Warmup" to begin the timer, or "Skip" to jump straight to the
///    workout.
/// 2. Timer — total countdown at the top, walks the user through each stretch
///    with a per-stretch sub-timer. Auto-advances; user can skip remaining time
///    at any point.
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
    @State private var hasStarted: Bool = false
    @State private var stretchForDetail: Stretch?

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

    /// Sum of per-stretch hold times (clamped to the warmup budget).
    private var estimatedTotalDuration: Int {
        let summed = stretches.reduce(0) { $0 + $1.durationSeconds }
        return min(summed, max(totalDuration, summed))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if hasStarted {
                    timerContent
                } else {
                    previewContent
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
            .onDisappear {
                stopTimer()
            }
            .sheet(item: $stretchForDetail) { stretch in
                StretchDetailSheet(stretch: stretch)
            }
        }
    }

    // MARK: - Preview

    private var previewContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    previewHeader
                    previewList
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, 120)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    Haptics.medium()
                    beginTimer()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Start Warmup")
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .accessibilityLabel("Start warmup timer")

                Button {
                    Haptics.light()
                    finish()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "forward.fill")
                        Text("Skip")
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityLabel("Skip warmup and start workout")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Theme.background.opacity(0), Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false),
                alignment: .bottom
            )
        }
    }

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warmup")
                .font(Theme.fontTitle2)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text("\(stretches.count) stretches · \(formatTime(estimatedTotalDuration))")
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text("Tap a stretch to see how it's done.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var previewList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(stretches.enumerated()), id: \.element.id) { index, stretch in
                Button {
                    Haptics.selection()
                    stretchForDetail = stretch
                } label: {
                    previewRow(index: index, stretch: stretch)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("\(stretch.name), \(stretch.durationSeconds) seconds, \(muscleGroupSummary(stretch.targetMuscleGroups))")
                .accessibilityHint("Opens stretch details")
            }
        }
    }

    private func previewRow(index: Int, stretch: Stretch) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stretch.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(stretch.durationSeconds)s")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(muscleGroupSummary(stretch.targetMuscleGroups))
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .contentShape(Rectangle())
    }

    // MARK: - Timer

    private var timerContent: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    timerHeader
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
    }

    private var timerHeader: some View {
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
                        Haptics.selection()
                        stretchForDetail = stretch
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text("Details")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show stretch details")

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

    // MARK: - Timer control

    private func beginTimer() {
        guard !hasStarted else { return }
        hasStarted = true
        startTimer()
    }

    private func startTimer() {
        // Bail early if there are no stretches at all.
        guard !stretches.isEmpty else {
            finish()
            return
        }
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
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
