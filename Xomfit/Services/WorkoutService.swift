import Foundation

@MainActor
final class WorkoutService {
    static let shared = WorkoutService()

    private let storageKey = "xomfit_workouts"

    private init() {}

    // MARK: - Save

    func saveWorkout(_ workout: Workout) async throws {
        var workouts = fetchWorkouts()
        // Replace if exists, otherwise append
        if let idx = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[idx] = workout
        } else {
            workouts.insert(workout, at: 0)
        }
        let data = try JSONEncoder().encode(workouts)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Fetch

    func fetchWorkouts() -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let workouts = (try? JSONDecoder().decode([Workout].self, from: data)) ?? []
        return workouts.sorted { $0.startTime > $1.startTime }
    }

    func fetchWorkouts(userId: String) -> [Workout] {
        fetchWorkouts().filter { $0.userId == userId }
    }

    // MARK: - Delete

    func deleteWorkout(id: String) {
        var workouts = fetchWorkouts()
        workouts.removeAll { $0.id == id }
        let data = try? JSONEncoder().encode(workouts)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
