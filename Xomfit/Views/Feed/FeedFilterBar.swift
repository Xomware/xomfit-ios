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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date range chips
                ForEach(FeedDateRange.allCases) { range in
                    filterChip(
                        label: range.rawValue,
                        isSelected: selectedDateRange == range
                    ) {
                        withAnimation(.xomChill) { selectedDateRange = range }
                    }
                }

                // Divider
                Rectangle()
                    .fill(Theme.textSecondary.opacity(0.3))
                    .frame(width: 1, height: 20)

                // Muscle group chips
                ForEach(MuscleGroup.allCases) { group in
                    filterChip(
                        icon: group.icon,
                        label: group.displayName,
                        isSelected: selectedMuscleGroups.contains(group)
                    ) {
                        withAnimation(.xomChill) {
                            if selectedMuscleGroups.contains(group) {
                                selectedMuscleGroups.remove(group)
                            } else {
                                selectedMuscleGroups.insert(group)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, 8)
    }

    private func filterChip(icon: String? = nil, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .black : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accent : Theme.surfaceSecondary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isSelected ? ", selected" : "")")
    }
}
