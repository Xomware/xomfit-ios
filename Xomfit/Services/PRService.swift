import Foundation
import Supabase

// MARK: - DB Row

/// Mirrors `personal_records` after the 20260811 migration.
///
/// The previous version of this struct read and wrote `date` and
/// `previous_best`, columns no migration has ever created — the table has always
/// used `achieved_at` and `previous_weight`. Every insert therefore failed with
/// an undefined-column error, and `checkForPR` swallowed it, which is why no
/// personal record was ever persisted. The column names below are the ones that
/// actually exist.
private struct PRRow: Codable {
    let id: String
    let userId: String
    let exerciseId: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let achievedAt: String?
    let previousWeight: Double?
    let kind: String?
    let variantKey: String?
    let estimated1RM: Double?
    let previous1RM: Double?
    let weightMode: String?
    let selectedGrip: String?
    let selectedAttachment: String?
    let selectedLaterality: String?
    let workoutId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case weight
        case reps
        case achievedAt = "achieved_at"
        case previousWeight = "previous_weight"
        case kind
        case variantKey = "variant_key"
        case estimated1RM = "estimated_1rm"
        case previous1RM = "previous_1rm"
        case weightMode = "weight_mode"
        case selectedGrip = "selected_grip"
        case selectedAttachment = "selected_attachment"
        case selectedLaterality = "selected_laterality"
        case workoutId = "workout_id"
    }
}

private struct PRUpsertPayload: Encodable {
    let id: String
    let user_id: String
    let exercise_id: String
    let exercise_name: String
    let weight: Double
    let reps: Int
    let achieved_at: String
    let previous_weight: Double?
    let kind: String
    let variant_key: String
    let estimated_1rm: Double
    let previous_1rm: Double?
    let weight_mode: String
    let selected_grip: String?
    let selected_attachment: String?
    let selected_laterality: String
    let workout_id: String?
}

// MARK: - Result

/// Records set by a single completed set. Both can fire at once — a heavy single
/// can be both a new all-time e1RM and a new best at that rep count.
struct PRResult {
    var e1rm: PersonalRecord?
    var repRange: PersonalRecord?

    var isEmpty: Bool { e1rm == nil && repRange == nil }
    /// The record worth celebrating loudest.
    var headline: PersonalRecord? { e1rm ?? repRange }
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

    /// Lenient parser for timestamps Postgres returns without fractional seconds.
    private let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Check

    /// Evaluates a completed set against the user's existing records for that
    /// exercise *variant* and persists any new record.
    ///
    /// Ranking is on estimated 1RM rather than raw weight, so sets at different
    /// rep counts are actually comparable. The previous implementation matched
    /// on an exact rep count, which meant 225x5 logged after 225x6 registered as
    /// a new PR despite being the strictly worse set, while 230x5 after 225x6
    /// was never compared against the better lift at all.
    ///
    /// Throws rather than returning nil on failure. PR detection is not critical
    /// enough to block finishing a workout, but it is far too important to fail
    /// invisibly — the caller decides how to surface and retry.
    func checkForPR(
        exerciseId: String,
        exerciseName: String,
        weight: Double,
        reps: Int,
        userId: String,
        weightMode: WeightMode = .total,
        grip: GripType? = nil,
        attachment: CableAttachment? = nil,
        position: ExercisePosition? = nil,
        laterality: Laterality = .bilateral,
        workoutId: String? = nil
    ) async throws -> PRResult {
        guard weight > 0, reps > 0 else { return PRResult() }

        let variantKey = ExerciseVariant.key(
            exerciseId: exerciseId,
            grip: grip,
            attachment: attachment,
            position: position,
            laterality: laterality
        )

        // A per-side set moves twice the load it records, and must be compared
        // on that basis or unilateral work can never register a record.
        let effectiveWeight = weightMode == .perSide ? weight * 2 : weight
        let newE1RM = Exercise.estimateMax(weight: effectiveWeight, reps: reps)

        // One round trip covers both record kinds for this variant.
        let existing: [PRRow] = try await supabase
            .from("personal_records")
            .select()
            .eq("user_id", value: userId)
            .eq("variant_key", value: variantKey)
            .execute()
            .value

        let existingE1RM = existing.first { $0.kind == PRKind.e1rm.rawValue }
        let existingRepRange = existing.first {
            $0.kind == PRKind.repRange.rawValue && $0.reps == reps
        }

        var result = PRResult()

        // All-rep-ranges record.
        let previousBest1RM = existingE1RM?.estimated1RM
        if previousBest1RM == nil || newE1RM > previousBest1RM! {
            result.e1rm = try await upsert(
                kind: .e1rm,
                existingId: existingE1RM?.id,
                userId: userId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                variantKey: variantKey,
                weight: weight,
                reps: reps,
                estimated1RM: newE1RM,
                previousWeight: existingE1RM?.weight,
                previous1RM: previousBest1RM,
                weightMode: weightMode,
                grip: grip,
                attachment: attachment,
                laterality: laterality,
                workoutId: workoutId
            )
        }

        // Best-at-this-rep-count record.
        let previousBestAtReps = existingRepRange?.weight
        if previousBestAtReps == nil || weight > previousBestAtReps! {
            result.repRange = try await upsert(
                kind: .repRange,
                existingId: existingRepRange?.id,
                userId: userId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                variantKey: variantKey,
                weight: weight,
                reps: reps,
                estimated1RM: newE1RM,
                previousWeight: previousBestAtReps,
                previous1RM: existingRepRange?.estimated1RM,
                weightMode: weightMode,
                grip: grip,
                attachment: attachment,
                laterality: laterality,
                workoutId: workoutId
            )
        }

        return result
    }

