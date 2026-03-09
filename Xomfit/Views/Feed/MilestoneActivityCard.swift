import SwiftUI

struct MilestoneActivityCard: View {
    let user: User
    let milestone: Milestone
    @State private var isLiked = false
    @State private var likes: Int
    
    init(user: User, milestone: Milestone, initialLikes: Int = 0) {
        self.user = user
        self.milestone = milestone
        self._likes = State(initialValue: initialLikes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Header
            HStack(spacing: Theme.paddingSmall) {
                Circle()
                    .fill(milestone.color.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(milestone.color)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(milestone.description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(milestone.date.timeAgoDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            // Milestone banner
            VStack(spacing: Theme.paddingSmall) {
                HStack(spacing: Theme.paddingMedium) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(milestone.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(milestone.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: milestone.icon)
                            .font(.system(size: 28))
                            .foregroundColor(milestone.color)
                        
                        Text(milestone.badge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(milestone.color)
                    }
                    .padding(Theme.paddingMedium)
                    .background(milestone.color.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(Theme.paddingMedium)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
            
            // Achievement details
            if !milestone.details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(milestone.details, id: \.self) { detail in
                        HStack(spacing: Theme.paddingSmall) {
                            Circle()
                                .fill(milestone.color)
                                .frame(width: 4, height: 4)
                            Text(detail)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
            
            // Engagement
            HStack(spacing: Theme.paddingMedium) {
                Button(action: {
                    isLiked.toggle()
                    likes += isLiked ? 1 : -1
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
                        Text("Congrats")
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

// MARK: - Milestone Model

struct Milestone: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let badge: String
    let color: Color
    let details: [String]
    let date: Date
    
    // Preset milestones
    static let workoutStreak = Milestone(
        id: "milestone-streak",
        title: "7-Day Streak",
        subtitle: "7 consecutive workouts",
        description: "reached a 7-day streak!",
        icon: "flame.fill",
        badge: "🔥 Hot",
        color: Color(red: 1.0, green: 0.6, blue: 0),
        details: [
            "Consistency is key to progress",
            "Keep up the momentum!",
            "Next target: 14-day streak"
        ],
        date: Date()
    )
    
    static let volumeMilestone = Milestone(
        id: "milestone-volume",
        title: "250k Volume",
        subtitle: "100,000 lbs lifted this month",
        description: "hit 250k total volume!",
        icon: "scalemass.fill",
        badge: "📊 Beast",
        color: Theme.accentColor,
        details: [
            "Incredible volume accumulation",
            "That's 125 tons of total weight!",
            "You're crushing it"
        ],
        date: Date().addingTimeInterval(-86400)
    )
    
    static let prMilestone = Milestone(
        id: "milestone-pr",
        title: "25 Personal Records",
        subtitle: "25 new max lifts achieved",
        description: "broke their 25th personal record!",
        icon: "star.fill",
        badge: "⭐ Strong",
        color: Color(red: 1.0, green: 0.84, blue: 0),
        details: [
            "Each PR represents strength growth",
            "Keep pushing those limits",
            "Aim for 50 PRs!"
        ],
        date: Date().addingTimeInterval(-86400 * 2)
    )
}

#Preview {
    VStack(spacing: Theme.paddingMedium) {
        MilestoneActivityCard(
            user: .mockFriend,
            milestone: .workoutStreak,
            initialLikes: 18
        )
        
        MilestoneActivityCard(
            user: .mock,
            milestone: .volumeMilestone,
            initialLikes: 32
        )
        
        MilestoneActivityCard(
            user: .mockFriend,
            milestone: .prMilestone,
            initialLikes: 25
        )
    }
    .padding()
    .background(Theme.background)
}
