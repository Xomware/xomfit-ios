import SwiftUI

struct PRActivityCard: View {
    let user: AppUser
    let pr: PersonalRecord
    let onLikeTap: () -> Void
    @State private var isLiked = false
    @State private var likes = 42
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Header
            HStack(spacing: Theme.paddingSmall) {
                Circle()
                    .fill(Theme.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.accentColor)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Hit a new personal record!")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(pr.date.timeAgoDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            // PR announcement
            VStack(spacing: Theme.paddingMedium) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEW PR!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accentColor)
                        
                        Text(pr.exerciseName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: Theme.paddingMedium) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                HStack(spacing: 0) {
                                    Text("\(Int(pr.weight))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(" lbs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reps")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                Text("\(pr.reps)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Improvement badge
                    if let improvement = pr.improvement, improvement > 0 {
                        VStack(alignment: .center, spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.accentColor)
                            
                            Text("+\(Int(improvement))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("from last")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, Theme.paddingSmall)
                        .padding(.vertical, 12)
                        .background(Theme.accentColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(Theme.paddingMedium)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
            
            // Stats
            HStack(spacing: Theme.paddingMedium) {
                PRStatBadge(label: "Total PRs", value: "\(user.stats.totalPRs)")
                PRStatBadge(label: "Streak", value: "\(user.stats.currentStreak)d")
                PRStatBadge(label: "Workouts", value: "\(user.stats.totalWorkouts)")
                Spacer()
            }
            
            // Engagement
            HStack(spacing: Theme.paddingMedium) {
                Button(action: {
                    isLiked.toggle()
                    likes += isLiked ? 1 : -1
                    onLikeTap()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("\(likes)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("Comment")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .foregroundColor(.gray)
                        Text("Share")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.paddingMedium)
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Support Views

struct PRStatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

#Preview {
    PRActivityCard(
        user: .mockFriend,
        pr: .mockPRs[0],
        onLikeTap: {}
    )
    .padding()
    .background(Theme.background)
}
