import SwiftUI

/// Config screen for the offline workout generator.
///
/// Two ways to fill the same underlying `Set<MuscleGroup>`:
/// 1. Push / Pull / Legs / Core split chips (multi-select via Seam-3 reverse map).
/// 2. The full 13-muscle grid (individual toggles).
/// Plus a time-budget slider and a set-count stepper, then a "Generate" CTA.
///
/// Framed as instant / offline / no-AI to read as distinct from the AI Coach.
/// Binds to `WorkoutGeneratorViewModel` only — never calls services or the engine.
struct WorkoutGeneratorConfigView: View {
    @Bindable var viewModel: WorkoutGeneratorViewModel
    let userId: String
    /// Start the generated workout via the host's warmup gate.
    let onStart: (WorkoutTemplate) -> Void
    /// Called after Save so the host can refresh the templates list.
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showPreview = false

    private let gridColumns = [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        splitSection
                        muscleSection
                        timeSection
                        setsSection
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 96)
                }

                generateBar
            }
            .navigationTitle("Generate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                WorkoutGeneratorPreviewView(
                    viewModel: viewModel,
                    userId: userId,
                    onStart: { template in
                        dismiss()
                        onStart(template)
                    },
                    onSaved: {
                        onSaved()
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Header (AI-coach distinction)

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "dice.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("Instant · No AI · Offline")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text("Pick what you want to hit. We'll build a runnable workout on-device — no chat, no waiting.")
                .font(Theme.fontFootnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Split chips

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Quick pick", subtitle: "Tap a split to select its muscles")
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TrainingRegion.allCases) { region in
                    chip(
                        title: region.displayName,
                        icon: region.icon,
                        isOn: viewModel.isRegionSelected(region)
                    ) {
                        Haptics.light()
                        viewModel.toggleRegion(region)
                    }
                }
            }
        }
    }

    // MARK: - Muscle grid

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Muscles", subtitle: "Fine-tune individual muscles")
            LazyVGrid(columns: gridColumns, spacing: Theme.Spacing.sm) {
                ForEach(MuscleGroup.allCases) { muscle in
                    chip(
                        title: muscle.displayName,
                        icon: muscle.icon,
                        isOn: viewModel.selectedMuscles.contains(muscle)
                    ) {
                        Haptics.light()
                        viewModel.toggleMuscle(muscle)
                    }
                }
            }
        }
    }

    // MARK: - Time

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                sectionTitle("Time budget", subtitle: nil)
                Spacer()
                Text("\(viewModel.timeBudgetMinutes) min")
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.accent)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.timeBudgetMinutes) },
                    set: { viewModel.timeBudgetMinutes = Int(($0 / 5).rounded()) * 5 }
                ),
                in: Double(viewModel.minTime)...Double(viewModel.maxTime),
                step: 5
            )
            .tint(Theme.accent)
            .accessibilityValue("\(viewModel.timeBudgetMinutes) minutes")
        }
    }

    // MARK: - Sets

    private var setsSection: some View {
        HStack {
            sectionTitle("Sets per exercise", subtitle: nil)
            Spacer()
            Stepper(
                value: $viewModel.targetSets,
                in: viewModel.minSets...viewModel.maxSets
            ) {
                Text("\(viewModel.targetSets)")
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.accent)
            }
            .fixedSize()
        }
    }

    // MARK: - Generate bar

    private var generateBar: some View {
        VStack {
            Spacer()
            XomButton("Generate", variant: .primary, icon: "dice.fill") {
                Haptics.medium()
                viewModel.generate(userId: userId)
                showPreview = true
            }
            .disabled(!viewModel.canGenerate)
            .opacity(viewModel.canGenerate ? 1 : 0.5)
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Reusable pieces

    private func sectionTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func chip(title: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.sm)
            .foregroundStyle(isOn ? .black : Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(isOn ? Theme.accent : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .strokeBorder(isOn ? Color.clear : Theme.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
