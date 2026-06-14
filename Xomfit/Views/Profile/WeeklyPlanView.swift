import SwiftUI

/// Set/edit the user's weekly training goal: a target session count plus
/// optional focus regions (Push / Pull / Legs / Core). Persists via the view
/// model → `WeeklyPlanService`. When cleared, the nudge reverts to adaptive.
///
/// MVVM: this view holds only view state and binds to `WeeklyPlanViewModel`;
/// it never touches `WeeklyPlanService` or `UserDefaults` directly.
struct WeeklyPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WeeklyPlanViewModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                targetSessionsSection
                focusSection
                actionsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Weekly Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Sections

    private var targetSessionsSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "calendar.badge.clock")
                    .frame(width: Theme.Spacing.lg)
                    .foregroundStyle(Theme.accent)
                Stepper(
                    value: $viewModel.targetSessions,
                    in: WeeklyPlanViewModel.minSessions...WeeklyPlanViewModel.maxSessions
                ) {
                    HStack {
                        Text("Sessions per week")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(viewModel.targetSessions)×")
                            .font(Theme.fontNumberMedium)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .accessibilityLabel("Target sessions per week")
                .accessibilityValue("\(viewModel.targetSessions)")
            }
        } header: {
            XomMetricLabel("Target")
        } footer: {
            Text("How many workouts you're aiming for this week.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var focusSection: some View {
        Section {
            ForEach(TrainingRegion.allCases) { region in
                Button {
                    Haptics.selection()
                    viewModel.toggle(region)
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: region.icon)
                            .frame(width: Theme.Spacing.lg)
                            .foregroundStyle(viewModel.isSelected(region) ? Theme.accent : Theme.textTertiary)
                        Text(region.displayName)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if viewModel.isSelected(region) {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.isSelected(region) ? .isSelected : [])
                .accessibilityHint("Toggle \(region.displayName) as a weekly focus")
            }
        } header: {
            XomMetricLabel("Focus")
        } footer: {
            Text("Optional. Picked regions get nudged when you fall behind your plan's pace. Leave empty for a session-count-only goal.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }

    private var actionsSection: some View {
        Section {
            Button {
                Haptics.success()
                viewModel.save()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Save Plan")
                        .font(Theme.fontBodyEmphasized)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Saves your weekly plan")

            if viewModel.hasPlan {
                Button(role: .destructive) {
                    Haptics.warning()
                    viewModel.clearPlan()
                } label: {
                    HStack {
                        Spacer()
                        Text("Clear Plan")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.destructive)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes your weekly plan and reverts to the adaptive nudge")
            }
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.hairline)
    }
}
