import Foundation
import Supabase

// MARK: - DB Row Types

struct FeedItemRow: Codable {
    let id: String
    let userId: String
    let activityType: String
    let caption: String?
    let payload: String       // JSON-encoded payload blob stored as text
    let visibility: String
    let createdAt: String
    let profiles: ProfileRow?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case caption
        case payload
        case visibility
        case createdAt = "created_at"
        case profiles
    }
}

struct FeedLikeRow: Codable {
    let id: String
    let feedItemId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id
        case feedItemId = "feed_item_id"
        case userId = "user_id"
    }
}

struct FeedCommentRow: Codable {
    let id: String
    let feedItemId: String
    let userId: String
    let text: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case feedItemId = "feed_item_id"
        case userId = "user_id"
        case text
        case createdAt = "created_at"
    }
}

// MARK: - Insert Payloads

private struct FeedItemInsert: Encodable {
    let id: String
    let user_id: String
    let activity_type: String
    let caption: String?
    let payload: String
    let visibility: String
}

private struct FeedLikeInsert: Encodable {
    let id: String
    let feed_item_id: String
    let user_id: String
}

private struct FeedCommentInsert: Encodable {
    let id: String
    let feed_item_id: String
    let user_id: String
    let text: String
}

// MARK: - FeedService

@MainActor
final class FeedService {
    static let shared = FeedService()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {}

    // MARK: - Fetch Feed

