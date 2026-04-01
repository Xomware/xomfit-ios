import SwiftUI

struct OnboardingGoalsScreen: View {
    @Binding var selectedGoals: Set<TrainingGoal>
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.xl)

            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Text("What do you train for?")
                    .font(Theme.fontTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick all that apply")
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .staggeredAppear(index: 0)

            // Goal grid
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(Array(TrainingGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                    GoalCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal),
                        onTap: {
                            Haptics.selection()
                            withAnimation(.xomPlayful) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }
                    )
                    .staggeredAppear(index: index + 1)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // CTA
            XomButton("Continue", action: onContinue)
                .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: TrainingGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: goal.icon)
                        .font(.largeTitle)
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Theme.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(goal.subtitle)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(Theme.Spacing.md)
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(isSelected ? Theme.accent.opacity(0.08) : Theme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.glassBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