    // MARK: - Persist

    /// Writes the record, reusing the existing row id when one is present so the
    /// table holds one *current* record per variant rather than an ever-growing
    /// log of every PR event. The unique indexes added in the 20260811 migration
    /// make this an upsert rather than a read-modify-write race between devices.
    private func upsert(
        kind: PRKind,
        existingId: String?,
        userId: String,
        exerciseId: String,
        exerciseName: String,
        variantKey: String,
        weight: Double,
        reps: Int,
        estimated1RM: Double,
        previousWeight: Double?,
        previous1RM: Double?,
        weightMode: WeightMode,
        grip: GripType?,
        attachment: CableAttachment?,
        laterality: Laterality,
        workoutId: String?
    ) async throws -> PersonalRecord {
        let id = existingId ?? UUID().uuidString
        let now = Date()

        let payload = PRUpsertPayload(
            id: id,
            user_id: userId,
            exercise_id: exerciseId,
            exercise_name: exerciseName,
            weight: weight,
            reps: reps,
            achieved_at: iso8601.string(from: now),
            previous_weight: previousWeight,
            kind: kind.rawValue,
            variant_key: variantKey,
            estimated_1rm: estimated1RM,
            previous_1rm: previous1RM,
            weight_mode: weightMode.rawValue,
            selected_grip: grip?.rawValue,
            selected_attachment: attachment?.rawValue,
            selected_laterality: laterality.rawValue,
            workout_id: workoutId
        )

        try await supabase
            .from("personal_records")
            .upsert(payload)
            .execute()

        return PersonalRecord(
            id: id,
            userId: userId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            date: now,
            previousBest: previousWeight,
            kind: kind,
            variantKey: variantKey,
            estimated1RM: estimated1RM,
            previous1RM: previous1RM,
            weightMode: weightMode,
            selectedGrip: grip,
            selectedAttachment: attachment,
            selectedLaterality: laterality,
            workoutId: workoutId
        )
    }

    // MARK: - Fetch

    /// All records for a user, newest first.
    ///
    /// Returns both kinds. Callers showing a "PRs" list generally want
    /// `fetchPRs(userId:kind:)` with `.e1rm` to avoid listing the same lift once
    /// per rep count.
    func fetchPRs(userId: String) async throws -> [PersonalRecord] {
        try await fetchPRs(userId: userId, kind: nil)
    }

    func fetchPRs(userId: String, kind: PRKind?) async throws -> [PersonalRecord] {
        var query = supabase
            .from("personal_records")
            .select()
            .eq("user_id", value: userId)

        if let kind {
            query = query.eq("kind", value: kind.rawValue)
        }

        let rows: [PRRow] = try await query
            .order("achieved_at", ascending: false)
            .execute()
            .value

        return rows.map(record(from:))
    }

    /// Current records for one exercise variant — what the exercise detail sheet
    /// shows above the history list.
    func fetchPRs(userId: String, variantKey: String) async throws -> [PersonalRecord] {
        let rows: [PRRow] = try await supabase
            .from("personal_records")
            .select()
            .eq("user_id", value: userId)
            .eq("variant_key", value: variantKey)
            .order("achieved_at", ascending: false)
            .execute()
            .value

        return rows.map(record(from:))
    }

    private func record(from row: PRRow) -> PersonalRecord {
        let date = row.achievedAt.flatMap { raw in
            iso8601.date(from: raw) ?? iso8601NoFraction.date(from: raw)
        } ?? Date()

        return PersonalRecord(
            id: row.id,
            userId: row.userId,
            exerciseId: row.exerciseId,
            exerciseName: row.exerciseName,
            weight: row.weight,
            reps: row.reps,
            date: date,
            previousBest: row.previousWeight,
            kind: row.kind.flatMap { PRKind(rawValue: $0) } ?? .repRange,
            variantKey: row.variantKey,
            estimated1RM: row.estimated1RM,
            previous1RM: row.previous1RM,
            weightMode: row.weightMode.flatMap { WeightMode(rawValue: $0) } ?? .total,
            selectedGrip: row.selectedGrip.flatMap { GripType(rawValue: $0) },
            selectedAttachment: row.selectedAttachment.flatMap { CableAttachment(rawValue: $0) },
            selectedLaterality: row.selectedLaterality.flatMap { Laterality(rawValue: $0) } ?? .bilateral,
            workoutId: row.workoutId
        )
    }
}
