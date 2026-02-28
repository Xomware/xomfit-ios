import SwiftUI

struct SuggestedFriendsView: View {
    @ObservedObject var viewModel: FriendViewModel
    @State private var dismissedSuggestions: Set<String> = []
    
    var filteredSuggestions: [FriendSuggestion] {
        viewModel.suggestedFriends.filter { !dismissedSuggestions.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.accent)
                    Spacer()
                }
            } else if filteredSuggestions.isEmpty {
                emptyStateView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Suggested Friends")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        
                        ForEach(filteredSuggestions) { suggestion in
                            SuggestedFriendCard(suggestion: suggestion) {
                                Task {
                                    await viewModel.sendFriendRequest(toUserId: suggestion.user.id)
                                    dismissedSuggestions.insert(suggestion.id)
                                }
                            } onDismiss: {
                                dismissedSuggestions.insert(suggestion.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Suggested Friends")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .task {
            await viewModel.loadSuggestedFriends()
        }
    }
    
    private func emptyStateView() -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accent.opacity(0.5))
            Text("No Suggestions Yet")
                .font(.headline)
            Text("We'll suggest friends as you grow your network")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Suggested Friend Card

struct SuggestedFriendCard: View {
    let suggestion: FriendSuggestion
    let onAdd: () -> Void
    let onDismiss: () -> Void
    
    @State private var isAdding = false
    @State private var isAdded = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.accent.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text(String(suggestion.user.displayName.prefix(1)))
                            .font(.system(size: 20).weight(.semibold))
                            .foregroundColor(.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("@\(suggestion.user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Match percentage badge
                VStack(spacing: 2) {
                    Text("\(suggestion.matchPercentage)%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accent)
                    Text("Match")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bio
            if !suggestion.user.bio.isEmpty {
                Text(suggestion.user.bio)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }
            
            // Reason badge
            HStack(spacing: 6) {
                Image(systemName: reasonIcon(suggestion.reason))
                    .font(.caption2)
                Text(reasonText(suggestion.reason))
                    .font(.caption2)
            }
            .foregroundColor(.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accent.opacity(0.1))
            .cornerRadius(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats
            HStack(spacing: 12) {
                MinStatBadge(title: "Workouts", value: "\(suggestion.user.stats.totalWorkouts)")
                MinStatBadge(title: "PRs", value: "\(suggestion.user.stats.totalPRs)")
                MinStatBadge(title: "Streak", value: "\(suggestion.user.stats.currentStreak)d")
            }
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                }
                
                Button(action: {
                    isAdding = true
                    onAdd()
                    isAdded = true
                }) {
                    if isAdding {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else if isAdded {
                        Text("Added ✓")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accent.opacity(0.6))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    } else {
                        Text("Add")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accent)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
                }
                .disabled(isAdding || isAdded)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func reasonIcon(_ reason: FriendSuggestion.SuggestionReason) -> String {
        switch reason {
        case .sameGym:
            return "building.2"
        case .mutualFriends:
            return "person.2.badge.glow.fill"
        case .similarInterests:
            return "heart.fill"
        case .recentlyActive:
            return "bolt.fill"
        }
    }
    
    private func reasonText(_ reason: FriendSuggestion.SuggestionReason) -> String {
        switch reason {
        case .sameGym:
            return "Same gym"
        case .mutualFriends:
            return "Mutual friends"
        case .similarInterests:
            return "Similar interests"
        case .recentlyActive:
            return "Recently active"
        }
    }
}

// MARK: - Min Stat Badge

struct MinStatBadge: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.accent)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.accent.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    NavigationView {
        SuggestedFriendsView(viewModel: FriendViewModel())
    }
}
