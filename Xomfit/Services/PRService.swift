import Foundation
import Supabase

// MARK: - DB Row

private struct PRRow: Codable {
    let id: String
    let userId: String
    let exerciseId: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: String           // ISO8601 string from Supabase
    let previousBest: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case weight
        case reps
        case date
        case previousBest = "previous_best"
    }
}

private struct PRInsertPayload: Encodable {
    let id: String
    let user_id: String
    let exercise_id: String
    let exercise_name: String
    let weight: Double
    let reps: Int
    let date: String
    let previous_best: Double?
}

// MARK: - PRService

@MainActor
final class PRService {
    static let shared = PRService()

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    /// Check if a completed set is a PR for the given exercise and user.
    /// Returns the new PersonalRecord if it is a PR, nil otherwise.
    func checkForPR(
        exerciseId: String,
        exerciseName: String,
        weight: Double,
        reps: Int,
        userId: String
    ) async -> PersonalRecord? {
        do {
            // Fetch existing PRs for this user + exercise at the same rep count
            let existing: [PRRow] = try await supabase
                .from("personal_records")
                .select()
                .eq("user_id", value: userId)
                .eq("exercise_id", value: exerciseId)
                .eq("reps", value: reps)
                .order("weight", ascending: false)
                .limit(1)
                .execute()
                .value

            let previousBest = existing.first?.weight

            // Is this a new PR?
            guard previousBest == nil || weight > (previousBest ?? 0) else {
                return nil
            }

            // Build and insert new PR
            let newId = UUID().uuidString
            let dateString = iso8601.string(from: Date())

            let payload = PRInsertPayload(
                id: newId,
                user_id: userId,
                exercise_id: exerciseId,
                exercise_name: exerciseName,
                weight: weight,
                reps: reps,
                date: dateString,
                previous_best: previousBest
            )

            try await supabase
                .from("personal_records")
                .insert(payload)
                .execute()

            return PersonalRecord(
                id: newId,
                userId: userId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                weight: weight,
                reps: reps,
                date: Date(),
                previousBest: previousBest
            )
        } catch {
            // PR detection is non-critical — fail silently
            return nil
        }
    }

    func fetchPRs(userId: String) async throws -> [PersonalRecord] {
        let rows: [PRRow] = try await supabase
            .from("personal_records")
            .select()
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value

        return rows.map { row in
            let date = iso8601.date(from: row.date) ?? Date()
            return PersonalRecord(
                id: row.id,
                userId: row.userId,
                exerciseId: row.exerciseId,
                exerciseName: row.exerciseName,
                weight: row.weight,
                reps: row.reps,
                date: date,
                previousBest: row.previousBest
            )
        }
    }
}
