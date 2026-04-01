import SwiftUI

struct FriendsListView: View {
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]
    let currentUserId: String

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
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
