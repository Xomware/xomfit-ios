import Foundation

class StreakService {
    static let shared = StreakService()
    
    private let supabaseService: SupabaseService
    
    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }
    
    // MARK: - Streak Management
    
    @discardableResult
    func updateStreak(
        userId: String,
        challengeId: String
    ) async -> Streak? {
        // Fetch or create streak entry
        var streak = try? await getOrCreateStreak(userId: userId, challengeId: challengeId)
        
        guard var streak = streak else {
            return createNewStreak(userId: userId, challengeId: challengeId)
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastWorkoutDay = Calendar.current.startOfDay(for: streak.lastWorkoutDate)
        let daysDifference = Calendar.current.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0
        
        // Same day - no change to streak
        if daysDifference == 0 {
            return streak
        }
        
        // Next day - increment streak
        if daysDifference == 1 {
            streak.count += 1
        }
        
        // Missed a day - reset streak (but don't break it if just checking after a gap)
        if daysDifference > 1 {
            // Only reset if we're past a day without activity
            streak.count = 1
        }
        
        // Update last workout date
        let updatedStreak = Streak(
            id: streak.id,
            userId: userId,
            challengeId: challengeId,
            count: streak.count,
            lastWorkoutDate: Date()
        )
        
        try? await supabaseService.update(updatedStreak, in: "streaks", where: "id", equals: streak.id)
        
        return updatedStreak
    }
    
    func checkAndResetExpiredStreaks(userId: String, challengeId: String) async -> Streak? {
        guard let streak = try? await getOrCreateStreak(userId: userId, challengeId: challengeId) else {
            return nil
        }
        
        let daysSinceLastWorkout = Calendar.current.dateComponents(
            [.day],
            from: streak.lastWorkoutDate,
            to: Date()
        ).day ?? 0
        
        // Reset streak if more than 1 day has passed
        if daysSinceLastWorkout > 1 && streak.count > 0 {
            let resetStreak = Streak(
                id: streak.id,
                userId: userId,
                challengeId: challengeId,
                count: 0,
                lastWorkoutDate: Date()
            )
            
            try? await supabaseService.update(resetStreak, in: "streaks", where: "id", equals: streak.id)
            return resetStreak
        }
        
        return streak
    }
    
    func getStreak(userId: String, challengeId: String) async -> Streak? {
        do {
            let streaks = try await supabaseService.fetch(
                Streak.self,
                from: "streaks",
                where: "userId", equals: userId
            )
            return streaks.first(where: { $0.challengeId == challengeId })
        } catch {
            return nil
        }
    }
    
    func getAllStreaks(for challengeId: String) async -> [Streak] {
        do {
            return try await supabaseService.fetch(
                Streak.self,
                from: "streaks",
                where: "challengeId", equals: challengeId
            )
        } catch {
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func getOrCreateStreak(userId: String, challengeId: String) async throws -> Streak? {
        let streaks = try await supabaseService.fetch(
            Streak.self,
            from: "streaks",
            where: "userId", equals: userId
        )
        return streaks.first(where: { $0.challengeId == challengeId })
    }
    
    private func createNewStreak(userId: String, challengeId: String) -> Streak {
        let streak = Streak(
            id: UUID().uuidString,
            userId: userId,
            challengeId: challengeId,
            count: 1,
            lastWorkoutDate: Date()
        )
        
        Task {
            try? await supabaseService.insert(streak, into: "streaks")
        }
        
        return streak
    }
}

// MARK: - Extension for Streak helpers
extension Streak {
    var daysRemainingInStreak: Int {
        let daysSince = Calendar.current.dateComponents([.day], from: lastWorkoutDate, to: Date()).day ?? 0
        return max(0, 1 - daysSince)  // If 1+ days have passed, streak is at risk
    }
    
    var streakStatus: StreakStatus {
        let daysSince = Calendar.current.dateComponents([.day], from: lastWorkoutDate, to: Date()).day ?? 0
        
        if daysSince == 0 {
            return .active
        } else if daysSince == 1 {
            return .atRisk
        } else {
            return .broken
        }
    }
}

enum StreakStatus {
    case active      // Workout today
    case atRisk      // Missed today, but can recover tomorrow
    case broken      // Missed 2+ days
}
