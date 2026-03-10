import Foundation

class BadgeService {
    static let shared = BadgeService()
    
    private let supabaseService: SupabaseService
    
    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }
    
    private var badgeCache: [String: Bool] = [:]
    
    // MARK: - Badge Evaluation
    
    func evaluateBadges(
        for userId: String,
        challengeId: String,
        leaderboard: [ChallengeLeaderboardEntry]
    ) async -> [Badge] {
        var earnedBadges: [Badge] = []
        
        // Find user's current entry
        guard let userEntry = leaderboard.first(where: { $0.userId == userId }) else {
            return earnedBadges
        }
        
        // First Place Badge
        if userEntry.rank == 1 {
            if !badgeExists(name: "First Place", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "First Place",
                    description: "Won a challenge",
                    icon: "crown.fill",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // Podium Badge (Top 3)
        if userEntry.rank <= 3 {
            if !badgeExists(name: "Podium", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "Podium",
                    description: "Finished in the top 3",
                    icon: "medal.fill",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // Streak Master Badge (7+ day streak)
        if userEntry.streak >= 7 {
            if !badgeExists(name: "Streak Master", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "Streak Master",
                    description: "Maintained a 7-day streak",
                    icon: "flame.fill",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // Most Improved Badge (improved position since start)
        let initialRank = await getInitialRank(userId: userId, challengeId: challengeId)
        if let initial = initialRank, initial > userEntry.rank {
            if !badgeExists(name: "Most Improved", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "Most Improved",
                    description: "Climbed the leaderboard",
                    icon: "arrow.up.right",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // Consistency Badge (no missed days)
        let hasConsistentWorkouts = await checkConsistency(userId: userId, challengeId: challengeId)
        if hasConsistentWorkouts {
            if !badgeExists(name: "Consistency", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "Consistency",
                    description: "Never missed a day",
                    icon: "checkmark.circle.fill",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // PR Breaker Badge (set new personal record)
        let brokeNewPR = await checkPRBreak(userId: userId, challengeId: challengeId)
        if brokeNewPR {
            if !badgeExists(name: "PR Breaker", userId: userId, challengeId: challengeId) {
                earnedBadges.append(createBadge(
                    name: "PR Breaker",
                    description: "Set a new personal record",
                    icon: "bolt.fill",
                    userId: userId,
                    challengeId: challengeId
                ))
            }
        }
        
        // Save earned badges
        for badge in earnedBadges {
            try? await supabaseService.insert(badge, into: "badges")
        }
        
        return earnedBadges
    }
    
    // MARK: - Helper Methods
    
    private func createBadge(
        name: String,
        description: String,
        icon: String,
        userId: String,
        challengeId: String
    ) -> Badge {
        Badge(
            id: UUID().uuidString,
            name: name,
            description: description + " (Challenge: \(challengeId))",
            icon: icon,
            earnedDate: Date()
        )
    }
    
    private func badgeExists(name: String, userId: String, challengeId: String) -> Bool {
        // TODO: Implement badge existence check
        // This would fetch from database
        return false
    }
    
    private func getInitialRank(userId: String, challengeId: String) async -> Int? {
        // TODO: Fetch initial rank from challenge start
        return nil
    }
    
    private func checkConsistency(userId: String, challengeId: String) async -> Bool {
        // TODO: Check if user has worked out every day of the challenge
        return true
    }
    
    private func checkPRBreak(userId: String, challengeId: String) async -> Bool {
        // TODO: Check if user set a new personal record
        return false
    }
}
