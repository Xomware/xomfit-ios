import Foundation
import HealthKit

/// The cardio modalities XomFit logs.
///
/// Deliberately a closed set rather than free text: pace only means something
/// when you know whether it is a run or a row, and grouping by modality is what
/// makes "am I getting faster" answerable.
enum CardioModality: String, Codable, CaseIterable, Identifiable {
    case outdoorRun
    case indoorRun
    case outdoorWalk
    case indoorWalk
    case hike
    case row
    case outdoorBike
    case indoorBike
    case stairMaster
    case elliptical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .outdoorRun:  return "Outdoor Run"
        case .indoorRun:   return "Indoor Run"
        case .outdoorWalk: return "Outdoor Walk"
        case .indoorWalk:  return "Indoor Walk"
        case .hike:        return "Hike"
        case .row:         return "Row"
        case .outdoorBike: return "Outdoor Bike"
        case .indoorBike:  return "Indoor Bike"
        case .stairMaster: return "Stair Master"
        case .elliptical:  return "Elliptical"
        }
    }

    var icon: String {
        switch self {
        case .outdoorRun, .indoorRun:   return "figure.run"
        case .outdoorWalk, .indoorWalk: return "figure.walk"
        case .hike:                     return "figure.hiking"
        case .row:                      return "figure.rower"
        case .outdoorBike, .indoorBike: return "figure.outdoor.cycle"
        case .stairMaster:              return "figure.stair.stepper"
        case .elliptical:               return "figure.elliptical"
        }
    }

    /// Whether distance is a meaningful metric. A stair master reports floors
    /// and an elliptical reports nothing useful, so asking for distance there
    /// invites junk data.
    var tracksDistance: Bool {
        switch self {
        case .stairMaster, .elliptical: return false
        default:                        return true
        }
    }

    /// Whether elevation gain is worth showing.
    var tracksElevation: Bool {
        switch self {
        case .outdoorRun, .outdoorWalk, .hike, .outdoorBike: return true
        default:                                             return false
        }
    }

    /// Whether the modality happens indoors, which HealthKit models as a
    /// separate metadata flag rather than a distinct activity type.
    var isIndoor: Bool {
        switch self {
        case .indoorRun, .indoorWalk, .indoorBike, .stairMaster, .elliptical: return true
        case .outdoorRun, .outdoorWalk, .hike, .row, .outdoorBike:            return false
        }
    }

    /// Pace is natural for foot-based work ("8:30 /mi"); speed is natural for
    /// wheels ("18.2 mph"). Showing a cyclist their pace in minutes per mile is
    /// technically correct and completely useless.
    var prefersPaceOverSpeed: Bool {
        switch self {
        case .outdoorBike, .indoorBike: return false
        default:                        return true
        }
    }

    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .outdoorRun, .indoorRun:   return .running
        case .outdoorWalk, .indoorWalk: return .walking
        case .hike:                     return .hiking
        case .row:                      return .rowing
        case .outdoorBike, .indoorBike: return .cycling
        case .stairMaster:              return .stairClimbing
        case .elliptical:               return .elliptical
        }
    }

    /// Best-effort reverse mapping for sessions imported from Health.
    ///
    /// HealthKit distinguishes indoor from outdoor with a metadata flag rather
    /// than the activity type, so the caller passes what it found.
    static func from(healthKitType: HKWorkoutActivityType, isIndoor: Bool) -> CardioModality? {
        switch healthKitType {
        case .running:        return isIndoor ? .indoorRun : .outdoorRun
        case .walking:        return isIndoor ? .indoorWalk : .outdoorWalk
        case .hiking:         return .hike
        case .rowing:         return .row
        case .cycling:        return isIndoor ? .indoorBike : .outdoorBike
        case .stairClimbing,
             .stairs,
             .stepTraining:   return .stairMaster
        case .elliptical:     return .elliptical
        default:              return nil
        }
    }
}

// MARK: - Session

/// A logged cardio effort.
///
/// Kept separate from `Workout` rather than bolted on as another `WorkoutKind`:
/// a workout is a list of exercises with sets, and cardio has no sets. Forcing
/// the two together would mean every strength code path carrying nil distance
/// and pace fields it can never use.
struct CardioSession: Codable, Identifiable, Hashable {
    let id: String
    var userId: String
    var modality: CardioModality
    var startTime: Date
    var endTime: Date
    /// Moving time, which is what pace should be computed from. Falls back to
    /// elapsed time when the source does not distinguish the two.
    var durationSeconds: Double
    /// Miles. Nil when the modality does not track distance.
    var distanceMiles: Double?
    var activeCalories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Feet.
    var elevationGainFeet: Double?
    var notes: String?
    /// Set when imported rather than logged by hand, so the UI can label the
    /// source and avoid re-importing the same session.
    var healthKitUUID: String?
    var sourceName: String?

    var isImported: Bool { healthKitUUID != nil }

    /// Minutes per mile. Nil when there is no distance to divide by.
    var paceSecondsPerMile: Double? {
        guard let distanceMiles, distanceMiles > 0, durationSeconds > 0 else { return nil }
        return durationSeconds / distanceMiles
    }

    var speedMPH: Double? {
        guard let distanceMiles, distanceMiles > 0, durationSeconds > 0 else { return nil }
        return distanceMiles / (durationSeconds / 3600)
    }

    /// "8:30 /mi" or "18.2 mph", whichever reads naturally for the modality.
    var paceDisplay: String? {
        if modality.prefersPaceOverSpeed {
            guard let pace = paceSecondsPerMile else { return nil }
            let minutes = Int(pace) / 60
            let seconds = Int(pace) % 60
            return String(format: "%d:%02d /mi", minutes, seconds)
        } else {
            guard let speed = speedMPH else { return nil }
            return String(format: "%.1f mph", speed)
        }
    }

    var durationDisplay: String {
        let total = Int(durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
