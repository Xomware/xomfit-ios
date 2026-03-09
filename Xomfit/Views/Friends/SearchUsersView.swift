import SwiftUI

struct SearchUsersView: View {
    @ObservedObject var viewModel: FriendViewModel
    @State private var searchText = ""
    @State private var selectedUser: User?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { newValue in
                        Task {
                            if newValue.isEmpty {
                                viewModel.clearSearch()
                            } else {
                                await viewModel.searchUsers(newValue)
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()
            
            // Results
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.accent)
                    Spacer()
                }
            } else if searchText.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Search for users")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No users found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(viewModel.searchResults) { user in
                    NavigationLink(destination: SearchResultDetailView(user: user, viewModel: viewModel)) {
                        SearchResultRowView(user: user)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// MARK: - Search Result Row

struct SearchResultRowView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Result Detail

struct SearchResultDetailView: View {
    let user: User
    let viewModel: FriendViewModel
    @State private var requestSent = false
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
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
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Stats Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(title: "Workouts", value: "\(user.stats.totalWorkouts)")
                    StatCard(title: "Volume", value: formatVolume(user.stats.totalVolume))
                }
                HStack(spacing: 12) {
                    StatCard(title: "PRs", value: "\(user.stats.totalPRs)")
                    StatCard(title: "Streak", value: "\(user.stats.currentStreak)d")
                }
            }
            
            // Favorite Exercise
            if let favoriteExercise = user.stats.favoriteExercise {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(.accent)
                    Text("Favorite: \(favoriteExercise)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.accent.opacity(0.1))
                .cornerRadius(8)
            }
            
            // CTA Button
            Button(action: {
                Task {
                    isLoading = true
                    await viewModel.sendFriendRequest(toUserId: user.id)
                    requestSent = true
                    isLoading = false
                    
                    // Dismiss after a short delay
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    dismiss()
                }
            }) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else if requestSent {
                    Text("Request Sent ✓")
                        .font(.headline.weight(.semibold))
                } else {
                    Text("Send Friend Request")
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(requestSent ? Color.accent.opacity(0.6) : Color.accent)
            .foregroundColor(.black)
            .cornerRadius(8)
            .disabled(requestSent || isLoading)
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return String(Int(volume))
    }
}

#Preview {
    NavigationView {
        SearchUsersView(viewModel: FriendViewModel())
    }
}
