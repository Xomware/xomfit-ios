import SwiftUI

/// Read-only sheet showing how to perform an exercise: description, form tips,
/// muscle groups, and equipment. Surfaced from the exercise picker and the
/// active workout view so users can check form mid-set.
struct ExerciseDetailSheet: View {
    let exercise: Exercise
    /// The lifter's best estimated 1RM on this exercise, when known. Drives the
    /// rank card; omitted callers simply get no rank section.
    var estimated1RM: Double?
    @Environment(\.dismiss) private var dismiss
    /// Toggles the 1RM estimator sheet from the meta row link.
    @State private var showOneRM: Bool = false
    @State private var showLifterDetails: Bool = false

    // Computed rather than stored: a private stored property would drop the
    // memberwise initializer to private and break every call site.
    private var strength: StrengthLevelService { .shared }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        rankSection
                        muscleAndEquipment
                        variationsSection
                        howToSection
                        if !exercise.tips.isEmpty {
                            tipsSection
                        }
                        // #346: Mini silhouette highlighting only the muscles
                        // this exercise hits. Non-tappable — just a visual aid.
                        miniSilhouetteSection
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

    /// Strength rank for this exercise.
    ///
    /// Hidden entirely rather than shown empty when the exercise is not
    /// weight-ranked (holds, mobility) or bodyweight is unknown — a rank card
    /// reading "Unranked" with no way to act on it is worse than no card.
    @ViewBuilder
    private var rankSection: some View {
        // Falls back to the cached best from PRService so the five existing call
        // sites get ranks without each having to look one up.
        let best = estimated1RM ?? PRService.shared.bestE1RM(for: exercise.id)
        let isRankable = StrengthStandards.profile(for: exercise.id)?.basis != LoadBasis.notRanked
            && StrengthStandards.profile(for: exercise.id) != nil

        if let rank = strength.rank(
            exerciseId: exercise.id,
            estimated1RM: best ?? 0
        ), rank.tier != .unranked || best != nil {
            StrengthRankCard(
                exerciseName: exercise.name,
                rank: rank,
                isProvisional: strength.isProvisional,
                onProvideDetails: { showLifterDetails = true }
            )
            .sheet(isPresented: $showLifterDetails) {
                LifterDetailsSheet()
            }
        } else if isRankable && !strength.canRank {
            // Without a bodyweight nothing can be ranked, so the card above
            // renders nothing — and the only way to *set* a bodyweight was a
            // button inside that card. That closed loop made strength ranks
            // unreachable for every user who had never logged a weigh-in, which
            // is to say the feature did not exist. This is the way in.
            Button {
                showLifterDetails = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "medal.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.prGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock strength ranks")
                            .font(Theme.fontBodyEmphasized)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Add your bodyweight to rank this lift Bronze through God")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showLifterDetails) {
                LifterDetailsSheet()
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

            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
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

            // Tools link — opens the 1RM estimator inline (no pre-fill; user types).
            Button {
                Haptics.selection()
                showOneRM = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.caption.weight(.semibold))
                    Text("Estimate 1RM")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.top, Theme.Spacing.tighter)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Estimate one rep max")
            .accessibilityHint("Opens the 1RM estimator")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .sheet(isPresented: $showOneRM) {
            OneRMEstimatorView()
                .presentationDetents([.large])
        }
    }

