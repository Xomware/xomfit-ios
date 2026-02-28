import Foundation
import SwiftUI

/// Badge achievement system for challenges
class BadgeSystem {
    static let shared = BadgeSystem()
    
    // MARK: - Badge Types
    
    enum BadgeType: String, Codable {
        case firstPlace = "first_place"
        case secondPlace = "second_place"
        case thirdPlace = "third_place"
        case streakMaster = "streak_master"
        case consistencyKing = "consistency_king"
        case mostImproved = "most_improved"
        case prBreaker = "pr_breaker"
        case challengeCreator = "challenge_creator"
        case allStar = "all_star"
        case marathoner = "marathoner"
        case speedDemon = "speed_demon"
    }
    
    private var earnedBadges: [String: Set<BadgeType>] = [:]
    
    // MARK: - Public Methods
    
    /// Check if a user has earned a badge
    func hasBadge(_ type: BadgeType, for userId: String) -> Bool {
        return earnedBadges[userId]?.contains(type) ?? false
    }
    
    /// Get all earned badges for a user
    func getBadges(for userId: String) -> [Badge] {
        let badgeTypes = earnedBadges[userId] ?? []
        return badgeTypes.map { createBadge(for: $0) }
    }
    
    /// Award a badge to a user
    func awardBadge(_ type: BadgeType, to userId: String) -> Badge? {
        if !hasBadge(type, for: userId) {
            if earnedBadges[userId] == nil {
                earnedBadges[userId] = []
            }
            earnedBadges[userId]?.insert(type)
            return createBadge(for: type, earnedDate: Date())
        }
        return nil
    }
    
    /// Check and award badges based on challenge results
    func checkAndAwardBadges(for results: [LeaderboardEntry], challengeType: ChallengeType) -> [String: [Badge]] {
        var awardedBadges: [String: [Badge]] = [:]
        
        guard let topPerformer = results.first else { return awardedBadges }
        
        // Award placement badges
        if let badge = awardBadge(.firstPlace, to: topPerformer.userId) {
            awardedBadges[topPerformer.userId, default: []].append(badge)
        }
        
        if results.count >= 2, let badge = awardBadge(.secondPlace, to: results[1].userId) {
            awardedBadges[results[1].userId, default: []].append(badge)
        }
        
        if results.count >= 3, let badge = awardBadge(.thirdPlace, to: results[2].userId) {
            awardedBadges[results[2].userId, default: []].append(badge)
        }
        
        // Award streak badges
        for result in results {
            if result.streak >= 7, let badge = awardBadge(.streakMaster, to: result.userId) {
                awardedBadges[result.userId, default: []].append(badge)
            }
        }
        
        // Award challenge creator badge
        // (This would be handled separately when creating a challenge)
        
        // Award most improved badge
        // (This requires historical data comparison)
        
        return awardedBadges
    }
    
    /// Check for streak badges
    func checkStreakBadges(userId: String, streakCount: Int) -> [Badge] {
        var badges: [Badge] = []
        
        let streakMilestones = [7, 14, 30, 60, 100]
        for milestone in streakMilestones {
            if streakCount >= milestone {
                let badgeType: BadgeType = {
                    switch milestone {
                    case 7: return .streakMaster
                    case 14: return .consistencyKing
                    case 30, 60, 100: return .marathoner
                    default: return .streakMaster
                    }
                }()
                
                if let badge = awardBadge(badgeType, to: userId) {
                    badges.append(badge)
                }
            }
        }
        
        return badges
    }
    
    /// Check for PR-related badges
    func checkPRBadges(userId: String, prCount: Int) -> [Badge]? {
        if prCount >= 5 {
            return [awardBadge(.prBreaker, to: userId)].compactMap { $0 }
        }
        return nil
    }
    
    /// Award all-star badge for participating in multiple challenges
    func checkAllStarBadge(userId: String, completedChallenges: Int) -> Badge? {
        if completedChallenges >= 5 {
            return awardBadge(.allStar, to: userId)
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func createBadge(
        for type: BadgeType,
        earnedDate: Date = Date()
    ) -> Badge {
        let (name, description, icon) = badgeInfo(for: type)
        return Badge(
            id: UUID().uuidString,
            name: name,
            description: description,
            icon: icon,
            earnedDate: earnedDate
        )
    }
    
    private func badgeInfo(for type: BadgeType) -> (name: String, description: String, icon: String) {
        switch type {
        case .firstPlace:
            return (
                "First Place",
                "Won a challenge",
                "crown.fill"
            )
        case .secondPlace:
            return (
                "Runner-Up",
                "Placed 2nd in a challenge",
                "medal.fill"
            )
        case .thirdPlace:
            return (
                "Podium Finisher",
                "Placed 3rd in a challenge",
                "medal.fill"
            )
        case .streakMaster:
            return (
                "Streak Master",
                "Maintained a 7-day streak",
                "flame.fill"
            )
        case .consistencyKing:
            return (
                "Consistency King",
                "Maintained a 14-day streak",
                "checkmark.circle.fill"
            )
        case .mostImproved:
            return (
                "Most Improved",
                "Showed the greatest improvement",
                "arrow.up.right"
            )
        case .prBreaker:
            return (
                "PR Breaker",
                "Set 5+ personal records",
                "bolt.fill"
            )
        case .challengeCreator:
            return (
                "Challenge Creator",
                "Created your first challenge",
                "sparkles"
            )
        case .allStar:
            return (
                "All-Star",
                "Completed 5+ challenges",
                "star.fill"
            )
        case .marathoner:
            return (
                "Marathoner",
                "Maintained a 30+ day streak",
                "figure.walk"
            )
        case .speedDemon:
            return (
                "Speed Demon",
                "Achieved fastest time in fastest mile",
                "hare.fill"
            )
        }
    }
}

// MARK: - Badge View
struct BadgeDisplayView: View {
    let badge: Badge
    let size: CGFloat = 48
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: badge.systemImage)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.orange)
            }
            
            Text(badge.name)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(badge.description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Badge Collection View
struct BadgeCollectionView: View {
    let badges: [Badge]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
            
            if badges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No badges earned yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeDisplayView(badge: badge)
                    }
                }
            }
        }
    }
}

// MARK: - Badge Notification
struct BadgeNotificationView: View {
    let badge: Badge
    @State private var isShowing = true
    
    var body: some View {
        if isShowing {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: badge.systemImage)
                                .foregroundColor(.orange)
                            Text("Badge Earned!")
                                .font(.headline)
                        }
                        Text(badge.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { withAnimation { isShowing = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .transition(.move(edge: .bottom))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BadgeDisplayView(
            badge: Badge(
                id: "1",
                name: "First Place",
                description: "Won a challenge",
                icon: "crown.fill",
                earnedDate: Date()
            )
        )
        
        BadgeCollectionView(
            badges: [
                Badge(id: "1", name: "First Place", description: "Won a challenge", icon: "crown.fill", earnedDate: Date()),
                Badge(id: "2", name: "Streak Master", description: "7-day streak", icon: "flame.fill", earnedDate: Date()),
                Badge(id: "3", name: "PR Breaker", description: "5+ PRs", icon: "bolt.fill", earnedDate: Date())
            ]
        )
    }
    .padding()
}
