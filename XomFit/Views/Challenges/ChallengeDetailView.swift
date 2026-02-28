import SwiftUI

struct ChallengeDetailView: View {
    let challengeDetail: ChallengeDetail
    @State private var showLeaderboard = false
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
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(challengeDetail.challenge.type.displayName)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text(challengeDetail.challenge.type.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Key Stats
                        HStack(spacing: 16) {
                            // Days Remaining
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Days Left")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(challengeDetail.challenge.daysRemaining)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Divider()
                                .frame(height: 30)
                            
                            // Your Rank
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Rank")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("#\(challengeDetail.currentUserRank ?? 0)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            Divider()
                                .frame(height: 30)
                            
                            // Your Value
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Total")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if let value = challengeDetail.currentUserValue {
                                    Text(String(format: "%.0f", value))
                                        .font(.headline)
                                } else {
                                    Text("—")
                                        .font(.headline)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Progress bar
                        ProgressView(value: challengeDetail.challenge.progressPercentage)
                            .tint(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
                }
                .background(Color(.systemBackground))
                
                // Tabs
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        // Streaks Tab
                        VStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            
                            Text("Streaks")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        
                        Spacer()
                        
                        // Leaderboard Tab
                        VStack(spacing: 8) {
                            Image(systemName: "list.number")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            Text("Leaderboard")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onTapGesture {
                            showLeaderboard = true
                        }
                    }
                    .padding()
                    
                    // Streaks View
                    ScrollView {
                        VStack(spacing: 8) {
                            if challengeDetail.streaks.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "flame.circle")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                    Text("No Streaks Yet")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                ForEach(challengeDetail.streaks) { streak in
                                    StreakRowView(streak: streak)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(challengeDetail: challengeDetail)
        }
    }
}

// MARK: - Streak Row View
struct StreakRowView: View {
    let streak: Streak
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    
                    Text("\(streak.count)-Day Streak")
                        .font(.headline)
                }
                
                Text("Last workout: \(streak.lastWorkoutDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(streakStatusColor)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var streakStatusColor: Color {
        switch streak.streakStatus {
        case .active:
            return .green
        case .atRisk:
            return .orange
        case .broken:
            return .red
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
        )
    ]
    
    let mockChallenge = Challenge(
        id: "ch1",
        type: .mostVolume,
        status: .active,
        createdBy: "user1",
        participants: ["user1"],
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
        currentUserRank: 1,
        currentUserValue: 5000,
        streaks: [
            Streak(id: "s1", userId: "user1", challengeId: "ch1", count: 7, lastWorkoutDate: Date())
        ]
    )
    
    return ChallengeDetailView(challengeDetail: mockDetail)
}
