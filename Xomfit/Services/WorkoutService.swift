import Foundation
import Supabase

// MARK: - Supabase Row Types

private struct WorkoutRow: Codable {
    let id: String
    let userId: String
    let name: String
    let startTime: String
    let endTime: String?
    let notes: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case createdAt = "created_at"
    }
}

private struct WorkoutExerciseRow: Codable {
    let id: String
    let workoutId: String
    let exerciseId: String
    let exerciseName: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sortOrder = "sort_order"
    }
}

private struct WorkoutSetRow: Codable {
    let id: String
    let workoutExerciseId: String
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rpe: Double?
    let isCompleted: Bool
    let isPr: Bool
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutExerciseId = "workout_exercise_id"
        case setNumber = "set_number"
        case weight
        case reps
        case rpe
        case isCompleted = "is_completed"
        case isPr = "is_pr"
        case completedAt = "completed_at"
    }
}

// MARK: - Nested Fetch Response

private struct WorkoutWithRelations: Codable {
    let id: String
    let userId: String
    let name: String
    let startTime: String
    let endTime: String?
    let notes: String?
    let createdAt: String?
    let workoutExercises: [ExerciseWithSets]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case createdAt = "created_at"
        case workoutExercises = "workout_exercises"
    }
}

private struct ExerciseWithSets: Codable {
    let id: String
    let workoutId: String
    let exerciseId: String
    let exerciseName: String
    let sortOrder: Int
    let workoutSets: [WorkoutSetRow]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sortOrder = "sort_order"
        case workoutSets = "workout_sets"
    }
}

// MARK: - Insert Payloads

private struct WorkoutInsertPayload: Encodable {
    let id: String
    let user_id: String
    let name: String
    let start_time: String
    let end_time: String?
    let notes: String?
}

private struct WorkoutExerciseInsertPayload: Encodable {
    let id: String
    let workout_id: String
    let exercise_id: String
    let exercise_name: String
    let sort_order: Int
}

private struct WorkoutSetInsertPayload: Encodable {
    let id: String
    let workout_exercise_id: String
    let set_number: Int
    let weight: Double
    let reps: Int
    let rpe: Double?
    let is_completed: Bool
    let is_pr: Bool
    let completed_at: String?
}

// MARK: - WorkoutService

@MainActor
final class WorkoutService {
    static let shared = WorkoutService()

    private let storageKey = "xomfit_workouts"

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    // MARK: - Save

    /// Saves a workout. Always writes to local cache; attempts Supabase write and queues for retry on failure.
    /// Returns `true` if the Supabase write succeeded, `false` if it was queued. Never throws.
    @discardableResult
    func saveWorkout(_ workout: Workout) async -> Bool {
        // Save to UserDefaults first (instant, always works)
        saveToCache(workout)

        // Push to Supabase (async, non-blocking on failure)
        do {
            try await saveToSupabase(workout)
            return true
        } catch {
            print("[WorkoutService] Supabase save failed, queuing for retry: \(error.localizedDescription)")
            if let data = try? JSONEncoder().encode(workout),
               let payload = String(data: data, encoding: .utf8) {
                SyncManager.shared.enqueue(SyncOperation(
                    type: .saveWorkout,
                    entityId: workout.id,
                    userId: workout.userId,
                    payload: payload
                ))
            }
            return false
        }
    }

    // MARK: - Fetch

    func fetchWorkout(id: String) async -> Workout? {
        do {
            let rows: [WorkoutWithRelations] = try await supabase
                .from("workouts")
                .select("*, workout_exercises(*, workout_sets(*))")
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else { return nil }
            return buildWorkout(from: row)
        } catch {
            print("[WorkoutService] Supabase fetch workout failed: \(error.localizedDescription)")
            // Fallback to cache
            let all = loadAllFromCache()
            return all.first(where: { $0.id == id })
        }
    }

    func fetchWorkouts(userId: String) async -> [Workout] {
        do {
            let workouts = try await fetchFromSupabase(userId: userId)
            // Update local cache on success — replace entirely for this user
            overwriteCache(workouts, userId: userId)
            return deduplicateWorkouts(workouts)
        } catch {
            print("[WorkoutService] Supabase fetch failed, using cache: \(error.localizedDescription)")
            return deduplicateWorkouts(fetchWorkoutsFromCache(userId: userId))
        }
    }

    /// Remove duplicate workouts by ID, keeping the first occurrence (most recent by sort order).
    private func deduplicateWorkouts(_ workouts: [Workout]) -> [Workout] {
        var seen = Set<String>()
        return workouts.filter { seen.insert($0.id).inserted }
    }

