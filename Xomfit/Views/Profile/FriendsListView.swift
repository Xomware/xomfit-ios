import SwiftUI

struct FriendsListView: View {
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]
    let currentUserId: String
    /// Optional pull-to-refresh handler. Owners that hold the friends data (e.g.
    /// `ProfileViewModel`) can pass `loadAll` here so the user can swipe down to
    /// refetch from this screen.
    var onRefresh: (() async -> Void)? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                ProfileFriendsView(
                    friends: friends,
                    friendProfiles: friendProfiles,
                    currentUserId: currentUserId
                )
                .padding(.top, Theme.Spacing.sm)
            }
            .refreshable {
                await onRefresh?()
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