    func fetchFeed(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [SocialFeedItem] {
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select("*, profiles!feed_items_user_id_fkey(*)")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.compactMap { row in
            buildSocialFeedItem(from: row)
        }
    }

    // MARK: - Fetch User Feed

    func fetchUserFeed(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [SocialFeedItem] {
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select("*, profiles!feed_items_user_id_fkey(*)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.compactMap { row in
            buildSocialFeedItem(from: row)
        }
    }

    // MARK: - Post Workout to Feed

    func postWorkoutToFeed(workout: Workout, userId: String) async throws {
        let exercises = workout.exercises.map { ex in
            WorkoutActivity.ExerciseSummary(
                id: ex.id,
                name: ex.exercise.name,
                bestWeight: ex.bestSet?.weight ?? 0,
                bestReps: ex.bestSet?.reps ?? 0,
                isPR: ex.sets.contains { $0.isPersonalRecord }
            )
        }

        let activity = WorkoutActivity(
            workoutId: workout.id,
            workoutName: workout.name,
            duration: workout.duration,
            totalVolume: workout.totalVolume,
            totalSets: workout.totalSets,
            exerciseCount: workout.exercises.count,
            prCount: workout.totalPRs,
            exercises: exercises
        )

        let payloadData = try jsonEncoder.encode(activity)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        let insert = FeedItemInsert(
            id: UUID().uuidString,
            user_id: userId,
            activity_type: ActivityType.workout.rawValue,
            caption: nil,
            payload: payloadString,
            visibility: SocialFeedItem.FeedVisibility.friends.rawValue
        )

        try await supabase
            .from("feed_items")
            .insert(insert)
            .execute()
    }

    // MARK: - Post Generic Item

    func postToFeed(
        userId: String,
        activityType: ActivityType,
        caption: String?,
        payloadEncodable: some Encodable,
        visibility: SocialFeedItem.FeedVisibility = .friends
    ) async throws {
        let payloadData = try jsonEncoder.encode(payloadEncodable)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        let insert = FeedItemInsert(
            id: UUID().uuidString,
            user_id: userId,
            activity_type: activityType.rawValue,
            caption: caption,
            payload: payloadString,
            visibility: visibility.rawValue
        )

        try await supabase
            .from("feed_items")
            .insert(insert)
            .execute()
    }

    // MARK: - Like / Unlike

    func likeFeedItem(feedItemId: String, userId: String) async throws {
        let insert = FeedLikeInsert(
            id: UUID().uuidString,
            feed_item_id: feedItemId,
            user_id: userId
        )
        try await supabase
            .from("feed_likes")
            .insert(insert)
            .execute()
    }

    func unlikeFeedItem(feedItemId: String, userId: String) async throws {
        try await supabase
            .from("feed_likes")
            .delete()
            .eq("feed_item_id", value: feedItemId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Comments

    func fetchComments(feedItemId: String) async throws -> [FeedComment] {
        let rows: [FeedCommentRow] = try await supabase
            .from("feed_comments")
            .select()
            .eq("feed_item_id", value: feedItemId)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            let date = iso8601.date(from: row.createdAt) ?? Date()
            return FeedComment(
                id: row.id,
                userId: row.userId,
                user: nil,
                text: row.text,
                createdAt: date
            )
        }
    }

    func postComment(feedItemId: String, userId: String, text: String) async throws {
        let insert = FeedCommentInsert(
            id: UUID().uuidString,
            feed_item_id: feedItemId,
            user_id: userId,
            text: text
        )
        try await supabase
            .from("feed_comments")
            .insert(insert)
            .execute()
    }

    // MARK: - Delete Feed Items for Workout

    /// Deletes feed items associated with a workout.
    /// Finds workout-type feed items for the given user and checks the payload for a matching workoutId.
    func deleteFeedItemsForWorkout(workoutId: String, userId: String) async throws {
        // Fetch all workout-type feed items for this user (no profile join needed)
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select("*, profiles!feed_items_user_id_fkey(*)")
            .eq("user_id", value: userId)
            .eq("activity_type", value: ActivityType.workout.rawValue)
            .execute()
            .value

        // Find rows whose payload contains the matching workoutId
        let matchingIds = rows.compactMap { row -> String? in
            guard let data = row.payload.data(using: .utf8),
                  let activity = try? jsonDecoder.decode(WorkoutActivity.self, from: data),
                  activity.workoutId == workoutId else {
                return nil
            }
            return row.id
        }

        // Delete matching feed items
        for feedItemId in matchingIds {
            try await supabase
                .from("feed_items")
                .delete()
                .eq("id", value: feedItemId)
                .execute()
        }
    }

    // MARK: - Private Helpers

    private func buildSocialFeedItem(from row: FeedItemRow) -> SocialFeedItem? {
        guard let activityType = ActivityType(rawValue: row.activityType) else { return nil }
        let createdAt = iso8601.date(from: row.createdAt) ?? Date()
        let visibility = SocialFeedItem.FeedVisibility(rawValue: row.visibility) ?? .friends
        let payloadData = row.payload.data(using: .utf8) ?? Data()

        // Decode the activity payload
        var workoutActivity: WorkoutActivity? = nil
        var prActivity: PRActivity? = nil
        var milestoneActivity: MilestoneActivity? = nil
        var streakActivity: StreakActivity? = nil

        switch activityType {
        case .workout:
            workoutActivity = try? jsonDecoder.decode(WorkoutActivity.self, from: payloadData)
        case .personalRecord:
            prActivity = try? jsonDecoder.decode(PRActivity.self, from: payloadData)
        case .milestone:
            milestoneActivity = try? jsonDecoder.decode(MilestoneActivity.self, from: payloadData)
        case .streak:
            streakActivity = try? jsonDecoder.decode(StreakActivity.self, from: payloadData)
        }

        // Build AppUser from joined profile data, falling back to placeholder
        let user: AppUser
        if let profile = row.profiles {
            user = AppUser(
                id: profile.id,
                username: profile.username,
                displayName: profile.displayName,
                avatarURL: profile.avatarURL,
                bio: profile.bio,
                stats: AppUser.UserStats(
                    totalWorkouts: 0,
                    totalVolume: 0,
                    totalPRs: 0,
                    currentStreak: 0,
                    longestStreak: 0,
                    favoriteExercise: nil
                ),
                isPrivate: profile.isPrivate,
                createdAt: Date()
            )
        } else {
            user = AppUser(
                id: row.userId,
                username: "",
                displayName: "User",
                avatarURL: nil,
                bio: "",
                stats: AppUser.UserStats(
                    totalWorkouts: 0,
                    totalVolume: 0,
                    totalPRs: 0,
                    currentStreak: 0,
                    longestStreak: 0,
                    favoriteExercise: nil
                ),
                isPrivate: false,
                createdAt: Date()
            )
        }

        return SocialFeedItem(
            id: row.id,
            userId: row.userId,
            activityType: activityType,
            createdAt: createdAt,
            user: user,
            likes: 0,          // Like counts fetched separately / via DB view
            isLiked: false,
            comments: [],
            workoutActivity: workoutActivity,
            prActivity: prActivity,
            milestoneActivity: milestoneActivity,
            streakActivity: streakActivity,
            caption: row.caption,
            visibility: visibility
        )
    }
}
