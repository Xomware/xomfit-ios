import SwiftUI

/// Horizontal scrolling filter pills used by the profile feed / workout-history
/// views. The main social feed migrated to a filter modal (`FeedFilterSheet`,
/// #feed-filter-modal); these profile lists still use the inline pill bar.
///
/// The shared filter types (`FeedDateRange`, etc.) live in `FeedFilterSheet.swift`.
struct FeedFilterBar: View {
    @Binding var selectedDateRange: FeedDateRange
    @Binding var selectedMuscleGroups: Set<MuscleGroup>

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    // Date range chips
                    ForEach(FeedDateRange.allCases) { range in
                        let isActive = selectedDateRange == range
                        Button {
                            withAnimation(.xomChill) { selectedDateRange = range }
                        } label: {
                            XomBadge(range.rawValue, variant: .interactive, isActive: isActive)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(range.rawValue)\(isActive ? ", selected" : "")")
                    }

                    // Vertical hairline separator
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 0.5, height: 20)

                    // Muscle group chips
                    ForEach(MuscleGroup.allCases) { group in
                        let isActive = selectedMuscleGroups.contains(group)
                        Button {
                            withAnimation(.xomChill) {
                                if selectedMuscleGroups.contains(group) {
                                    selectedMuscleGroups.remove(group)
                                } else {
                                    selectedMuscleGroups.insert(group)
                                }
                            }
                        } label: {
                            XomBadge(group.displayName, icon: group.icon, variant: .interactive, isActive: isActive)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(group.displayName)\(isActive ? ", selected" : "")")
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.sm)

            XomDivider()
        }
    }
}
