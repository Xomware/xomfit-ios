import Foundation

enum WeightMode: String, Codable {
    case total      // default: weight is total (both hands on barbell)
    case perSide    // weight is per arm/leg (e.g., 25lb each arm)
}

struct WorkoutSet: Codable, Identifiable, Hashable {
    let id: String
    var exerciseId: String
    var weight: Double
    var reps: Int
    var rpe: Double? // Rate of Perceived Exertion (1-10)
    var isPersonalRecord: Bool
    var completedAt: Date
    var weightMode: WeightMode = .total

    // MARK: - Skip
    /// Set when the lifter explicitly decides not to do this set.
    ///
    /// Distinct from "not done yet" (`completedAt == .distantPast`): a skipped
    /// set is *resolved*, so it stops counting as work remaining and the flow
    /// advances past it. Client-side only — skipped sets are dropped at save,
    /// so this never reaches the backend (the wire DTOs in `WorkoutService`
    /// are separate structs). Optional-with-default so previously persisted
    /// session blobs still decode.
    var skippedAt: Date?

    // MARK: - Drop Set
    /// True when this set is a drop set following a parent set without rest.
    /// Drop sets immediately follow their parent in the sets array.
    var isDropSet: Bool = false

    /// True when this set was completed while the previous set's rest timer was
    /// still running — the lifter got back under the bar before the clock ran
    /// out.
    ///
    /// Stored rather than derived: nothing in a saved workout records when rest
    /// started, so this cannot be reconstructed after the fact. Sets that skip
    /// rest entirely (drop-set chains) are false — there was no clock to beat.
    var beatRestTimer: Bool = false

    // MARK: - Form Check Video (optional attachment)
    var videoLocalURL: URL?       // locally saved clip after recording
    var videoRemoteURL: URL?      // uploaded to Supabase Storage

    /// Memberwise init, spelled out because the hand-written `init(from:)` below
    /// suppresses the synthesized one. Parameter order and defaults match the
    /// property declarations above.
    init(
        id: String,
        exerciseId: String,
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        isPersonalRecord: Bool,
        completedAt: Date,
        weightMode: WeightMode = .total,
        skippedAt: Date? = nil,
        isDropSet: Bool = false,
        beatRestTimer: Bool = false,
        videoLocalURL: URL? = nil,
        videoRemoteURL: URL? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.isPersonalRecord = isPersonalRecord
        self.completedAt = completedAt
        self.weightMode = weightMode
        self.skippedAt = skippedAt
        self.isDropSet = isDropSet
        self.beatRestTimer = beatRestTimer
        self.videoLocalURL = videoLocalURL
        self.videoRemoteURL = videoRemoteURL
    }

    // MARK: - Decoding
    //
    // Written by hand because Swift's synthesized decoder ignores property
    // defaults: a key that is merely *absent* is a hard failure, not a fallback
    // to the default. Every field added since the first release is therefore a
    // decoding break for anything already cached — the in-progress session blob
    // and the local workout cache both round-trip through this type, so a lifter
    // updating mid-workout would lose the session.
    //
    // Anything with a default is read with `decodeIfPresent`. Add a field with a
    // default, add it here too.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        exerciseId = try c.decode(String.self, forKey: .exerciseId)
        weight = try c.decode(Double.self, forKey: .weight)
        reps = try c.decode(Int.self, forKey: .reps)
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        isPersonalRecord = try c.decode(Bool.self, forKey: .isPersonalRecord)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        weightMode = try c.decodeIfPresent(WeightMode.self, forKey: .weightMode) ?? .total
        skippedAt = try c.decodeIfPresent(Date.self, forKey: .skippedAt)
        isDropSet = try c.decodeIfPresent(Bool.self, forKey: .isDropSet) ?? false
        beatRestTimer = try c.decodeIfPresent(Bool.self, forKey: .beatRestTimer) ?? false
        videoLocalURL = try c.decodeIfPresent(URL.self, forKey: .videoLocalURL)
        videoRemoteURL = try c.decodeIfPresent(URL.self, forKey: .videoRemoteURL)
    }

    /// True when the lifter chose not to do this set.
    var isSkipped: Bool { skippedAt != nil }

    /// True when this set is neither done nor skipped — i.e. still owed.
    ///
    /// This is the predicate every "is there work left?" check should use.
    /// Testing `completedAt == .distantPast` alone treats a skipped set as
    /// outstanding forever, which blocks `allExercisesComplete` and strands
    /// the auto-advance.
    var isPending: Bool { completedAt == Date.distantPast && skippedAt == nil }

    /// True when this set has been resolved one way or the other.
    var isCompleted: Bool { completedAt != Date.distantPast }

    var volume: Double {
        let multiplier: Double = weightMode == .perSide ? 2 : 1
        return weight * Double(reps) * multiplier
    }
    
    var estimated1RM: Double {
        // Epley formula
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
    
    var displayWeight: String {
        weight.formattedWeight + " lbs"
    }
    
    var displaySet: String {
        "\(weight.formattedWeight) × \(reps)"
    }
}

// MARK: - Mock Data
extension WorkoutSet {
    static let mockSets: [WorkoutSet] = [
        WorkoutSet(id: "set-1", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8, isPersonalRecord: false, completedAt: Date()),
        WorkoutSet(id: "set-2", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8.5, isPersonalRecord: false, completedAt: Date()),
        WorkoutSet(id: "set-3", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: true, completedAt: Date()),
    ]
}
