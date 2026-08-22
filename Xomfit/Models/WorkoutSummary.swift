import Foundation

/// What a lifter actually did in one session, assembled at finish.
///
/// Built once in `WorkoutLoggerViewModel.finishWorkout` rather than derived by
/// the view, because half of it is only knowable *during* the session: PRs and
/// tier promotions are detected set by set and are gone from view state the
/// moment the workout is torn down.
struct WorkoutSummary: Identifiable {
    /// Identity only exists so the sheet can be driven by `.sheet(item:)`.
    /// `PersonalRecord` isn't `Equatable`, so this type can't be either.
    let id = UUID()

    let workoutName: String
    /// Wall-clock training time with paused intervals already removed.
    let duration: TimeInterval
    let totalVolume: Double
    let totalSets: Int
    let exerciseCount: Int
    /// Sets finished before the previous set's rest timer ran out.
    let beatTheClockSets: Int

    let personalRecords: [PersonalRecord]
    /// Lifts that crossed into a new strength tier during this session.
    let tierUps: [TierUp]
    /// Badges this workout pushed over the line.
    let newBadges: [ActivityBadge]

    struct TierUp: Equatable {
        let exerciseName: String
        let tier: StrengthTier
    }

    /// True when the session produced nothing beyond the raw numbers, so the
    /// view can drop the achievements section rather than render an empty header.
    var hasAchievements: Bool {
        !personalRecords.isEmpty || !tierUps.isEmpty || !newBadges.isEmpty
    }

    var durationString: String {
        let seconds = Int(duration)
        let minutes = seconds / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    /// Volume rounded to something readable — nobody needs 47,318 lbs to the pound.
    var volumeString: String {
        if totalVolume >= 10_000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return String(format: "%.0f", totalVolume)
    }
}
