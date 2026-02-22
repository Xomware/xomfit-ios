import Foundation

protocol APIServiceProtocol {
    func fetchFeed() async throws -> [FeedPost]
    func fetchWorkouts(userId: String) async throws -> [Workout]
    func fetchExercises() async throws -> [Exercise]
    func saveWorkout(_ workout: Workout) async throws -> Workout
    func fetchUser(id: String) async throws -> User
    func fetchPRs(userId: String) async throws -> [PersonalRecord]
}

class APIService: APIServiceProtocol {
    static let shared = APIService()
    private let baseURL = "https://api.xomfit.com/v1" // TODO: Configure
    
    func fetchFeed() async throws -> [FeedPost] {
        // TODO: Replace with real API call
        return FeedPost.mockFeed
    }
    
    func fetchWorkouts(userId: String) async throws -> [Workout] {
        return [.mock]
    }
    
    func fetchExercises() async throws -> [Exercise] {
        return Exercise.mockExercises
    }
    
    func saveWorkout(_ workout: Workout) async throws -> Workout {
        return workout
    }
    
    func fetchUser(id: String) async throws -> User {
        return .mock
    }
    
    func fetchPRs(userId: String) async throws -> [PersonalRecord] {
        return PersonalRecord.mockPRs
    }
}
