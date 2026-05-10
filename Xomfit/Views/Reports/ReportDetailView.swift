import SwiftUI

// MARK: - ReportDetailView
//
// Detail surface for a single weekly / monthly report (#260). Presents
// the period header, three stat cards (volume / sessions / avg
// duration), top exercises, new PRs (if any), the recommendation prose,
// and a thumbs-up / thumbs-down feedback row at the bottom.
//
// On appear: marks the report as read via the view model. On feedback
// submit: writes through the view model and dismisses the view.

struct ReportDetailView: View {
    let report: UserReport
    /// Shared view model passed down from `ReportsListView` so that
    /// optimistic mutations (read state, feedback) reflect back into the
    /// list when the user pops.
    var viewModel: ReportsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var feedbackRating: Int? = nil
    @State private var feedbackText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showFeedbackForm: Bool = false

    /// Look up the latest version of this report from the view model so
    /// optimistic updates show up here too (e.g. immediately after
    /// submitting feedback).
    private var current: UserReport {
        viewModel.reports.first(where: { $0.id == report.id }) ?? report
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                statsRow
                if !current.stats.topExercises.isEmpty {
                    topExercisesSection
                }
                if !current.stats.newPRs.isEmpty {
                    newPRsSection
                }
                recommendationSection
                feedbackSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            // Mark read when the user actually opens the detail view.
            await viewModel.markRead(report)
            // Pre-seed the feedback UI from any prior submission.
            feedbackRating = current.feedbackRating
            feedbackText = current.feedbackText ?? ""
            showFeedbackForm = current.feedbackRating != nil
        }
    }

    private var navTitle: String {
        switch current.kind {
        case .weekly:  "Weekly Report"
        case .monthly: "Monthly Report"
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: current.kind == .weekly ? "calendar.badge.clock" : "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(current.kind.rawValue.capitalized)
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(periodString)
                .font(Theme.fontTitle2)
                .foregroundStyle(Theme.textPrimary)
            Text("Generated \(relativeCreatedAt)")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var periodString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let start = formatter.string(from: current.periodStart)
        let end = formatter.string(from: current.periodEnd)
        return "\(start) – \(end)"
    }

    private var relativeCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: current.createdAt, relativeTo: Date())
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            statCard(
                label: "Volume",
                value: formattedVolume(current.stats.totalVolume),
                icon: "chart.bar.fill"
            )
            statCard(
                label: "Sessions",
                value: "\(current.stats.sessionCount)",
                icon: "figure.strengthtraining.traditional"
            )
            statCard(
                label: "Avg Min",
                value: avgMinutesString,
                icon: "clock"
            )
        }
    }

    private var avgMinutesString: String {
        let value = current.stats.avgSessionMinutes
        if value <= 0 { return "0" }
        if value >= 100 { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }

    private func statCard(label: String, value: String, icon: String) -> some View {
        XomCard(padding: Theme.Spacing.md, variant: .elevated) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                }
                Text(value)
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                XomMetricLabel(label)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Top Exercises

    private var topExercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("Top Exercises")
            XomCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(current.stats.topExercises.enumerated()), id: \.offset) { index, exercise in
                        topExerciseRow(rank: index + 1, exercise: exercise)
                        if index < current.stats.topExercises.count - 1 {
                            Divider().background(Theme.hairline)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }

    private func topExerciseRow(rank: Int, exercise: UserReport.TopExercise) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(exercise.sets) set\(exercise.sets == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)

            Text(formattedVolume(exercise.volume))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(exercise.name), \(exercise.sets) sets, volume \(formattedVolume(exercise.volume))")
    }

    // MARK: - New PRs

    private var newPRsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("New PRs")
            XomCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(current.stats.newPRs.enumerated()), id: \.offset) { index, pr in
                        newPRRow(pr)
                        if index < current.stats.newPRs.count - 1 {
                            Divider().background(Theme.hairline)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }

    private func newPRRow(_ pr: UserReport.NewPR) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.prGold)
                .frame(width: 24)

            Text(pr.exercise)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 0)

            Text("\(formattedWeight(pr.weight)) × \(pr.reps)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New PR \(pr.exercise), \(formattedWeight(pr.weight)) for \(pr.reps) reps")
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("Recommendation")
            XomCard(variant: .base) {
                Text(current.recommendationText.isEmpty
                     ? "No recommendation available for this period."
                     : current.recommendationText)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("Was this helpful?")

            XomCard(variant: .base) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.md) {
                        feedbackButton(rating: 1, icon: "hand.thumbsup.fill", label: "Yes")
                        feedbackButton(rating: -1, icon: "hand.thumbsdown.fill", label: "No")
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(Theme.accent)
                        }
                    }

                    if showFeedbackForm {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            TextField(
                                "Optional comment (what worked, what didn't)",
                                text: $feedbackText,
                                axis: .vertical
                            )
                            .lineLimit(2...5)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(Theme.Spacing.md)
                            .background(Theme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
                            )

                            XomButton("Send Feedback", variant: .primary, isLoading: isSubmitting) {
                                Task { await submitFeedback() }
                            }
                            .disabled(feedbackRating == nil || isSubmitting)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackButton(rating: Int, icon: String, label: String) -> some View {
        let isSelected = feedbackRating == rating
        Button {
            Haptics.light()
            feedbackRating = rating
            showFeedbackForm = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .black : Theme.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.accent : Theme.surfaceElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(label) feedback")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func submitFeedback() async {
        guard let rating = feedbackRating, !isSubmitting else { return }
        isSubmitting = true
        await viewModel.submitFeedback(report: current, rating: rating, text: feedbackText)
        Haptics.success()
        isSubmitting = false
        dismiss()
    }

    // MARK: - Formatting Helpers

    private func formattedVolume(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", value / 1_000)
        }
        return String(Int(value.rounded()))
    }

    private func formattedWeight(_ value: Double) -> String {
        // Match plate-loaded display: drop the trailing .0 when whole.
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) lb"
        }
        return String(format: "%.1f lb", value)
    }
}
