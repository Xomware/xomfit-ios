import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendViewModel()
    @State private var selectedTab: FriendsTab = .friends
    
    enum FriendsTab {
        case friends
        case following
        case followers
        case requests
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                TabSelectorView(selectedTab: $selectedTab)
                
                // Content
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.accent)
                    } else if let error = viewModel.error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        contentView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .task {
                await loadInitialData()
            }
        }
    }
    
    @ViewBuilder
    private func contentView() -> some View {
        switch selectedTab {
        case .friends:
            if viewModel.friends.isEmpty {
                emptyStateView("No Friends Yet", "Add friends to see their workouts on your feed")
            } else {
                friendListView(viewModel.friends)
            }
            
        case .following:
            if viewModel.following.isEmpty {
                emptyStateView("Not Following Anyone", "Follow users to see their activity")
            } else {
                followingListView(viewModel.following)
            }
            
        case .followers:
            if viewModel.followers.isEmpty {
                emptyStateView("No Followers Yet", "Build your community by sharing your progress")
            } else {
                friendListView(viewModel.followers)
            }
            
        case .requests:
            if viewModel.pendingRequests.isEmpty {
                emptyStateView("No Pending Requests", "You're all caught up!")
            } else {
                requestsListView(viewModel.pendingRequests)
            }
        }
    }
    
    private func friendListView(_ users: [User]) -> some View {
        List(users) { user in
            NavigationLink(destination: FriendDetailView(user: user, viewModel: viewModel)) {
                FriendRowView(user: user)
            }
        }
        .listStyle(.plain)
    }
    
    private func followingListView(_ users: [User]) -> some View {
        List(users) { user in
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(Color.accent.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(user.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.accent.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
    
    private func requestsListView(_ requests: [FriendRequest]) -> some View {
        List(requests) { request in
            VStack(alignment: .leading, spacing: 8) {
                if let user = request.fromUser {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accent.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(user.displayName.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.accent)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.headline)
                            Text("Sent \(formatDate(request.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            Task {
                                await viewModel.acceptFriendRequest(request)
                            }
                        }) {
                            Text("Accept")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accent)
                                .foregroundColor(.black)
                                .cornerRadius(6)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.declineFriendRequest(request)
                            }
                        }) {
                            Text("Decline")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
    
    private func emptyStateView(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.accent.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if selectedTab == .requests {
                NavigationLink(destination: SearchUsersView(viewModel: viewModel)) {
                    Text("Find Friends")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accent.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadInitialData() async {
        async let loadFriends = viewModel.loadFriends()
        async let loadFollowing = viewModel.loadFollowing()
        async let loadFollowers = viewModel.loadFollowers()
        async let loadRequests = viewModel.loadPendingRequests()
        
        _ = await (loadFriends, loadFollowing, loadFollowers, loadRequests)
    }
    
    private func formatDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Tab Selector

struct TabSelectorView: View {
    @Binding var selectedTab: FriendsView.FriendsTab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                tabButton("Friends", for: .friends)
                tabButton("Following", for: .following)
                tabButton("Followers", for: .followers)
                tabButton("Requests", for: .requests)
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(Color(.systemBackground))
        .borderBottom(color: .separator)
    }
    
    private func tabButton(_ title: String, for tab: FriendsView.FriendsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(selectedTab == tab ? .accent : .secondary)
                
                if selectedTab == tab {
                    Capsule()
                        .fill(Color.accent)
                        .frame(height: 2)
                }
            }
        }
    }
}

// MARK: - Friend Row

struct FriendRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accent.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.displayName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.accent)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.stats.totalWorkouts)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accent)
                Text("workouts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend Detail

struct FriendDetailView: View {
    let user: User
    let viewModel: FriendViewModel
    @State private var mutualFriendsCount = 0
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.accent.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 32).weight(.semibold))
                            .foregroundColor(.accent)
                    )
                
                Text(user.displayName)
                    .font(.title3.weight(.bold))
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Stats
            HStack(spacing: 16) {
                StatCard(title: "Workouts", value: "\(user.stats.totalWorkouts)")
                StatCard(title: "Volume", value: "\(user.stats.totalVolume.formatted())")
                StatCard(title: "PRs", value: "\(user.stats.totalPRs)")
            }
            
            if mutualFriendsCount > 0 {
                Text("\(mutualFriendsCount) mutual friends")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            mutualFriendsCount = await viewModel.getMutualFriendsCount(with: user.id)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.accent)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - View Extensions

extension View {
    func borderBottom(color: Color = .separator) -> some View {
        VStack {
            self
            Divider()
                .background(color)
        }
    }
}

#Preview {
    FriendsView()
}