    private func metaRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(Theme.fontSubheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.Spacing.lg)
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
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
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("How To")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(exercise.description)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Full step-by-step guidance where it has been written. Exercises
            // without it fall back to the description above plus the existing
            // tips section, rather than showing generated filler.
            if let steps = ExerciseInstructionLibrary.instructions(for: exercise.id) {
                if !steps.setup.isEmpty {
                    instructionGroup("Setup", systemImage: "figure.stand", steps: steps.setup)
                }
                if !steps.execution.isEmpty {
                    instructionGroup("The Rep", systemImage: "arrow.up.arrow.down", steps: steps.execution)
                }
                if !steps.mistakes.isEmpty {
                    instructionGroup(
                        "Common Mistakes",
                        systemImage: "exclamationmark.triangle.fill",
                        steps: steps.mistakes,
                        tint: Theme.alert
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    /// One titled block of numbered steps.
    ///
    /// Mistakes get a bullet rather than a number, because they are a checklist
    /// of things to watch for, not an ordered procedure.
    private func instructionGroup(
        _ title: String,
        systemImage: String,
        steps: [String],
        tint: Color = Theme.accent
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(Theme.fontFootnote.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Text(tint == Theme.alert ? "•" : "\(index + 1)")
                            .font(Theme.fontCaption.weight(.bold).monospacedDigit())
                            .foregroundStyle(tint)
                            .frame(width: 16, alignment: .trailing)
                        Text(step)
                            .font(Theme.fontCallout)
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            .font(Theme.fontSubheadline)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, Theme.Spacing.tighter)
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

    // MARK: - Mini Silhouette (#346)

    // MARK: - Muscle highlighting

    /// Opacity applied to the prime mover, and to everything supporting it.
    static let primaryMuscleOpacity: Double = 0.9
    static let supportingMuscleOpacity: Double = 0.32

    /// Builds the silhouette's fill map: first muscle group solid, the rest
    /// washed out.
    ///
    /// `muscleGroups` is ordered prime-mover-first throughout
    /// `ExerciseDatabase` — bench press is `[.chest, .triceps, .shoulders]`,
    /// pull-ups `[.lats, .back, .biceps]`. That ordering is the only signal
    /// available; the model carries no explicit primary flag.
    ///
    /// Deliberately a static function over plain values so the weighting is
    /// testable without rendering the sheet.
    static func highlightFill(for muscleGroups: [MuscleGroup]) -> [MuscleGroup: Color] {
        var fill: [MuscleGroup: Color] = [:]
        for (index, muscle) in muscleGroups.enumerated() {
            let opacity = index == 0 ? primaryMuscleOpacity : supportingMuscleOpacity
            // Keyed assignment, not Dictionary(uniqueKeysWithValues:), which
            // traps if an exercise ever repeats a muscle group.
            fill[muscle] = Theme.accent.opacity(opacity)
        }
        return fill
    }

    /// 200x300pt silhouette highlighting only this exercise's muscles. Shows
    /// front + back side-by-side so all muscles are visible without a toggle.
    /// Non-interactive — `onMuscleTap: nil`.
    ///
    /// The prime mover is painted solid and the supporting muscles are washed
    /// out behind it. Painting all of them alike said a bench press works chest,
    /// triceps and shoulders in equal measure, which is the one thing the
    /// diagram exists to answer.
    private var miniSilhouetteSection: some View {
        let highlightedFill = Self.highlightFill(for: exercise.muscleGroups)

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Muscles Worked")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: Theme.Spacing.md) {
                miniBody(side: .front, fill: highlightedFill)
                miniBody(side: .back, fill: highlightedFill)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(muscleDiagramAccessibilityLabel)

            muscleLegend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    /// Opacity alone is easy to miss, and invisible to anyone who cannot pick
    /// the two shades apart — the legend names which muscle is which.
    @ViewBuilder
    private var muscleLegend: some View {
        if let primary = exercise.muscleGroups.first {
            let supporting = exercise.muscleGroups.dropFirst()

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                legendRow(
                    swatch: Theme.accent.opacity(0.9),
                    title: "Primary",
                    detail: primary.displayName
                )

                if !supporting.isEmpty {
                    legendRow(
                        swatch: Theme.accent.opacity(0.32),
                        title: "Supporting",
                        detail: supporting.map(\.displayName).joined(separator: ", ")
                    )
                }
            }
        }
    }

    private func legendRow(swatch: Color, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tighter) {
            Circle()
                .fill(swatch)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail)")
    }

    private var muscleDiagramAccessibilityLabel: String {
        guard let primary = exercise.muscleGroups.first else {
            return "Muscles worked diagram."
        }
        let supporting = exercise.muscleGroups.dropFirst()
        guard !supporting.isEmpty else {
            return "Muscles worked diagram. Primary: \(primary.displayName)."
        }
        return "Muscles worked diagram. Primary: \(primary.displayName). "
            + "Supporting: \(supporting.map(\.displayName).joined(separator: ", "))."
    }

    private func miniBody(side: BodySide, fill: [MuscleGroup: Color]) -> some View {
        VStack(spacing: Theme.Spacing.tighter) {
            BodySilhouetteView(
                side: side,
                fillByMuscle: fill,
                onMuscleTap: nil
            )
            .frame(width: 100, height: 200)
            Text(side.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
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
