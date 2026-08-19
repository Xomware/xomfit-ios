import SwiftUI

/// Reusable filter bar for the workout tabs.
///
/// One row by default: a search field with a filter toggle. The muscle-group
/// and equipment chip rails expand underneath on demand.
///
/// They used to be permanently expanded, so this bar cost three rows above
/// every workout list — search plus two chip rails — for controls most sessions
/// never touch. The toggle carries a dot when a filter is active, so a narrowed
/// list is never silently narrowed.
struct WorkoutFilterBar: View {
    @Binding var filter: WorkoutFilter

    @State private var isExpanded = false

    /// True when the list is actually being narrowed by a chip selection.
    private var hasActiveFilter: Bool {
        filter.muscleGroup != nil || filter.equipment != nil
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            searchRow
            if isExpanded {
                muscleGroupChips
                equipmentChips
            }
        }
        .padding(.bottom, Theme.Spacing.xs)
        .animation(.xomConfident, value: isExpanded)
    }

    private var searchRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            searchField

            Button {
                Haptics.selection()
                isExpanded.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isExpanded || hasActiveFilter ? .black : Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(isExpanded || hasActiveFilter ? Theme.accent : Theme.surface)
                    )
                    .overlay(alignment: .topTrailing) {
                        if hasActiveFilter && !isExpanded {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide filters" : "Show filters")
            .accessibilityValue(hasActiveFilter ? "Filters active" : "No filters")
        }
        .padding(.trailing, Theme.Spacing.md)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textTertiary)
            TextField("Search workouts...", text: $filter.searchText)
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .accessibilityLabel("Search workouts")
            if !filter.searchText.isEmpty {
                Button {
                    Haptics.selection()
                    filter.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .padding(.leading, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Muscle Group Chips

    private var muscleGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Haptics.selection()
                    filter.muscleGroup = nil
                } label: {
                    XomBadge("All Muscles", variant: .interactive, isActive: filter.muscleGroup == nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All muscle groups")
                .accessibilityAddTraits(filter.muscleGroup == nil ? [.isButton, .isSelected] : .isButton)

                ForEach(MuscleGroup.allCases) { mg in
                    Button {
                        Haptics.selection()
                        filter.muscleGroup = filter.muscleGroup == mg ? nil : mg
                    } label: {
                        XomBadge(mg.displayName, variant: .interactive, isActive: filter.muscleGroup == mg)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mg.displayName)
                    .accessibilityAddTraits(filter.muscleGroup == mg ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    // MARK: - Equipment Chips

    private var equipmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Haptics.selection()
                    filter.equipment = nil
                } label: {
                    XomBadge("All Equipment", variant: .interactive, isActive: filter.equipment == nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All equipment")
                .accessibilityAddTraits(filter.equipment == nil ? [.isButton, .isSelected] : .isButton)

                ForEach(Equipment.allCases, id: \.self) { eq in
                    Button {
                        Haptics.selection()
                        filter.equipment = filter.equipment == eq ? nil : eq
                    } label: {
                        XomBadge(eq.displayName, variant: .interactive, isActive: filter.equipment == eq)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(eq.displayName)
                    .accessibilityAddTraits(filter.equipment == eq ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

#Preview {
    @Previewable @State var filter = WorkoutFilter()
    return ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            WorkoutFilterBar(filter: $filter)
            Spacer()
        }
    }
}
