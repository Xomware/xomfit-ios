import SwiftUI

// MARK: - Filter Types

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

/// Sort order for the feed. `recent` is the default and matches the backend
/// ordering; the rating variants reorder by overall workout rating.
enum FeedSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case highestRated = "Highest Rated"
    case lowestRated = "Lowest Rated"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recent: return "clock"
        case .highestRated: return "arrow.down"
        case .lowestRated: return "arrow.up"
        }
    }
}

/// Lightweight user option for the feed's per-user filter. `id` is the
/// poster's `userId` so it matches `FeedViewModel.selectedUserIds`.
struct FeedUserOption: Identifiable, Hashable {
    let id: String
    let name: String
    let avatarURL: String?
}

// MARK: - Feed Filter Sheet

/// Modal that owns every feed filter control (#feed-filter-modal). Replaces the
/// old horizontal pill bar. Edits a local draft so the feed only re-filters
/// when the user taps **Apply**; **Clear** resets the draft to defaults, and
/// dismissing without applying discards changes.
struct FeedFilterSheet: View {
    let availableUsers: [FeedUserOption]
    let onApply: (_ sort: FeedSortOption,
                  _ dateRange: FeedDateRange,
                  _ minRating: Int,
                  _ muscleGroups: Set<MuscleGroup>,
                  _ userIds: Set<String>) -> Void

    @State private var draftSort: FeedSortOption
    @State private var draftDateRange: FeedDateRange
    @State private var draftMinRating: Int
    @State private var draftMuscleGroups: Set<MuscleGroup>
    @State private var draftUserIds: Set<String>

    @Environment(\.dismiss) private var dismiss

    init(
        sortOption: FeedSortOption,
        dateRange: FeedDateRange,
        minRating: Int,
        selectedMuscleGroups: Set<MuscleGroup>,
        selectedUserIds: Set<String>,
        availableUsers: [FeedUserOption],
        onApply: @escaping (FeedSortOption, FeedDateRange, Int, Set<MuscleGroup>, Set<String>) -> Void
    ) {
        self.availableUsers = availableUsers
        self.onApply = onApply
        _draftSort = State(initialValue: sortOption)
        _draftDateRange = State(initialValue: dateRange)
        _draftMinRating = State(initialValue: minRating)
        _draftMuscleGroups = State(initialValue: selectedMuscleGroups)
        _draftUserIds = State(initialValue: selectedUserIds)
    }

    /// True when the draft differs from the no-filter defaults — drives the
    /// Clear button's enabled state.
    private var hasActiveDraft: Bool {
        draftSort != .recent
            || draftDateRange != .all
            || draftMinRating > 0
            || !draftMuscleGroups.isEmpty
            || !draftUserIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        sortSection
                        dateSection
                        ratingSection
                        if availableUsers.count > 1 { usersSection }
                        muscleSection
                    }
                    .padding(Theme.Spacing.md)
                    // Leave room for the pinned action bar.
                    .padding(.bottom, 96)
                }

                VStack(spacing: 0) {
                    Spacer()
                    actionBar
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Close filters")
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.lg)
    }

    // MARK: - Sort

    private var sortSection: some View {
        sectionContainer(title: "Sort By", icon: "arrow.up.arrow.down") {
            Picker("Sort By", selection: $draftSort) {
                ForEach(FeedSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Date Range

    private var dateSection: some View {
        sectionContainer(title: "Date Range", icon: "calendar") {
            chipFlow(FeedDateRange.allCases) { range in
                filterChip(
                    label: range.rawValue,
                    isActive: draftDateRange == range
                ) {
                    withAnimation(.xomSnappy) { draftDateRange = range }
                }
            }
        }
    }

    // MARK: - Minimum Rating

    /// Tappable star row that picks a minimum overall-rating threshold. Tapping
    /// the current value clears it back to "Any".
    private var ratingSection: some View {
        sectionContainer(title: "Minimum Rating", icon: "star.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.xomSnappy) {
                                draftMinRating = (draftMinRating == star) ? 0 : star
                            }
                        } label: {
                            Image(systemName: star <= draftMinRating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(star <= draftMinRating ? Theme.accent : Theme.textSecondary.opacity(0.4))
                                .frame(minWidth: 36, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Minimum \(star) star\(star == 1 ? "" : "s")")
                        .accessibilityAddTraits(star <= draftMinRating ? .isSelected : [])
                    }
                    Spacer()
                }

                Text(draftMinRating == 0 ? "Any rating" : "\(draftMinRating)+ stars")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Users

    private var usersSection: some View {
        sectionContainer(title: "Users", icon: "person.2.fill") {
            VStack(spacing: 0) {
                ForEach(Array(availableUsers.enumerated()), id: \.element.id) { index, user in
                    Button {
                        withAnimation(.xomSnappy) { toggleUser(user.id) }
                    } label: {
                        userRow(user: user, isSelected: draftUserIds.contains(user.id))
                    }
                    .buttonStyle(.plain)

                    if index < availableUsers.count - 1 {
                        XomDivider()
                    }
                }
            }
        }
    }

    private func userRow(user: FeedUserOption, isSelected: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            XomAvatar(
                name: user.name,
                size: 36,
                imageURL: user.avatarURL.flatMap { URL(string: $0) }
            )
            Text(user.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary.opacity(0.4))
        }
        .padding(.vertical, Theme.Spacing.sm)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.name)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Muscle Groups

    private var muscleSection: some View {
        sectionContainer(title: "Body Parts", icon: "figure.strengthtraining.traditional") {
            chipFlow(MuscleGroup.allCases) { group in
                filterChip(
                    label: group.displayName,
                    icon: group.icon,
                    isActive: draftMuscleGroups.contains(group)
                ) {
                    withAnimation(.xomSnappy) { toggleMuscle(group) }
                }
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomButton("Clear", variant: .ghost) {
                Haptics.light()
                withAnimation(.xomSnappy) { clearDraft() }
            }
            .disabled(!hasActiveDraft)
            .opacity(hasActiveDraft ? 1 : 0.5)

            XomButton("Apply", variant: .primary) {
                Haptics.success()
                onApply(draftSort, draftDateRange, draftMinRating, draftMuscleGroups, draftUserIds)
                dismiss()
            }
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            XomDivider()
        }
    }

    // MARK: - Mutations

    private func toggleMuscle(_ group: MuscleGroup) {
        if draftMuscleGroups.contains(group) {
            draftMuscleGroups.remove(group)
        } else {
            draftMuscleGroups.insert(group)
        }
    }

    private func toggleUser(_ id: String) {
        if draftUserIds.contains(id) {
            draftUserIds.remove(id)
        } else {
            draftUserIds.insert(id)
        }
    }

    private func clearDraft() {
        draftSort = .recent
        draftDateRange = .all
        draftMinRating = 0
        draftMuscleGroups = []
        draftUserIds = []
    }

    // MARK: - Reusable Pieces

    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    /// Wrapping chip layout. Uses `LazyVGrid` with adaptive columns so chips
    /// flow onto multiple rows without manual width math.
    private func chipFlow<T: Identifiable, ChipView: View>(
        _ items: [T],
        @ViewBuilder chip: @escaping (T) -> ChipView
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: Theme.Spacing.sm, alignment: .leading)],
            alignment: .leading,
            spacing: Theme.Spacing.sm
        ) {
            ForEach(items) { item in
                chip(item)
            }
        }
    }

    private func filterChip(
        label: String,
        icon: String? = nil,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            XomBadge(label, icon: icon, variant: .interactive, isActive: isActive)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isActive ? ", selected" : "")")
    }
}
