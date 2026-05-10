import SwiftUI

/// Read-only sheet showing how to perform a warmup stretch: description,
/// hold time, and the muscle groups it loosens up. Mirrors `ExerciseDetailSheet`
/// so users can tap a stretch in the warmup preview to see what they're about to do.
struct StretchDetailSheet: View {
    let stretch: Stretch
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        metaSection
                        muscleSection
                        howToSection
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle(stretch.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: stretch.icon)
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .background(Theme.accentMuted)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text(stretch.name)
                    .font(Theme.fontTitle2)
                    .foregroundStyle(Theme.textPrimary)
                Text("Warmup stretch")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Meta (hold time)

    private var metaSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "timer")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hold Time")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                Text(formatDuration(stretch.durationSeconds))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Targeted muscles

    @ViewBuilder
    private var muscleSection: some View {
        if !stretch.targetMuscleGroups.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(stretch.targetMuscleGroups.count > 1 ? "Targets" : "Target")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(stretch.targetMuscleGroups, id: \.self) { mg in
                            XomBadge(mg.displayName, icon: mg.icon, color: Theme.accent, variant: .display)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - How to

    private var howToSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("How To")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(stretch.description)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        if s >= 60 {
            let mins = s / 60
            let secs = s % 60
            if secs == 0 { return "\(mins) min" }
            return "\(mins)m \(secs)s"
        }
        return "\(s) sec"
    }
}

#Preview {
    StretchDetailSheet(stretch: StretchDatabase.all[0])
        .preferredColorScheme(.dark)
}
