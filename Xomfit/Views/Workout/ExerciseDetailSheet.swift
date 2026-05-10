import SwiftUI

/// Read-only sheet showing how to perform an exercise: description, form tips,
/// muscle groups, and equipment. Surfaced from the exercise picker and the
/// active workout view so users can check form mid-set.
struct ExerciseDetailSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        muscleAndEquipment
                        variationsSection
                        howToSection
                        if !exercise.tips.isEmpty {
                            tipsSection
                        }
                        if exercise.supportsUnilateral {
                            unilateralNote
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle(exercise.name)
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

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: exercise.icon)
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .background(Theme.accentMuted)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(Theme.fontTitle2)
                    .foregroundStyle(Theme.textPrimary)
                Text(exercise.category.displayName)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var muscleAndEquipment: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            metaRow(label: "Equipment", value: exercise.equipment.displayName, icon: exercise.equipment.icon)
            metaRow(
                label: exercise.muscleGroups.count > 1 ? "Muscles" : "Muscle",
                value: exercise.muscleGroups.map(\.displayName).joined(separator: ", "),
                icon: exercise.muscleGroups.first?.icon ?? "figure.strengthtraining.traditional"
            )
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func metaRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
    }

    /// Optional grips / attachments / positions chip rows when the exercise supports variations.
    @ViewBuilder
    private var variationsSection: some View {
        let grips = exercise.supportedGrips ?? []
        let attachments = exercise.supportedAttachments ?? []
        let positions = exercise.supportedPositions ?? []

        if !grips.isEmpty || !attachments.isEmpty || !positions.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Variations")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)

                if !grips.isEmpty {
                    chipRow(
                        label: "Grips",
                        icon: "hand.raised.fill",
                        chips: grips.map(\.displayName)
                    )
                }
                if !attachments.isEmpty {
                    chipRow(
                        label: "Attachments",
                        icon: "link",
                        chips: attachments.map(\.displayName)
                    )
                }
                if !positions.isEmpty {
                    chipRow(
                        label: "Positions",
                        icon: "figure.strengthtraining.traditional",
                        chips: positions.map(\.displayName)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
    }

    private func chipRow(label: String, icon: String, chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(label)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        XomBadge(chip, variant: .secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(chips.joined(separator: ", "))")
    }

    private var howToSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("How To")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(exercise.description)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Form Tips")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(exercise.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                        Text(tip)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var unilateralNote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("Can be performed one side at a time. Toggle laterality from the exercise config.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.accentMuted)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    ExerciseDetailSheet(exercise: Exercise.benchPress)
        .preferredColorScheme(.dark)
}
