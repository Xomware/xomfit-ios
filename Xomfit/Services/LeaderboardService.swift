import Foundation

final class LeaderboardService {
    static let shared = LeaderboardService()
    private init() {}

    /// Fetches leaderboard entries by aggregating workout feed items from Supabase.
    func fetchLeaderboard(
        metric: LeaderboardMetric,
        timeframe: LeaderboardTimeframe,
        scope: LeaderboardScope,
        userId: String,
        muscleGroupFilter: MuscleGroup? = nil
    ) async throws -> [LeaderboardEntry] {
        // Build date filter
        let startDate: Date? = {
            let cal = Calendar.current
            let now = Date()
            switch timeframe {
            case .weekly: return cal.dateInterval(of: .weekOfYear, for: now)?.start
            case .monthly: return cal.dateInterval(of: .month, for: now)?.start
            case .allTime: return nil
            }
        }()

        // Get friend IDs for friends scope
        let friendIds: Set<String>?
        if scope == .friends {
            let friends = try await FriendsService.shared.fetchFriends(userId: userId)
            let ids = friends.map { $0.requesterId == userId ? $0.addresseeId : $0.requesterId }
            friendIds = Set(ids + [userId])
        } else {
            friendIds = nil
        }

        // Fetch workout feed items
        var query = supabase
            .from("feed_items")
            .select()
            .eq("activity_type", value: "workout")

        if let startDate {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query = query.gte("created_at", value: iso.string(from: startDate))
        }

        let response: [LeaderboardFeedRow] = try await query
            .order("created_at", ascending: false)
            .limit(500)
            .execute()
            .value

        // Aggregate by user
        var userScores: [String: (displayName: String, score: Int)] = [:]

        for row in response {
            // Scope filter
            if let friendIds, !friendIds.contains(row.user_id) { continue }

            guard let payloadData = row.payload.data(using: .utf8),
                  let activity = try? JSONDecoder().decode(WorkoutActivity.self, from: payloadData) else { continue }

            // Muscle group filter
            if let filter = muscleGroupFilter {
                let exerciseGroups = activity.exercises.flatMap { ex in
                    ExerciseDatabase.all.first(where: { $0.name == ex.name })?.muscleGroups ?? []
                }
                guard exerciseGroups.contains(filter) else { continue }
            }

            let score: Int = {
                switch metric {
                case .weeklyVolume: return Int(activity.totalVolume)
                case .personalRecords: return activity.prCount
                case .totalWorkouts: return 1
                case .workoutStreak: return 1 // approximation — streaks need separate tracking
                }
            }()

            let existing = userScores[row.user_id]
            userScores[row.user_id] = (
                displayName: existing?.displayName ?? row.user_id,
                score: (existing?.score ?? 0) + score
            )
        }

        // Resolve display names
        let userIds = Array(userScores.keys)
        if !userIds.isEmpty {
            let profiles: [LeaderboardProfile] = try await supabase
                .from("profiles")
                .select("id, display_name, username")
                .in("id", values: userIds)
                .execute()
                .value

            for profile in profiles {
                if var entry = userScores[profile.id] {
                    entry.displayName = profile.display_name.isEmpty ? profile.username : profile.display_name
                    userScores[profile.id] = entry
                }
            }
        }

        // Sort and rank
        let sorted = userScores.sorted { $0.value.score > $1.value.score }
        return sorted.enumerated().map { rank, pair in
            LeaderboardEntry(
                userId: pair.key,
                displayName: pair.value.displayName,
                rank: rank + 1,
                score: pair.value.score,
                metric: metric
            )
        }
    }
}

// MARK: - Supabase DTOs

private struct LeaderboardFeedRow: Decodable {
    let user_id: String
    let payload: String
    let created_at: String
}

private struct LeaderboardProfile: Decodable {
    let id: String
    let display_name: String
    let username: String
}
