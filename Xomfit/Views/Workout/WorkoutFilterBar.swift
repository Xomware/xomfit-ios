import SwiftUI

/// Reusable filter bar for the workout tabs.
///
/// Pattern mirrors `ExercisePickerView` — a search field plus two horizontal chip
/// rails (muscle group + equipment). Emits state through a `WorkoutFilter` binding.
struct WorkoutFilterBar: View {
    @Binding var filter: WorkoutFilter

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            searchField
            muscleGroupChips
            equipmentChips
        }
        .padding(.bottom, Theme.Spacing.xs)
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
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.md)
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
