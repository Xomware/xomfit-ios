import Foundation

// MARK: - Supporting Types

/// A friend selectable in the comparison section. Lightweight projection of a
/// `ProfileRow` so the view doesn't need the full row.
struct StatsFriend: Identifiable, Hashable {
    let id: String
    let displayName: String
    let username: String
    let avatarURL: URL?

    var label: String { displayName.isEmpty ? username : displayName }
}

/// A single radar axis: a coarse muscle bucket plus its normalized intensity.
struct RadarAxis: Identifiable, Hashable {
    let name: String
    /// 0.0–1.0 normalized vs. the most-trained bucket.
    let value: Double
    /// Raw set count behind `value` — surfaced in accessibility / detail.
    let rawSets: Int

    var id: String { name }
}

/// Month-to-date comparison snapshot used by `FriendComparisonView`.
struct ComparisonStats: Equatable {
    var workoutsThisMonth: Int = 0
    var volumeThisMonth: Double = 0
    var prsThisMonth: Int = 0
    var currentStreak: Int = 0
    var avgWorkoutsPerWeek: Double = 0
}

// MARK: - StatsViewModel

@MainActor
@Observable
final class StatsViewModel {
    // MARK: - State
    var isLoading = false
    var workouts: [Workout] = []

    // MARK: - Quick Stats
    var totalWorkouts = 0
    var totalVolume: Double = 0
    var totalPRs = 0
    var currentStreak = 0
    var longestStreak = 0

    // MARK: - Sections
    /// Ordered radar axes (6 coarse muscle buckets), normalized for the chart.
    var radarAxes: [RadarAxis] = []
    /// 4 weekly volume buckets, oldest first. Reuses `ProfileViewModel.VolumeBucket`
    /// so `VolumeTrendChart` can render it directly.
    var volumeTrend: [ProfileViewModel.VolumeBucket] = []
    /// Workout counts per week for the last 4 weeks, oldest first.
    var workoutsPerWeek: [Int] = []
    var avgWorkoutsPerWeek: Double = 0
    /// Top 5 lifetime exercises by volume. Reuses `ProfileViewModel.TopExercise`.
    var topExercises: [ProfileViewModel.TopExercise] = []
    var recentPRs: [PersonalRecord] = []

    // MARK: - Friends
    var friends: [StatsFriend] = []
    /// Your own month-to-date snapshot, compared against a selected friend.
    var myComparison = ComparisonStats()

    var hasData: Bool { !workouts.isEmpty }
    var hasFriends: Bool { !friends.isEmpty }

    var formattedVolume: String { Self.formatVolume(totalVolume) }

