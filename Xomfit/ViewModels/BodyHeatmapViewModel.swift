import Foundation
import SwiftUI

// MARK: - Time Range

/// Filter for the full-body heatmap (#346).
///
/// Decoupled from the older `HeatmapTimeFilter` (Week/Month) because the new
/// silhouette heatmap also supports 3-month and all-time views.
enum HeatmapTimeRange: String, CaseIterable, Identifiable {
    case week        = "1W"
    case month       = "1M"
    case threeMonths = "3M"
    case allTime     = "All"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var accessibilityName: String {
        switch self {
        case .week:        return "Last week"
        case .month:       return "Last month"
        case .threeMonths: return "Last three months"
        case .allTime:     return "All time"
        }
    }

    /// Start date for the range. `nil` means "no lower bound" (.allTime).
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .allTime:
            return nil
        }
    }
}

// MARK: - ExerciseVolumeEntry

/// One exercise's contribution to a muscle group within the selected range.
/// Surfaced by `MuscleDetailSheet` so users can drill from "lats hit hardest"
/// → "deadlift was 80% of that".
struct ExerciseVolumeEntry: Identifiable, Hashable {
    let exercise: Exercise
    /// Total set count across the selected range.
    let setCount: Int
    /// Total volume (lbs · reps) attributed to this muscle from this exercise.
    /// Volume is split evenly across the exercise's primary muscle groups.
    let volume: Double
    /// Best-set weight × reps, displayed as a quick PR-ish summary.
    let bestSetWeight: Double
    let bestSetReps: Int

    var id: String { exercise.id }
}

// MARK: - BodyHeatmapViewModel

/// Derives per-muscle volume from a workout history for the full-body heatmap.
///
/// Volume distribution rule: an exercise's total volume is split *evenly across
/// its primary muscle groups*. Bench press (chest, triceps, shoulders) with
/// 9,000 lbs volume contributes 3,000 to each. This matches the simplifying
/// assumption called out in #346 — we don't have prime/synergist data in the
/// `Exercise` model, so equal split is the honest aggregation.
@Observable
@MainActor
final class BodyHeatmapViewModel {
    // MARK: - Inputs

    /// Workout history backing the heatmap. Re-assign to recompute.
    var workouts: [Workout] {
        didSet { recompute() }
    }

    /// Selected time range. Re-assign to recompute.
    var range: HeatmapTimeRange {
        didSet { recompute() }
    }

    // MARK: - Outputs

    /// Total volume per muscle group within the selected range.
    private(set) var volumeByMuscle: [MuscleGroup: Double] = [:]

    /// Exercises that contributed to each muscle, ranked by descending volume.
    /// Populated alongside `volumeByMuscle`.
    private(set) var exercisesByMuscle: [MuscleGroup: [ExerciseVolumeEntry]] = [:]

    /// Max value in `volumeByMuscle`. Cached so `intensity(for:)` is O(1).
    private(set) var maxVolume: Double = 0

    // MARK: - Init

    init(workouts: [Workout] = [], range: HeatmapTimeRange = .week) {
        self.workouts = workouts
        self.range = range
        recompute()
    }

    // MARK: - Public Helpers

    /// Returns 0.0–1.0 intensity for the given muscle relative to the busiest
    /// muscle in the current range. Returns 0 when the muscle has no recorded
    /// volume or the dataset is empty.
    func intensity(for muscle: MuscleGroup) -> Double {
        guard maxVolume > 0 else { return 0 }
        let volume = volumeByMuscle[muscle] ?? 0
        return max(0, min(1, volume / maxVolume))
    }

    /// Exercises that hit `muscle` in the selected range, ranked by volume.
    func exercises(for muscle: MuscleGroup) -> [ExerciseVolumeEntry] {
        exercisesByMuscle[muscle] ?? []
    }

    /// Total volume contributed to `muscle` in the selected range.
    func totalVolume(for muscle: MuscleGroup) -> Double {
        volumeByMuscle[muscle] ?? 0
    }

    // MARK: - Compute

    private func recompute() {
        let start = range.startDate()
        var byMuscle: [MuscleGroup: Double] = [:]
        // Per-muscle, per-exercise rollup so we can rebuild `ExerciseVolumeEntry`
        // without re-walking the workout list a second time.
        var perMuscleAgg: [MuscleGroup: [String: MuscleAggregate]] = [:]

        for workout in workouts {
            if let start, workout.startTime < start { continue }

            for workoutExercise in workout.exercises {
                let exercise = workoutExercise.exercise
                let muscles = exercise.muscleGroups
                guard !muscles.isEmpty else { continue }

                let totalVolume = workoutExercise.totalVolume
                let share = totalVolume / Double(muscles.count)
                guard share > 0 else { continue }

                // Best set across all sets of this exercise instance.
                let best = workoutExercise.sets.max(by: { $0.volume < $1.volume })
                let setCount = workoutExercise.sets.count

                for muscle in muscles {
                    byMuscle[muscle, default: 0] += share

                    var bucket = perMuscleAgg[muscle] ?? [:]
                    var entry = bucket[exercise.id] ?? MuscleAggregate(exercise: exercise)
                    entry.volume += share
                    entry.setCount += setCount
                    if let best, best.volume > entry.bestSetVolume {
                        entry.bestSetVolume = best.volume
                        entry.bestSetWeight = best.weight
                        entry.bestSetReps = best.reps
                    }
                    bucket[exercise.id] = entry
                    perMuscleAgg[muscle] = bucket
                }
            }
        }

        volumeByMuscle = byMuscle
        maxVolume = byMuscle.values.max() ?? 0

        // Flatten the aggregates into ranked entry lists.
        var ranked: [MuscleGroup: [ExerciseVolumeEntry]] = [:]
        for (muscle, bucket) in perMuscleAgg {
            ranked[muscle] = bucket.values
                .map {
                    ExerciseVolumeEntry(
                        exercise: $0.exercise,
                        setCount: $0.setCount,
                        volume: $0.volume,
                        bestSetWeight: $0.bestSetWeight,
                        bestSetReps: $0.bestSetReps
                    )
                }
                .sorted { $0.volume > $1.volume }
        }
        exercisesByMuscle = ranked
    }

    /// Internal rollup struct kept private — `ExerciseVolumeEntry` is the
    /// Identifiable façade we expose to views.
    private struct MuscleAggregate {
        let exercise: Exercise
        var volume: Double = 0
        var setCount: Int = 0
        var bestSetVolume: Double = 0
        var bestSetWeight: Double = 0
        var bestSetReps: Int = 0
    }
}

// MARK: - Color Helpers

extension BodyHeatmapViewModel {
    /// Convenience: build the `[MuscleGroup: Color]` map a silhouette consumes.
    /// Color is `Theme.accent` shaded by relative intensity, with a floor so even
    /// touched muscles read as "hit" rather than invisible.
    func fillMap(accent: Color = Theme.accent, floor: Double = 0.18) -> [MuscleGroup: Color] {
        var map: [MuscleGroup: Color] = [:]
        for muscle in MuscleGroup.allCases {
            let i = intensity(for: muscle)
            guard i > 0 else { continue }
            // Floor non-zero intensities to `floor` so a lightly-hit muscle still shows.
            let opacity = floor + (1 - floor) * i
            map[muscle] = accent.opacity(opacity)
        }
        return map
    }
}
