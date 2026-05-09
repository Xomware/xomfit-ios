import SwiftUI

// MARK: - Mode

enum FitnessQuestionnaireMode {
    /// First-launch flow: shows "Maybe later" skip option, calls onFinish on save/skip.
    case onboarding
    /// Profile edit mode: no skip option, dismisses on save.
    case edit
}

// MARK: - View

struct FitnessQuestionnaireView: View {
    let mode: FitnessQuestionnaireMode
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboardingSkipped") private var onboardingSkipped = false

    @State private var draft: UserFitnessProfile
    @State private var currentPage = 0

    private let totalPages = 5

    init(
        mode: FitnessQuestionnaireMode = .onboarding,
        onFinish: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.onFinish = onFinish
        // Seed with whatever is persisted so edit mode shows current answers,
        // and onboarding mode preserves partial selections across sessions.
        _draft = State(initialValue: UserFitnessProfile.current)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            // Subtle accent gradient
            RadialGradient(
                colors: [Theme.accent.opacity(0.04), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                primaryGoalPage.tag(0)
                experiencePage.tag(1)
                workoutsPerWeekPage.tag(2)
                splitPage.tag(3)
                sessionLengthPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.xomChill, value: currentPage)

            bottomBar
        }
        .preferredColorScheme(.dark)
        .toolbar(mode == .edit ? .visible : .hidden, for: .navigationBar)
    }

    // MARK: - Pages

    private var primaryGoalPage: some View {
        QuestionPage(
            title: "What's your primary goal?",
            subtitle: "We'll tailor your plan around this.",
            stepIndex: 0,
            totalSteps: totalPages
        ) {
            ChoiceList(
                options: FitnessPrimaryGoal.allCases,
                selection: $draft.primaryGoal,
                label: { $0.title },
                icon: { $0.icon }
            )
        }
    }

    private var experiencePage: some View {
        QuestionPage(
            title: "How experienced are you?",
            subtitle: "Be honest — beginners get the best gains.",
            stepIndex: 1,
            totalSteps: totalPages
        ) {
            ChoiceList(
                options: FitnessExperience.allCases,
                selection: $draft.experience,
                label: { $0.title },
                subtitle: { $0.subtitle }
            )
        }
    }

    private var workoutsPerWeekPage: some View {
        QuestionPage(
            title: "How many workouts per week?",
            subtitle: "Pick a realistic target.",
            stepIndex: 2,
            totalSteps: totalPages
        ) {
            ChipGrid(
                options: FitnessWorkoutsPerWeek.allCases,
                selection: $draft.workoutsPerWeek,
                label: { $0.title }
            )
        }
    }

    private var splitPage: some View {
        QuestionPage(
            title: "Preferred split?",
            subtitle: "How do you like to organize your sessions?",
            stepIndex: 3,
            totalSteps: totalPages
        ) {
            ChoiceList(
                options: FitnessSplit.allCases,
                selection: $draft.preferredSplit,
                label: { $0.title },
                subtitle: { $0.subtitle }
            )
        }
    }

    private var sessionLengthPage: some View {
        QuestionPage(
            title: "How long per session?",
            subtitle: "Including warm-ups and rest.",
            stepIndex: 4,
            totalSteps: totalPages
        ) {
            ChipGrid(
                options: FitnessSessionLength.allCases,
                selection: $draft.sessionLength,
                label: { $0.title }
            )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Progress dots
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Theme.accent : Theme.surfaceElevated)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    index == currentPage ? Theme.accent : Theme.hairline,
                                    lineWidth: 0.5
                                )
                        )
                        .scaleEffect(index == currentPage ? 1.2 : 1)
                        .animation(.xomPlayful, value: currentPage)
                }
            }

            // Primary CTA
            XomButton(primaryButtonTitle, action: advance)
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.5)

            // Secondary actions
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        Haptics.light()
                        withAnimation(.xomChill) { currentPage -= 1 }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                if mode == .onboarding {
                    Button("Maybe later", action: skip)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                } else if mode == .edit {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch currentPage {
        case 0: draft.primaryGoal != nil
        case 1: draft.experience != nil
        case 2: draft.workoutsPerWeek != nil
        case 3: draft.preferredSplit != nil
        case 4: draft.sessionLength != nil
        default: false
        }
    }

    private var primaryButtonTitle: String {
        currentPage == totalPages - 1 ? "Save" : "Continue"
    }

    private func advance() {
        Haptics.light()
        if currentPage < totalPages - 1 {
            withAnimation(.xomChill) { currentPage += 1 }
        } else {
            save()
        }
    }

    private func save() {
        var saved = draft
        saved.completedAt = Date()
        UserFitnessProfile.current = saved
        // Once they've completed, they're not "skipped" anymore.
        onboardingSkipped = false
        Haptics.success()

        if mode == .edit {
            dismiss()
        } else {
            onFinish()
        }
    }

    private func skip() {
        Haptics.light()
        onboardingSkipped = true
        onFinish()
    }
}

// MARK: - Question Page Container

private struct QuestionPage<Content: View>: View {
    let title: String
    let subtitle: String
    let stepIndex: Int
    let totalSteps: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer().frame(height: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Step \(stepIndex + 1) of \(totalSteps)")
                        .font(Theme.fontMetricLabel)
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .kerning(0.5)

                    Text(title)
                        .font(Theme.fontTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(Theme.fontSubheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .staggeredAppear(index: 0)

                content()
                    .padding(.horizontal, Theme.Spacing.lg)
                    .staggeredAppear(index: 1)

                // Leave room for the bottom bar.
                Spacer().frame(height: 180)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Choice List (vertical card list with optional subtitle/icon)

private struct ChoiceList<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String
    var subtitle: ((Option) -> String)? = nil
    var icon: ((Option) -> String)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(options) { option in
                ChoiceRow(
                    label: label(option),
                    subtitle: subtitle?(option),
                    icon: icon?(option),
                    isSelected: selection == option,
                    onTap: {
                        Haptics.selection()
                        withAnimation(.xomPlayful) {
                            selection = option
                        }
                    }
                )
            }
        }
    }
}

private struct ChoiceRow: View {
    let label: String
    let subtitle: String?
    let icon: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isSelected ? Theme.accent.opacity(0.08) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.hairline,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Chip Grid (compact options like 30/45/60 min)

private struct ChipGrid<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(options) { option in
                ChipButton(
                    label: label(option),
                    isSelected: selection == option,
                    onTap: {
                        Haptics.selection()
                        withAnimation(.xomPlayful) {
                            selection = option
                        }
                    }
                )
            }
        }
    }
}

private struct ChipButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? .black : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(isSelected ? Theme.accent : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(
                            isSelected ? Color.clear : Theme.hairline,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    FitnessQuestionnaireView(mode: .onboarding, onFinish: {})
}

#Preview("Edit") {
    NavigationStack {
        FitnessQuestionnaireView(mode: .edit, onFinish: {})
    }
}
