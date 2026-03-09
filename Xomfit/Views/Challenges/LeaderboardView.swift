import SwiftUI

struct LeaderboardView: View {
    let challengeDetail: ChallengeDetail
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                        Spacer()
                        Text("Leaderboard")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                    }
                    .padding()
                    
                    // Top 3 Podium
                    TopPodiumView(leaderboard: challengeDetail.leaderboard)
                        .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                
                // Leaderboard List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(challengeDetail.leaderboard) { entry in
                            LeaderboardRowView(
                                entry: entry,
                                isCurrentUser: challengeDetail.leaderboard.first { $0.rank == challengeDetail.currentUserRank } == entry
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Top Podium View
struct TopPodiumView: View {
    let leaderboard: [LeaderboardEntry]
    
    var body: some View {
        VStack(spacing: 16) {
            if leaderboard.count >= 3 {
                HStack(alignment: .bottom, spacing: 12) {
                    // Silver Medal (2nd)
                    if leaderboard.count >= 2 {
                        VStack(spacing: 8) {
                            PodiumPlaceView(
                                entry: leaderboard[1],
                                place: 2,
                                height: 120
                            )
                        }
                        .frame(height: 200)
                    }
                    
                    // Gold Medal (1st)
                    VStack(spacing: 8) {
                        PodiumPlaceView(
                            entry: leaderboard[0],
                            place: 1,
                            height: 160
                        )
                    }
                    .frame(height: 220)
                    
                    // Bronze Medal (3rd)
                    if leaderboard.count >= 3 {
                        VStack(spacing: 8) {
                            PodiumPlaceView(
                                entry: leaderboard[2],
                                place: 3,
                                height: 100
                            )
                        }
                        .frame(height: 190)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Podium Place View
struct PodiumPlaceView: View {
    let entry: LeaderboardEntry
    let place: Int
    let height: CGFloat
    
    var medalColor: Color {
        switch place {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .gray
        }
    }
    
    var medalIcon: String {
        switch place {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "star.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(entry.userName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            // Medal
            Image(systemName: medalIcon)
                .font(.system(size: 24))
                .foregroundColor(medalColor)
            
            // Name
            Text(entry.userName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            // Value
            Text(entry.formattedValue)
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Podium bar
            RoundedRectangle(cornerRadius: 4)
                .fill(medalColor.opacity(0.3))
                .frame(height: height)
                .overlay(
                    VStack {
                        Spacer()
                        Text("#\(place)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(medalColor)
                            .padding(.bottom, 8)
                    }
                )
        }
    }
}

// MARK: - Leaderboard Row View
struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("#\(entry.rank)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Avatar and Name
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(entry.userName.prefix(1)))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entry.userName)
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if entry.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(entry.streak) streak")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.formattedValue)
                        .font(.headline)
                    
                    if !entry.badges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(entry.badges.prefix(3)) { badge in
                                Image(systemName: badge.systemImage)
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                            if entry.badges.count > 3 {
                                Text("+\(entry.badges.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            
            // Highlight for current user
            if isCurrentUser {
                VStack {}
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.blue
        }
    }
}

// MARK: - Challenge Detail with Leaderboard
struct ChallengeDetailWithLeaderboard: View {
    @StateObject private var viewModel = ChallengeViewModel()
    let challengeId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            if let detail = viewModel.selectedChallenge {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detail.challenge.type.displayName)
                                .font(.system(size: 24, weight: .bold))
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Days Remaining")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(detail.challenge.daysRemaining)")
                                        .font(.headline)
                                }
                                
                                Divider()
                                    .frame(height: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Rank")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("#\(detail.currentUserRank ?? 0)")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                            }
                            
                            ProgressView(value: detail.challenge.progressPercentage)
                                .tint(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    // Leaderboard
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(detail.leaderboard) { entry in
                                LeaderboardRowView(
                                    entry: entry,
                                    isCurrentUser: entry.userId == viewModel.supabaseService.currentUserId
                                )
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await viewModel.fetchChallengeDetail(challengeId: challengeId)
        }
    }
}

#Preview {
    let mockLeaderboard = [
        LeaderboardEntry(
            id: "1",
            userId: "user1",
            userName: "John Doe",
            userAvatar: nil,
            rank: 1,
            value: 5000,
            unit: "lbs",
            streak: 7,
            badges: [
                Badge(id: "1", name: "First Place", description: "Won a challenge", icon: "crown.fill", earnedDate: Date())
            ]
        ),
        LeaderboardEntry(
            id: "2",
            userId: "user2",
            userName: "Jane Smith",
            userAvatar: nil,
            rank: 2,
            value: 4800,
            unit: "lbs",
            streak: 3,
            badges: []
        ),
        LeaderboardEntry(
            id: "3",
            userId: "user3",
            userName: "Mike Johnson",
            userAvatar: nil,
            rank: 3,
            value: 4600,
            unit: "lbs",
            streak: 0,
            badges: []
        )
    ]
    
    let mockChallenge = Challenge(
        id: "ch1",
        type: .mostVolume,
        status: .active,
        createdBy: "user1",
        participants: ["user1", "user2", "user3"],
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        results: [],
        createdAt: Date(),
        updatedAt: Date()
    )
    
    let mockDetail = ChallengeDetail(
        id: "ch1",
        challenge: mockChallenge,
        leaderboard: mockLeaderboard,
        currentUserRank: 2,
        currentUserValue: 4800,
        streaks: []
    )
    
    return LeaderboardView(challengeDetail: mockDetail)
}
