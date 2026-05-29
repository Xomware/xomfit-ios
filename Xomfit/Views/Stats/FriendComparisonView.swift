import SwiftUI

/// Side-by-side month-to-date comparison between you and a selected friend.
///
/// Pure view: it owns the friend selection + the loaded friend snapshot, but
/// all data comes in via `myStats`, `friends`, and the async `loadFriend`
/// closure supplied by `StatsView`.
struct FriendComparisonView: View {
    let myStats: ComparisonStats
    let friends: [StatsFriend]
    /// Loads a friend's snapshot. Returns nil on failure.
    let loadFriend: (String) async -> ComparisonStats?

    @State private var selectedFriendId: String?
    @State private var friendStats: ComparisonStats?
    @State private var isLoadingFriend = false

    private var selectedFriend: StatsFriend? {
        friends.first { $0.id == selectedFriendId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            friendPicker

            if let friend = selectedFriend {
                comparisonCards(friend: friend)
            } else {
                Text("Pick a friend to compare your month.")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xs)
            }
        }
        .cardStyle()
        .onAppear {
            if selectedFriendId == nil { selectedFriendId = friends.first?.id }
        }
        .task(id: selectedFriendId) {
            await refreshFriend()
        }
    }

    // MARK: - Friend Picker

    private var friendPicker: some View {
        Menu {
            ForEach(friends) { friend in
                Button {
                    Haptics.selection()
                    selectedFriendId = friend.id
                } label: {
                    if friend.id == selectedFriendId {
                        Label(friend.label, systemImage: "checkmark")
                    } else {
                        Text(friend.label)
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.accent)
                Text(selectedFriend?.label ?? "Select a friend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Select friend to compare")
    }

    // MARK: - Comparison Cards

    @ViewBuilder
    private func comparisonCards(friend: StatsFriend) -> some View {
        let friendStats = friendStats ?? ComparisonStats()

        VStack(spacing: Theme.Spacing.sm) {
            headerRow(friend: friend)

            comparisonRow(
                label: "Workouts",
                mine: "\(myStats.workoutsThisMonth)",
                theirs: "\(friendStats.workoutsThisMonth)",
                mineWins: myStats.workoutsThisMonth >= friendStats.workoutsThisMonth,
                tie: myStats.workoutsThisMonth == friendStats.workoutsThisMonth
            )
            comparisonRow(
                label: "Volume",
                mine: StatsViewModel.formatVolume(myStats.volumeThisMonth),
                theirs: StatsViewModel.formatVolume(friendStats.volumeThisMonth),
                mineWins: myStats.volumeThisMonth >= friendStats.volumeThisMonth,
                tie: myStats.volumeThisMonth == friendStats.volumeThisMonth
            )
            comparisonRow(
                label: "PRs",
                mine: "\(myStats.prsThisMonth)",
                theirs: "\(friendStats.prsThisMonth)",
                mineWins: myStats.prsThisMonth >= friendStats.prsThisMonth,
                tie: myStats.prsThisMonth == friendStats.prsThisMonth
            )
            comparisonRow(
                label: "Streak",
                mine: "\(myStats.currentStreak)",
                theirs: "\(friendStats.currentStreak)",
                mineWins: myStats.currentStreak >= friendStats.currentStreak,
                tie: myStats.currentStreak == friendStats.currentStreak
            )
            comparisonRow(
                label: "Avg / wk",
                mine: String(format: "%.1f", myStats.avgWorkoutsPerWeek),
                theirs: String(format: "%.1f", friendStats.avgWorkoutsPerWeek),
                mineWins: myStats.avgWorkoutsPerWeek >= friendStats.avgWorkoutsPerWeek,
                tie: myStats.avgWorkoutsPerWeek == friendStats.avgWorkoutsPerWeek
            )
        }
    }

    private func headerRow(friend: StatsFriend) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("You")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            if isLoadingFriend {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(friend.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, Theme.Spacing.xs)
    }

    private func comparisonRow(
        label: String,
        mine: String,
        theirs: String,
        mineWins: Bool,
        tie: Bool
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Your value (left)
            HStack(spacing: Theme.Spacing.tight) {
                if mineWins && !tie {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.prGold)
                }
                Text(mine)
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center metric label
            Text(label.uppercased())
                .font(Theme.fontMetricLabel)
                .foregroundStyle(Theme.textTertiary)
                .kerning(0.5)
                .frame(width: 84)

            // Friend value (right)
            HStack(spacing: Theme.Spacing.tight) {
                Text(theirs)
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.textSecondary)
                if !mineWins && !tie {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.prGold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.tight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.background.opacity(0.4))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): you \(mine), friend \(theirs)")
    }

    // MARK: - Loading

    private func refreshFriend() async {
        guard let id = selectedFriendId else { return }
        isLoadingFriend = true
        friendStats = await loadFriend(id)
        isLoadingFriend = false
    }
}

// MARK: - Preview

#Preview {
    FriendComparisonView(
        myStats: ComparisonStats(
            workoutsThisMonth: 14,
            volumeThisMonth: 124_500,
            prsThisMonth: 3,
            currentStreak: 5,
            avgWorkoutsPerWeek: 3.5
        ),
        friends: [
            StatsFriend(id: "1", displayName: "Lift Buddy", username: "lift_buddy", avatarURL: nil)
        ],
        loadFriend: { _ in
            ComparisonStats(
                workoutsThisMonth: 9,
                volumeThisMonth: 98_000,
                prsThisMonth: 5,
                currentStreak: 2,
                avgWorkoutsPerWeek: 2.25
            )
        }
    )
    .padding()
    .background(Theme.background)
}