    /// Under the DEBUG auth bypass there are no Supabase credentials, so the
    /// `supabase` client traps on first access (an assertion, not a throw — so
    /// `try?` can't save us). Network paths are skipped and the seeded local
    /// cache is used instead. Compiles to `false` in Release.
    private var isAuthBypass: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1"
        #else
        false
        #endif
    }

    // MARK: - Muscle Axis Buckets
    //
    // The radar collapses the 13 fine-grained `MuscleGroup` cases into 6 coarse
    // buckets so the chart reads as a clean hexagon. Order is the clockwise
    // perimeter order used by `RadarChartView`.
    static let axisOrder = ["Chest", "Shoulders", "Arms", "Core", "Legs", "Back"]

    private static func axis(for group: MuscleGroup) -> String {
        switch group {
        case .chest:                              return "Chest"
        case .shoulders:                          return "Shoulders"
        case .biceps, .triceps, .forearms:        return "Arms"
        case .abs:                                return "Core"
        case .quads, .hamstrings, .glutes, .calves: return "Legs"
        case .back, .lats, .traps:                return "Back"
        }
    }

    // MARK: - Load

    /// Hydrates from the local cache first (instant), then refreshes from the
    /// network. Recomputes derived stats after each so the screen never blanks.
    func load(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true

        // 1. Instant render from the local cache (always available, bypass-safe).
        apply(workouts: WorkoutService.shared.fetchWorkoutsFromCache(userId: userId))

        // 2. Network refresh + remote-only data — skipped under the auth bypass
        //    where the Supabase client is unconfigured.
        if !isAuthBypass {
            let fresh = await WorkoutService.shared.fetchWorkouts(userId: userId)
            apply(workouts: fresh)
            await loadRecentPRs(userId: userId)
            await loadFriends(userId: userId)
        }

        isLoading = false
    }

    private func apply(workouts: [Workout]) {
        self.workouts = workouts
        totalWorkouts = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        totalPRs = workouts.reduce(0) { $0 + $1.totalPRs }
        currentStreak = WorkoutInsights.currentStreak(workouts: workouts)
        longestStreak = WorkoutInsights.longestStreak(workouts: workouts)
        radarAxes = Self.computeRadar(workouts: workouts)
        let trend = Self.computeWeeklyBuckets(workouts: workouts)
        volumeTrend = trend.volume
        workoutsPerWeek = trend.counts
        avgWorkoutsPerWeek = trend.counts.isEmpty
            ? 0
            : Double(trend.counts.reduce(0, +)) / Double(trend.counts.count)
        topExercises = Self.computeTopExercises(workouts: workouts)
        myComparison = Self.comparisonStats(workouts: workouts)
        // Baseline PRs derived from PR sets in history; overridden by the richer
        // PR table when the network path runs.
        recentPRs = Self.derivePRs(workouts: workouts)
    }

    private func loadRecentPRs(userId: String) async {
        if let prs = try? await PRService.shared.fetchPRs(userId: userId), !prs.isEmpty {
            recentPRs = Array(prs.prefix(5))
        }
    }

    private func loadFriends(userId: String) async {
        guard let rows = try? await FriendsService.shared.fetchFriends(userId: userId) else { return }
        let friendIds = rows.map { $0.requesterId == userId ? $0.addresseeId : $0.requesterId }

        var resolved: [StatsFriend] = []
        for id in friendIds {
            if let profile = try? await ProfileService.shared.fetchProfile(userId: id) {
                resolved.append(StatsFriend(
                    id: id,
                    displayName: profile.displayName,
                    username: profile.username,
                    avatarURL: profile.avatarURL.flatMap(URL.init(string:))
                ))
            }
        }
        friends = resolved
    }

    /// Loads a friend's month-to-date snapshot for the comparison cards.
    func loadFriendComparison(friendId: String) async -> ComparisonStats {
        let friendWorkouts = await WorkoutService.shared.fetchWorkouts(userId: friendId)
        return Self.comparisonStats(workouts: friendWorkouts)
    }

    // MARK: - Pure Computations

    static func computeRadar(workouts: [Workout]) -> [RadarAxis] {
        var setsByAxis: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let setCount = exercise.sets.count
                // A muscle group is credited once per exercise it appears in.
                let axes = Set(exercise.exercise.muscleGroups.map { axis(for: $0) })
                for axisName in axes {
                    setsByAxis[axisName, default: 0] += setCount
                }
            }
        }
        let maxSets = max(setsByAxis.values.max() ?? 0, 1)
        return axisOrder.map { name in
            let raw = setsByAxis[name] ?? 0
            return RadarAxis(name: name, value: Double(raw) / Double(maxSets), rawSets: raw)
        }
    }

    /// 4 weekly buckets ending now, oldest first. Mirrors
    /// `ProfileViewModel.computeDerivedStats` so charts stay consistent.
    static func computeWeeklyBuckets(
        workouts: [Workout],
        now: Date = Date()
    ) -> (volume: [ProfileViewModel.VolumeBucket], counts: [Int]) {
        let calendar = Calendar.current
        let bucketCount = 4
        var ranges: [(start: Date, end: Date)] = []
        var starts: [Date] = []
        for i in 0..<bucketCount {
            let daysBack = (bucketCount - i) * 7
            if let start = calendar.date(byAdding: .day, value: -daysBack, to: now) {
                starts.append(start)
            }
        }
        for i in 0..<starts.count {
            let end = i + 1 < starts.count ? starts[i + 1] : now
            ranges.append((starts[i], end))
        }

        var volume: [ProfileViewModel.VolumeBucket] = []
        var counts: [Int] = []
        for range in ranges {
            let inRange = workouts.filter { $0.startTime >= range.start && $0.startTime < range.end }
            volume.append(ProfileViewModel.VolumeBucket(
                weekStart: range.start,
                volume: inRange.reduce(0.0) { $0 + $1.totalVolume }
            ))
            counts.append(inRange.count)
        }
        return (volume, counts)
    }

    static func computeTopExercises(workouts: [Workout]) -> [ProfileViewModel.TopExercise] {
        var volumeByName: [String: Double] = [:]
        var setsByName: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                volumeByName[exercise.exercise.name, default: 0] += exercise.totalVolume
                setsByName[exercise.exercise.name, default: 0] += exercise.sets.count
            }
        }
        return volumeByName
            .map { ProfileViewModel.TopExercise(name: $0.key, volume: $0.value, setCount: setsByName[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.volume != rhs.volume { return lhs.volume > rhs.volume }
                return lhs.name < rhs.name
            }
            .prefix(5)
            .map { $0 }
    }

    /// Month-to-date snapshot derived purely from workout history. Safe to run
    /// on any user's workouts (yours or a friend's).
    static func comparisonStats(workouts: [Workout], now: Date = Date()) -> ComparisonStats {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthWorkouts = workouts.filter { $0.startTime >= monthStart }

        let prsThisMonth = monthWorkouts.reduce(0) { $0 + $1.totalPRs }
        let buckets = computeWeeklyBuckets(workouts: workouts, now: now)
        let avg = buckets.counts.isEmpty
            ? 0
            : Double(buckets.counts.reduce(0, +)) / Double(buckets.counts.count)

        return ComparisonStats(
            workoutsThisMonth: monthWorkouts.count,
            volumeThisMonth: monthWorkouts.reduce(0) { $0 + $1.totalVolume },
            prsThisMonth: prsThisMonth,
            currentStreak: WorkoutInsights.currentStreak(workouts: workouts, now: now),
            avgWorkoutsPerWeek: avg
        )
    }

    /// Builds a recent-PR list from PR sets in workout history. Used when the
    /// PR table can't be reached. `previousBest` is unknown so improvement is nil.
    static func derivePRs(workouts: [Workout]) -> [PersonalRecord] {
        var prs: [PersonalRecord] = []
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets where set.isPersonalRecord {
                    prs.append(PersonalRecord(
                        id: set.id,
                        userId: workout.userId,
                        exerciseId: exercise.exercise.id,
                        exerciseName: exercise.exercise.name,
                        weight: set.weight,
                        reps: set.reps,
                        date: set.completedAt,
                        previousBest: nil
                    ))
                }
            }
        }
        return prs
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Formatting

    static func formatVolume(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }
}
