import SwiftUI

// MARK: - StretchesView
//
// Top-level Stretches destination reached from the hamburger drawer (#388).
// Two sections, top-to-bottom:
//   1. Templates carousel — curated stretching sequences.
//   2. All Stretches — sectioned by `StretchCategory` (Full Body / Upper / Lower / Hips / Core).
//
// Tapping a template pushes `StretchTemplateDetailView`. Tapping an individual
// stretch surfaces the existing `StretchDetailSheet`.

struct StretchesView: View {
    @State private var stretchForDetail: Stretch?
    /// Fullscreen runner presented when an agent passes
    /// `XOMFIT_PUSH_STRETCH_TEMPLATE=<id>` (DEBUG-only). Lets screenshot
    /// flows reach the runner without scripted taps.
    @State private var debugRunnerTemplate: StretchTemplate?
    /// Detail sheet presented when an agent passes
    /// `XOMFIT_OPEN_STRETCH_TEMPLATE=<id>` (DEBUG-only). Same trick as above,
    /// but stops at the detail view instead of the runner.
    @State private var debugDetailTemplate: StretchTemplate?

    private let templates: [StretchTemplate] = StretchTemplate.curated
    private let sections: [(category: StretchCategory, stretches: [Stretch])] =
        StretchDatabase.grouped.filter { !$0.stretches.isEmpty }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    templatesSection
                    allStretchesSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationDestination(for: StretchTemplate.self) { template in
            StretchTemplateDetailView(template: template)
        }
        .sheet(item: $stretchForDetail) { stretch in
            StretchDetailSheet(stretch: stretch)
        }
        .sheet(item: $debugDetailTemplate) { template in
            // Wrap in a NavigationStack so the detail view's toolbar + push
            // surface render correctly inside the sheet.
            NavigationStack {
                StretchTemplateDetailView(template: template)
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $debugRunnerTemplate) { template in
            GuidedStretchRunnerView(
                stretches: template.stretches,
                templateName: template.name
            )
        }
        #if DEBUG
        .task {
            // Agent UI verification (#388): when XOMFIT_OPEN_STRETCH_TEMPLATE
            // is set, present that template's detail as a sheet shortly after
            // first render. When XOMFIT_PUSH_STRETCH_TEMPLATE is set, jump
            // straight to the guided runner. Compiles out of Release builds.
            let env = ProcessInfo.processInfo.environment
            if let id = env["XOMFIT_OPEN_STRETCH_TEMPLATE"],
               let tpl = templates.first(where: { $0.id == id }) {
                try? await Task.sleep(for: .seconds(1))
                debugDetailTemplate = tpl
            }
            if let id = env["XOMFIT_PUSH_STRETCH_TEMPLATE"],
               let tpl = templates.first(where: { $0.id == id }) {
                try? await Task.sleep(for: .seconds(1))
                debugRunnerTemplate = tpl
            }
        }
        #endif
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                XomMetricLabel("Templates")
                Spacer()
                Text("\(templates.count)")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
            Text("Guided stretching sequences")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            StretchTemplateCard(template: template)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel("\(template.name), \(template.stretches.count) stretches, \(template.totalDurationLabel)")
                        .accessibilityHint("Opens template details")
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .padding(.horizontal, -Theme.Spacing.md)
            .padding(.leading, Theme.Spacing.md)
        }
    }

    // MARK: - All Stretches

    private var allStretchesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                XomMetricLabel("All Stretches")
                Spacer()
                Text("\(StretchDatabase.all.count)")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }

            ForEach(sections, id: \.category) { section in
                stretchSection(category: section.category, stretches: section.stretches)
            }
        }
    }

    private func stretchSection(category: StretchCategory, stretches: [Stretch]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: Theme.Radius.xs))
                Text(category.displayName)
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(stretches.count)")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(stretches) { stretch in
                    Button {
                        Haptics.selection()
                        stretchForDetail = stretch
                    } label: {
                        StretchRow(stretch: stretch)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(stretch.name), \(stretch.durationSeconds) seconds")
                    .accessibilityHint("Opens stretch details")
                }
            }
        }
    }
}

// MARK: - Template Card

private struct StretchTemplateCard: View {
    let template: StretchTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: template.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                Spacer(minLength: 0)
            }

            Text(template.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(template.description)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                Text(template.totalDurationLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(template.stretches.count) stretches")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 240, height: 170, alignment: .topLeading)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }
}

// MARK: - Stretch Row

private struct StretchRow: View {
    let stretch: Stretch

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: stretch.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentMuted)
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(stretch.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(muscleGroupSummary(stretch.targetMuscleGroups))
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(stretch.durationSeconds)s")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(minHeight: 56)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .contentShape(Rectangle())
    }

    private func muscleGroupSummary(_ groups: [MuscleGroup]) -> String {
        let names = groups.prefix(3).map { $0.displayName }
        return names.joined(separator: " · ")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        StretchesView()
    }
    .preferredColorScheme(.dark)
}
#endif
