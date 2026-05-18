import SwiftUI

// MARK: - GuidedStretchRunnerView
//
// Full-screen guided stretching session for a curated template (#388, polished
// in #398). Shows the current stretch, a per-stretch countdown ring, a top
// progress bar, and skip/back/pause controls. The countdown keeps going past
// zero into negative territory so the user can hold a stretch as long as they
// want — the runner does NOT auto-advance; Skip / Done are manual. Mirrors
// the workout Live Activity via `XomfitWidgetAttributes` so the current
// stretch + countdown surface in the Dynamic Island / on the lock screen.

struct GuidedStretchRunnerView: View {
    let stretches: [Stretch]
    let templateName: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GuidedStretchRunnerViewModel

    init(stretches: [Stretch], templateName: String) {
        self.stretches = stretches
        self.templateName = templateName
        _viewModel = State(
            initialValue: GuidedStretchRunnerViewModel(
                stretches: stretches,
                templateName: templateName
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.isFinished {
                    finishedContent
                } else {
                    runningContent
                }
            }
            .navigationTitle(templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Haptics.light()
                        viewModel.teardown()
                        dismiss()
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Close stretching sequence")
                }
            }
            .onAppear {
                viewModel.start()
                #if DEBUG
                // Agent screenshot helper: jump-start the runner into the
                // negative-countdown ("overtime") state so the red styling can
                // be captured from a cold launch.
                let env = ProcessInfo.processInfo.environment
                if let raw = env["XOMFIT_STRETCH_FORCE_OVERTIME"], let secs = Int(raw) {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        // Tick the runner forward enough to push `secondsRemaining`
                        // to roughly `-secs`. The view model owns the timer so
                        // we use its public skip path to enter overtime.
                        let target = viewModel.currentStretch?.durationSeconds ?? 0
                        let tickCount = target + secs
                        for _ in 0..<tickCount {
                            viewModel.debugTickForOvertimeScreenshot()
                        }
                    }
                }
                #endif
            }
            .onDisappear {
                viewModel.teardown()
            }
        }
    }

    // MARK: - Running

    private var runningContent: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    counterRow
                    timerCard
                    if let stretch = viewModel.currentStretch {
                        descriptionCard(for: stretch)
                        upcomingList
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, 140)
            }

            controlsBar
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let progress = viewModel.overallProgress
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.surfaceElevated)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent)
                    .frame(width: max(0, proxy.size.width * progress))
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Sequence progress")
        .accessibilityValue("\(Int(viewModel.overallProgress * 100)) percent complete")
    }

    private var counterRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            XomMetricLabel("Stretch")
            Text("\(min(viewModel.currentIndex + 1, viewModel.totalCount)) of \(viewModel.totalCount)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if !viewModel.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.caption2.weight(.semibold))
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.alert)
            }
        }
    }

    private var timerCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let stretch = viewModel.currentStretch {
                Text(stretch.name)
                    .font(Theme.fontTitle2)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                ZStack {
                    // Ring color also flips red once the user holds past the
                    // recommended time (#398). Progress stays clamped at 1.
                    RestTimerRingView(
                        progress: viewModel.stretchProgress,
                        color: viewModel.isOvertime ? Theme.destructive : Theme.accent,
                        lineWidth: 10
                    )
                    VStack(spacing: 2) {
                        Text("\(viewModel.secondsRemaining)")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(viewModel.isOvertime ? Theme.destructive : Theme.textPrimary)
                        Text(viewModel.isOvertime ? "over · tap skip" : "seconds")
                            .font(Theme.fontCaption)
                            .foregroundStyle(viewModel.isOvertime ? Theme.destructive : Theme.textSecondary)
                    }
                }
                .frame(width: 200, height: 200)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    viewModel.isOvertime
                        ? "\(abs(viewModel.secondsRemaining)) seconds past target on \(stretch.name). Tap skip when ready."
                        : "\(viewModel.secondsRemaining) seconds remaining on \(stretch.name)"
                )
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func descriptionCard(for stretch: Stretch) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("How To")
            Text(stretch.description)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            if !stretch.targetMuscleGroups.isEmpty {
                Divider().overlay(Theme.hairline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(stretch.targetMuscleGroups, id: \.self) { mg in
                            XomBadge(mg.displayName, icon: mg.icon, color: Theme.accent, variant: .display)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var upcomingList: some View {
        let upcoming = upcomingStretches
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                XomMetricLabel("Up Next")
                ForEach(Array(upcoming.enumerated()), id: \.element.id) { offset, stretch in
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(viewModel.currentIndex + offset + 2)")
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Theme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 6))
                        Text(stretch.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
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
            }
        }
    }

    private var upcomingStretches: [Stretch] {
        let start = viewModel.currentIndex + 1
        guard start < viewModel.stretches.count else { return [] }
        return Array(viewModel.stretches[start...].prefix(3))
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            controlButton(icon: "backward.fill", label: "Back") {
                viewModel.skipBack()
            }
            .accessibilityLabel("Previous stretch")

            playPauseButton

            controlButton(icon: "forward.fill", label: "Skip") {
                viewModel.skipForward()
            }
            .accessibilityLabel("Next stretch")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(PressableCardStyle())
    }

    private var playPauseButton: some View {
        Button {
            viewModel.togglePause()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                Text(viewModel.isRunning ? "Pause" : "Play")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.accent)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(viewModel.isRunning ? "Pause sequence" : "Resume sequence")
    }

    // MARK: - Finished

    private var finishedContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentMuted)
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Nice work")
                    .font(Theme.fontTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(stretches.count) stretches in \(viewModel.elapsedSummary).")
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                Haptics.medium()
                viewModel.teardown()
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .accessibilityLabel("Finish and close")
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

#if DEBUG
#Preview("Running") {
    GuidedStretchRunnerView(
        stretches: StretchTemplate.curated[0].stretches,
        templateName: StretchTemplate.curated[0].name
    )
    .preferredColorScheme(.dark)
}
#endif
