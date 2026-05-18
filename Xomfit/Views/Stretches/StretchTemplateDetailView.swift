import SwiftUI

/// Detail view for a curated `StretchTemplate` (#388).
///
/// Shows the template's stretches in order with a "Start Stretching" CTA that
/// presents the guided runner as a full-screen cover. Tapping a row opens the
/// existing `StretchDetailSheet` so the user can read the long description.
struct StretchTemplateDetailView: View {
    let template: StretchTemplate

    @State private var stretchForDetail: Stretch?
    @State private var showRunner = false

    private var stretches: [Stretch] { template.stretches }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        headerCard
                        listSection
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 140)
                }

                bottomBar
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $stretchForDetail) { stretch in
            StretchDetailSheet(stretch: stretch)
        }
        .fullScreenCover(isPresented: $showRunner) {
            GuidedStretchRunnerView(
                stretches: stretches,
                templateName: template.name
            )
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: template.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: Theme.Radius.md))

                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text(template.name)
                        .font(Theme.fontTitle2)
                        .foregroundStyle(Theme.textPrimary)
                    Text(template.category.displayName)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(template.description)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.md) {
                metric(icon: "clock.fill", label: template.totalDurationLabel)
                metric(icon: "list.bullet", label: "\(stretches.count) stretches")
            }
            .accessibilityElement(children: .combine)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func metric(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: Theme.Radius.xs))
    }

    // MARK: - Stretch List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            XomMetricLabel("In This Sequence")

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(stretches.enumerated()), id: \.element.id) { index, stretch in
                    Button {
                        Haptics.selection()
                        stretchForDetail = stretch
                    } label: {
                        row(index: index, stretch: stretch)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("Stretch \(index + 1): \(stretch.name), \(stretch.durationSeconds) seconds")
                    .accessibilityHint("Opens stretch details")
                }
            }
        }
    }

    private func row(index: Int, stretch: Stretch) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(stretch.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(stretch.description)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Text("\(stretch.durationSeconds)s")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .contentShape(Rectangle())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.medium()
                showRunner = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start Stretching")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .accessibilityLabel("Start guided stretching sequence")
        }
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        StretchTemplateDetailView(template: StretchTemplate.curated[0])
    }
    .preferredColorScheme(.dark)
}
#endif
