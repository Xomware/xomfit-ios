import Foundation
import Supabase

protocol APIServiceProtocol {
    func fetchFeed() async throws -> [FeedPost]
    func fetchFeedByFilter(_ filter: FeedFilter) async throws -> [FeedPost]
    func fetchWorkouts(userId: String) async throws -> [Workout]
    func fetchExercises() async throws -> [Exercise]
    func saveWorkout(_ workout: Workout) async throws -> Workout
    func fetchUser(id: String) async throws -> User
    func fetchPRs(userId: String) async throws -> [PersonalRecord]
    func likePost(_ postId: String) async throws
    func unlikePost(_ postId: String) async throws
    func commentOnPost(_ postId: String, comment: String) async throws
    func reactToPost(_ postId: String, emoji: String) async throws
}

class APIService: APIServiceProtocol {
    static let shared = APIService()
    private let baseURL = "https://api.xomfit.com/v1" // TODO: Configure
    private let supabaseClient = supabase
    
    func fetchFeed() async throws -> [FeedPost] {
        // TODO: Replace with real API call
        return FeedPost.mockFeed
    }
    
    func fetchFeedByFilter(_ filter: FeedFilter) async throws -> [FeedPost] {
        switch filter {
        case .friends:
            return try await fetchFriendsWorkouts()
        case .following:
            return try await fetchFollowingWorkouts()
        case .discover:
            return try await fetchDiscoverWorkouts()
        }
    }
    
    private func fetchFriendsWorkouts() async throws -> [FeedPost] {
        // TODO: Integrate with actual Supabase queries
        // For now, return mock data
        // Query would be:
        // SELECT w.*, u.*, e.* FROM workouts w
        // JOIN users u ON w.user_id = u.id
        // LEFT JOIN exercise_data e ON w.id = e.workout_id
        // WHERE w.is_shared_to_feed = true AND w.is_completed = true
        // AND w.user_id IN (friends)
        // ORDER BY w.created_at DESC LIMIT 50
        return FeedPost.mockFeed
    }
    
    private func fetchFollowingWorkouts() async throws -> [FeedPost] {
        // TODO: Integrate with actual Supabase queries
        // Query would filter by users being followed
        return FeedPost.mockFeed
    }
    
    private func fetchDiscoverWorkouts() async throws -> [FeedPost] {
        // TODO: Integrate with actual Supabase queries
        // Query would be for public workouts only
        return FeedPost.mockFeed
    }
    
    func fetchWorkouts(userId: String) async throws -> [Workout] {
        return [.mock]
    }
    
    func fetchExercises() async throws -> [Exercise] {
        return Exercise.mockExercises
    }
    
    func saveWorkout(_ workout: Workout) async throws -> Workout {
        // Save to Supabase
        let _ = try await supabaseClient
            .from("workouts")
            .insert([
                "id": workout.id,
                "user_id": workout.userId,
                "name": workout.name,
                "start_time": ISO8601DateFormatter().string(from: workout.startTime),
                "end_time": workout.endTime.map { ISO8601DateFormatter().string(from: $0) },
                "notes": workout.notes,
                "is_shared_to_feed": false,
                "is_completed": true,
                "is_public": false
            ])
            .execute()
        
        return workout
    }
    
    func fetchUser(id: String) async throws -> User {
        return .mock
    }
    
    func fetchPRs(userId: String) async throws -> [PersonalRecord] {
        return PersonalRecord.mockPRs
    }
    
    func likePost(_ postId: String) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        let _ = try await supabaseClient
            .from("feed_likes")
            .insert(["post_id": postId, "user_id": userId])
            .execute()
    }
    
    func unlikePost(_ postId: String) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        let _ = try await supabaseClient
            .from("feed_likes")
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    func commentOnPost(_ postId: String, comment: String) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        let _ = try await supabaseClient
            .from("feed_comments")
            .insert([
                "post_id": postId,
                "user_id": userId,
                "text": comment,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ])
            .execute()
    }
    
    func reactToPost(_ postId: String, emoji: String) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        let _ = try await supabaseClient
            .from("feed_reactions")
            .insert([
                "post_id": postId,
                "user_id": userId,
                "emoji": emoji
            ])
            .execute()
    }
    
    private func getCurrentUserId() async throws -> String? {
        guard let session = try await supabaseClient.auth.session else { return nil }
        return session.user.id.uuidString
    }
}
