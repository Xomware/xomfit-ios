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

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case caption
        case payload
        case visibility
        case createdAt = "created_at"
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
    /// Optional reply parent — present when the row is a reply to another comment.
    /// MIGRATION TODO (#320): add `parent_comment_id uuid null references feed_comments(id)`
    /// to the `feed_comments` table when threading is rolled out server-side.
    let parentCommentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case feedItemId = "feed_item_id"
        case userId = "user_id"
        case text
        case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"
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
    /// MIGRATION TODO (#320): backend column `parent_comment_id` must exist.
    /// When nil this is a top-level comment; otherwise it is a reply.
    let parent_comment_id: String?
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
            .select()
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        // Batch-fetch profiles for feed user names — concurrent to avoid serial N+1 (#359).
        let uniqueUserIds = Set(rows.map { $0.userId })
        let profileMap = await fetchProfileMap(for: uniqueUserIds)

        return rows.compactMap { row in
            buildSocialFeedItem(from: row, profile: profileMap[row.userId])
        }
    }

    // MARK: - Fetch User Feed

    func fetchUserFeed(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [SocialFeedItem] {
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        // Batch-fetch profiles for feed user names — concurrent to avoid serial N+1 (#359).
        let uniqueUserIds = Set(rows.map { $0.userId })
        let profileMap = await fetchProfileMap(for: uniqueUserIds)

        return rows.compactMap { row in
            buildSocialFeedItem(from: row, profile: profileMap[row.userId])
        }
    }

    // MARK: - Post Workout to Feed

    /// Posts a workout to the social feed.
    ///
    /// `compact` controls whether the per-set details (`ExerciseSummary.sets`) are
    /// encoded into the payload (#321). Feed cards only render summaries
    /// (`bestWeight`, `bestReps`, `setCount`, `isPR`), and `FeedDetailView` fetches
    /// the full workout via `WorkoutService.fetchWorkout`, so the per-set array
    /// is dead weight in the payload that bloats the row and the wire response.
    /// Defaults to `true` to avoid posting the bloat going forward; pass `false`
    /// only if a caller specifically needs the snapshot to round-trip through
    /// the feed payload (no current callers do).
    func postWorkoutToFeed(
        workout: Workout,
        userId: String,
        caption: String? = nil,
        photoURLs: [String]? = nil,
        compact: Bool = true
    ) async throws {
        let activity = buildWorkoutActivity(from: workout, photoURLs: photoURLs, compact: compact)

        let payloadData = try jsonEncoder.encode(activity)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        let insert = FeedItemInsert(
            id: UUID().uuidString,
            user_id: userId,
            activity_type: ActivityType.workout.rawValue,
            caption: caption,
            payload: payloadString,
            visibility: SocialFeedItem.FeedVisibility.friends.rawValue
        )

        try await supabase
            .from("feed_items")
            .insert(insert)
            .execute()
    }

    // MARK: - Update Feed Item for Workout (#365)

    /// Rewrites the payload of an existing workout-type feed item after the user
    /// edits the workout. Matches the same lookup strategy as
    /// `deleteFeedItemsForWorkout`: fetch the user's workout-type rows, decode
    /// each payload, find the one whose `workoutId` matches.
    ///
    /// If no feed item matches (e.g. workout was edited before the post-to-feed
    /// flow ran) this is a no-op.
    ///
    /// `caption` and `photoURLs` are preserved from the existing row when not
    /// passed in — only the activity payload is rebuilt from the new workout.
    func updateFeedItemForWorkout(
        workout: Workout,
        userId: String
    ) async throws {
        // Find existing workout-type feed items for this user
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select()
            .eq("user_id", value: userId)
            .eq("activity_type", value: ActivityType.workout.rawValue)
            .execute()
            .value

        // Pick the row whose payload's workoutId matches
        let match = rows.first { row in
            guard let data = row.payload.data(using: .utf8),
                  let activity = try? jsonDecoder.decode(WorkoutActivity.self, from: data) else {
                return false
            }
            return activity.workoutId == workout.id
        }

        guard let row = match else {
            // No existing feed post for this workout — nothing to update.
            return
        }

        // Preserve existing photoURLs from the prior payload so we don't drop
        // attached photos when rewriting the activity from the edited workout.
        let existingPhotoURLs: [String]? = {
            guard let data = row.payload.data(using: .utf8),
                  let activity = try? jsonDecoder.decode(WorkoutActivity.self, from: data) else {
                return nil
            }
            return activity.photoURLs
        }()

        let activity = buildWorkoutActivity(from: workout, photoURLs: existingPhotoURLs, compact: true)
        let payloadData = try jsonEncoder.encode(activity)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        try await supabase
            .from("feed_items")
            .update(["payload": payloadString])
            .eq("id", value: row.id)
            .execute()
    }

    /// Builds the `WorkoutActivity` payload shared by `postWorkoutToFeed` and
    /// `updateFeedItemForWorkout` so both call sites stay in lock-step on the
    /// compact-vs-full set encoding (#321).
    private func buildWorkoutActivity(
        from workout: Workout,
        photoURLs: [String]?,
        compact: Bool
    ) -> WorkoutActivity {
        let exercises = workout.exercises.map { ex in
            WorkoutActivity.ExerciseSummary(
                id: ex.id,
                name: ex.exercise.name,
                bestWeight: ex.bestSet?.weight ?? 0,
                bestReps: ex.bestSet?.reps ?? 0,
                isPR: ex.sets.contains { $0.isPersonalRecord },
                setCount: ex.sets.count,
                sets: compact ? nil : ex.sets.enumerated().map { index, set in
                    WorkoutActivity.ExerciseSummary.SetDetail(
                        setNumber: index + 1,
                        weight: set.weight,
                        reps: set.reps
                    )
                }
            )
        }

        // Now Playing capture teaser (#302). Skip when no tracks were captured so we
        // don't bloat the payload with empty fields for Spotify-only workouts.
        let trackCount: Int? = workout.tracks.isEmpty ? nil : workout.tracks.count
        let firstTrackTitle: String? = workout.tracks.first?.title

        return WorkoutActivity(
            workoutId: workout.id,
            workoutName: workout.name,
            duration: workout.duration,
            totalVolume: workout.totalVolume,
            totalSets: workout.totalSets,
            exerciseCount: workout.exercises.count,
            prCount: workout.totalPRs,
            exercises: exercises,
            location: workout.location,
            rating: workout.rating,
            photoURLs: photoURLs,
            trackCount: trackCount,
            firstTrackTitle: firstTrackTitle
        )
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
        do {
            try await supabase
                .from("feed_likes")
                .insert(insert)
                .execute()
        } catch {
            SyncManager.shared.enqueue(SyncOperation(
                type: .likeFeedItem,
                entityId: feedItemId,
                userId: userId
            ))
            throw error
        }
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

        // Batch-fetch commenter profiles concurrently so each comment shows the
        // correct username/avatar instead of a placeholder "User" (#359).
        let uniqueUserIds = Set(rows.map { $0.userId })
        let profileMap = await fetchProfileMap(for: uniqueUserIds)

        return rows.map { row in
            let date = iso8601.date(from: row.createdAt) ?? Date()
            let user = profileMap[row.userId].map { buildAppUser(from: $0) }
            return FeedComment(
                id: row.id,
                userId: row.userId,
                user: user,
                text: row.text,
                createdAt: date,
                parentCommentId: row.parentCommentId
            )
        }
    }

    /// Post a comment. When `parentCommentId` is non-nil this is a threaded reply (#320).
    func postComment(
        feedItemId: String,
        userId: String,
        text: String,
        parentCommentId: String? = nil
    ) async throws {
        let insert = FeedCommentInsert(
            id: UUID().uuidString,
            feed_item_id: feedItemId,
            user_id: userId,
            text: text,
            parent_comment_id: parentCommentId
        )
        do {
            try await supabase
                .from("feed_comments")
                .insert(insert)
                .execute()
        } catch {
            SyncManager.shared.enqueue(SyncOperation(
                type: .postComment,
                entityId: feedItemId,
                userId: userId,
                payload: text
            ))
            throw error
        }
    }

    // MARK: - Delete Feed Item

    func deleteFeedItem(id: String) async throws {
        try await supabase.from("feed_items").delete().eq("id", value: id).execute()
    }

    // MARK: - Update Caption

    func updateCaption(feedItemId: String, caption: String) async throws {
        try await supabase
            .from("feed_items")
            .update(["caption": caption])
            .eq("id", value: feedItemId)
            .execute()
    }

    // MARK: - Delete Feed Items for Workout

    /// Deletes feed items associated with a workout.
    /// Finds workout-type feed items for the given user and checks the payload for a matching workoutId.
    func deleteFeedItemsForWorkout(workoutId: String, userId: String) async throws {
        // Fetch all workout-type feed items for this user (no profile join needed)
        let rows: [FeedItemRow] = try await supabase
            .from("feed_items")
            .select()
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

    /// Concurrently fetches a `ProfileRow` for each unique user id and returns
    /// a `[userId: ProfileRow]` map. Failed fetches are skipped silently so a
    /// single deleted/blocked profile doesn't drop the rest of the feed (#359).
    private func fetchProfileMap(for userIds: Set<String>) async -> [String: ProfileRow] {
        await withTaskGroup(of: (String, ProfileRow?).self) { group in
            for uid in userIds {
                group.addTask {
                    (uid, try? await ProfileService.shared.fetchProfile(userId: uid))
                }
            }
            var map: [String: ProfileRow] = [:]
            for await (uid, profile) in group {
                if let profile { map[uid] = profile }
            }
            return map
        }
    }

    /// Builds an `AppUser` from a `ProfileRow`. Stats are zeroed because the
    /// feed/comments don't fetch aggregate stats per-user.
    private func buildAppUser(from profile: ProfileRow) -> AppUser {
        AppUser(
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
    }

    private func buildSocialFeedItem(from row: FeedItemRow, profile: ProfileRow? = nil) -> SocialFeedItem? {
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

        // Build AppUser from profile data, falling back to placeholder
        let user: AppUser
        if let profile {
            user = buildAppUser(from: profile)
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