    func fetchWorkoutsFromCache(userId: String) -> [Workout] {
        let all = loadAllFromCache()
        return all
            .filter { $0.userId == userId }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Delete

    func deleteWorkout(id: String) async {
        // Grab the userId from cache before deleting (needed for feed cleanup)
        let workouts = loadAllFromCache()
        let workoutUserId = workouts.first(where: { $0.id == id })?.userId

        // Delete locally
        var updatedWorkouts = workouts
        updatedWorkouts.removeAll { $0.id == id }
        let data = try? JSONEncoder().encode(updatedWorkouts)
        UserDefaults.standard.set(data, forKey: storageKey)

        // Delete from Supabase (cascade handles exercises + sets)
        do {
            try await deleteFromSupabase(id: id)
        } catch {
            print("[WorkoutService] Supabase delete failed: \(error.localizedDescription)")
        }

        // Delete associated feed items
        if let userId = workoutUserId {
            do {
                try await FeedService.shared.deleteFeedItemsForWorkout(workoutId: id, userId: userId)
            } catch {
                print("[WorkoutService] Feed item cleanup failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private: Supabase

    private func saveToSupabase(_ workout: Workout) async throws {
        let workoutPayload = WorkoutInsertPayload(
            id: workout.id,
            user_id: workout.userId,
            name: workout.name,
            start_time: iso8601.string(from: workout.startTime),
            end_time: workout.endTime.map { iso8601.string(from: $0) },
            notes: workout.notes
        )

        try await supabase
            .from("workouts")
            .upsert(workoutPayload)
            .execute()

        for (sortIndex, workoutExercise) in workout.exercises.enumerated() {
            let exercisePayload = WorkoutExerciseInsertPayload(
                id: workoutExercise.id,
                workout_id: workout.id,
                exercise_id: workoutExercise.exercise.id,
                exercise_name: workoutExercise.exercise.name,
                sort_order: sortIndex
            )

            try await supabase
                .from("workout_exercises")
                .upsert(exercisePayload)
                .execute()

            for (setIndex, workoutSet) in workoutExercise.sets.enumerated() {
                let setPayload = WorkoutSetInsertPayload(
                    id: workoutSet.id,
                    workout_exercise_id: workoutExercise.id,
                    set_number: setIndex,
                    weight: workoutSet.weight,
                    reps: workoutSet.reps,
                    rpe: workoutSet.rpe,
                    is_completed: true,
                    is_pr: workoutSet.isPersonalRecord,
                    completed_at: iso8601.string(from: workoutSet.completedAt)
                )

                try await supabase
                    .from("workout_sets")
                    .upsert(setPayload)
                    .execute()
            }
        }
    }

    private func fetchFromSupabase(userId: String) async throws -> [Workout] {
        let rows: [WorkoutWithRelations] = try await supabase
            .from("workouts")
            .select("*, workout_exercises(*, workout_sets(*))")
            .eq("user_id", value: userId)
            .order("start_time", ascending: false)
            .execute()
            .value

        return rows.map { buildWorkout(from: $0) }
    }

    private func buildWorkout(from row: WorkoutWithRelations) -> Workout {
        let exercises = row.workoutExercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { exRow in
                let exercise = ExerciseDatabase.all.first(where: { $0.id == exRow.exerciseId })
                    ?? Exercise(
                        id: exRow.exerciseId,
                        name: exRow.exerciseName,
                        muscleGroups: [],
                        equipment: .other,
                        category: .compound,
                        description: "",
                        tips: []
                    )

                let sets = exRow.workoutSets
                    .sorted { $0.setNumber < $1.setNumber }
                    .map { setRow in
                        WorkoutSet(
                            id: setRow.id,
                            exerciseId: exRow.exerciseId,
                            weight: setRow.weight,
                            reps: setRow.reps,
                            rpe: setRow.rpe,
                            isPersonalRecord: setRow.isPr,
                            completedAt: setRow.completedAt.flatMap { iso8601.date(from: $0) } ?? Date()
                        )
                    }

                return WorkoutExercise(
                    id: exRow.id,
                    exercise: exercise,
                    sets: sets
                )
            }

        return Workout(
            id: row.id,
            userId: row.userId,
            name: row.name,
            exercises: exercises,
            startTime: iso8601.date(from: row.startTime) ?? Date(),
            endTime: row.endTime.flatMap { iso8601.date(from: $0) },
            notes: row.notes
        )
    }

    private func deleteFromSupabase(id: String) async throws {
        try await supabase
            .from("workouts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Private: UserDefaults Cache

    private func saveToCache(_ workout: Workout) {
        var workouts = loadAllFromCache()
        if let idx = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[idx] = workout
        } else {
            workouts.insert(workout, at: 0)
        }
        let data = try? JSONEncoder().encode(workouts)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadAllFromCache() -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([Workout].self, from: data)) ?? []
    }

    private func overwriteCache(_ workouts: [Workout], userId: String) {
        // Keep workouts for other users, replace for this user
        var all = loadAllFromCache().filter { $0.userId != userId }
        all.append(contentsOf: workouts)
        let data = try? JSONEncoder().encode(all)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
