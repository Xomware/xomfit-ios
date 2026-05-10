import SwiftUI

enum FeedDateRange: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"

    var id: String { rawValue }

    /// Returns the start date for this range, or nil for "all time".
    var startDate: Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .all: return nil
        case .today: return cal.startOfDay(for: now)
        case .thisWeek: return cal.dateInterval(of: .weekOfYear, for: now)?.start
        case .thisMonth: return cal.dateInterval(of: .month, for: now)?.start
        }
    }
}

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
