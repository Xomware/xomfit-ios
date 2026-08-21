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
    // See WorkoutExerciseRow — optional for pre-migration rows. `weightMode`
    // absent means the row predates the column, and everything logged then was
    // total, which is exactly what WeightMode's own default resolves to.
    var weightMode: String?
    var isDropSet: Bool?
    var videoURL: String?

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
        case weightMode = "weight_mode"
        case isDropSet = "is_drop_set"
        case videoURL = "video_url"
    }
}

// MARK: - Nested Fetch Response

private struct WorkoutTrackRow: Codable {
    let id: String
    let workoutId: String
    let title: String
    let artist: String?
    let album: String?
    let capturedAt: String
    let sourceApp: String

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case title
        case artist
        case album
        case capturedAt = "captured_at"
        case sourceApp = "source_app"
    }
}

private struct WorkoutWithRelations: Codable {
    let id: String
    let userId: String
    let name: String
    let startTime: String
    let endTime: String?
    let notes: String?
    let location: String?
    let rating: Int?
    let detailedRatings: WorkoutRatings?
    let createdAt: String?
    let workoutExercises: [ExerciseWithSets]
    let workoutTracks: [WorkoutTrackRow]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case location
        case rating
        case detailedRatings = "detailed_ratings"
        case createdAt = "created_at"
        case workoutExercises = "workout_exercises"
        case workoutTracks = "workout_tracks"
    }
}

private struct ExerciseWithSets: Codable {
    let id: String
    let workoutId: String
    let exerciseId: String
    let exerciseName: String
    let sortOrder: Int
    let workoutSets: [WorkoutSetRow]
    // Variant/config fields. Optional so rows written before the 20260811
    // migration — which had no such columns — still decode.
    var selectedGrip: String?
    var selectedAttachment: String?
    var selectedPosition: String?
    var selectedLaterality: String?
    var supersetGroupId: String?
    var restSeconds: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sortOrder = "sort_order"
        case workoutSets = "workout_sets"
        case selectedGrip = "selected_grip"
        case selectedAttachment = "selected_attachment"
        case selectedPosition = "selected_position"
        case selectedLaterality = "selected_laterality"
        case supersetGroupId = "superset_group_id"
        case restSeconds = "rest_seconds"
        case notes
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
    let location: String?
    let rating: Int?
    let detailed_ratings: WorkoutRatings?
}

private struct WorkoutExerciseInsertPayload: Encodable {
    let id: String
    let workout_id: String
    let exercise_id: String
    let exercise_name: String
    let sort_order: Int
    let selected_grip: String?
    let selected_attachment: String?
    let selected_position: String?
    let selected_laterality: String
    let superset_group_id: String?
    let rest_seconds: Int?
    let notes: String?
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
    let weight_mode: String
    let is_drop_set: Bool
    let video_url: String?
}

private struct WorkoutTrackInsertPayload: Encodable {
    let id: String
    let workout_id: String
    let title: String
    let artist: String?
    let album: String?
    let captured_at: String
    let source_app: String
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

    // MARK: - Update (#365)

    /// Updates a previously-saved workout. The base `workouts` row already upserts
    /// in `saveToSupabase`, but child rows (`workout_exercises`, `workout_sets`,
    /// `workout_tracks`) only upsert by id — so if the user removed an exercise
    /// or set during edit those orphan rows would survive. To keep the source of
    /// truth in sync we delete the child rows first and then re-run the standard
    /// save path, which re-inserts them from the edited `Workout`.
    ///
    /// Always writes to local cache. Returns `true` if Supabase succeeded,
    /// `false` if the write was queued via `SyncManager` for retry.
    @discardableResult
    func updateWorkout(_ workout: Workout) async -> Bool {
        // Cache first — instant.
        saveToCache(workout)

        // Wipe children so removed exercises/sets/tracks don't leak.
        // workout_sets cascade-deletes from workout_exercises in the schema.
        do {
            try await supabase
                .from("workout_exercises")
                .delete()
                .eq("workout_id", value: workout.id)
                .execute()

            try await supabase
                .from("workout_tracks")
                .delete()
                .eq("workout_id", value: workout.id)
                .execute()

            try await saveToSupabase(workout)
            return true
        } catch {
            print("[WorkoutService] Supabase update failed, queuing for retry: \(error.localizedDescription)")
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
        #if DEBUG
        // #410 + #353 bypass — surface a mock workout with tracks + featured
        // pick so FeedDetailView's expanded soundtrack list + deep-link buttons
        // can be screenshot-verified from a cold launch.
        if ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1" {
            if let mock = DebugFixtures.bypassWorkout(id: id) {
                return mock
            }
            // Fall back to the local cache for own-user mock workouts seeded
            // via `seedDebugFixtures` (#411 follow-up). Lets the agent
            // screenshot harness open `mock-workout-1` from a cold launch
            // without hitting Supabase.
            if let cached = loadAllFromCache().first(where: { $0.id == id }) {
                return cached
            }
            return nil
        }
        #endif

        do {
            let rows: [WorkoutWithRelations] = try await supabase
                .from("workouts")
                .select("*, workout_exercises(*, workout_sets(*)), workout_tracks(*)")
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

    /// True under the DEBUG auth-bypass launch, which runs without Supabase
    /// credentials. The `supabase` global validates config on first access and
    /// **fatal-errors** rather than throwing, so `do/catch` cannot rescue it —
    /// every caller that reached the network crashed the app on launch. Callers
    /// get the bypass-seeded cache instead. Compiles to `false` in Release.
    private var isAuthBypass: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1"
        #else
        false
        #endif
    }

    func fetchWorkouts(userId: String) async -> [Workout] {
        guard !isAuthBypass else {
            return deduplicateWorkouts(fetchWorkoutsFromCache(userId: userId))
        }
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
        // UUIDs are case-insensitive identifiers. Callers normalize to lowercase
        // (`uuidString.lowercased()`) while some writers (e.g. the DEBUG auth
        // bypass fixtures) cache the raw uppercase `uuidString`, so compare
        // case-insensitively to avoid spurious empty results.
        let needle = userId.lowercased()
        let all = loadAllFromCache()
        return all
            .filter { $0.userId.lowercased() == needle }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Friends Feed

    /// Fan out across the current user's accepted friends and merge their recent workouts.
    /// Sorted by `startTime` desc; capped at `limit` results.
    /// Failures from individual friend fetches are logged and skipped — never throws.
    func fetchFriendsRecentWorkouts(currentUserId: String, limit: Int = 30) async -> [Workout] {
        guard !currentUserId.isEmpty else { return [] }

        let friendIds: [String]
        do {
            let rows = try await FriendsService.shared.fetchFriends(userId: currentUserId)
            friendIds = rows.map { $0.requesterId == currentUserId ? $0.addresseeId : $0.requesterId }
        } catch {
            print("[WorkoutService] fetchFriendsRecentWorkouts: friend list failed: \(error.localizedDescription)")
            return []
        }

        guard !friendIds.isEmpty else { return [] }

        let merged: [Workout] = await withTaskGroup(of: [Workout].self) { group in
            for friendId in friendIds {
                group.addTask {
                    await WorkoutService.shared.fetchWorkouts(userId: friendId)
                }
            }
            var collected: [Workout] = []
            for await batch in group {
                collected.append(contentsOf: batch)
            }
            return collected
        }

        return merged
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Soundtrack edits (post-save) (#411 follow-up)

    /// Update the featured-track pick on a previously-saved workout. Writes the
    /// new value to the local cache immediately and pushes to Supabase
    /// best-effort. Patches the matching feed item so the card refreshes.
    ///
    /// Tolerant of missing columns — the `workouts.featured_track_id` /
    /// `workouts.share_full_soundtrack` Supabase columns may not exist yet, in
    /// which case the remote update is logged and swallowed so the local cache
    /// + feed item still reflect the edit (the source of truth on first
    /// hydration after the migration ships will be the local cache).
    @discardableResult
    func setFeaturedTrack(workoutId: String, trackId: String?) async -> Bool {
        // 1. Patch local cache so the next read of this workout sees the edit.
        var workouts = loadAllFromCache()
        guard let idx = workouts.firstIndex(where: { $0.id == workoutId }) else { return false }
        workouts[idx].featuredTrackId = trackId
        let updated = workouts[idx]
        let data = try? JSONEncoder().encode(workouts)
        UserDefaults.standard.set(data, forKey: storageKey)

        // 2. Push to Supabase — best effort, tolerant of missing columns.
        var remoteOK = true
        do {
            try await supabase
                .from("workouts")
                .update(["featured_track_id": trackId])
                .eq("id", value: workoutId)
                .execute()
        } catch {
            remoteOK = false
            print("[WorkoutService] setFeaturedTrack remote update failed (likely missing column — will retry once migration ships): \(error.localizedDescription)")
        }

        // 3. Patch the feed item activity payload so the card reflects the change.
        do {
            try await FeedService.shared.updateFeedItemForWorkout(workout: updated, userId: updated.userId)
        } catch {
            print("[WorkoutService] setFeaturedTrack feed patch failed: \(error.localizedDescription)")
        }

        return remoteOK
    }

    /// Update the share-full-soundtrack toggle on a previously-saved workout.
    /// Same tolerance pattern as `setFeaturedTrack` — local cache and feed
    /// item are always patched; the Supabase column update is best-effort.
    @discardableResult
    func setShareFullSoundtrack(workoutId: String, enabled: Bool) async -> Bool {
        var workouts = loadAllFromCache()
        guard let idx = workouts.firstIndex(where: { $0.id == workoutId }) else { return false }
        workouts[idx].shareFullSoundtrack = enabled
        let updated = workouts[idx]
        let data = try? JSONEncoder().encode(workouts)
        UserDefaults.standard.set(data, forKey: storageKey)

        var remoteOK = true
        do {
            try await supabase
                .from("workouts")
                .update(["share_full_soundtrack": enabled])
                .eq("id", value: workoutId)
                .execute()
        } catch {
            remoteOK = false
            print("[WorkoutService] setShareFullSoundtrack remote update failed (likely missing column): \(error.localizedDescription)")
        }

        do {
            try await FeedService.shared.updateFeedItemForWorkout(workout: updated, userId: updated.userId)
        } catch {
            print("[WorkoutService] setShareFullSoundtrack feed patch failed: \(error.localizedDescription)")
        }

        return remoteOK
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
            notes: workout.notes,
            location: workout.location,
            rating: workout.rating,
            detailed_ratings: workout.detailedRatings
        )

        try await supabase
            .from("workouts")
            .upsert(workoutPayload)
            .execute()

        // Exercises and sets are written as two batch upserts rather than one
        // request per row. The previous per-row loop issued 1 + exercises +
        // sets requests (31 for a 6-exercise, 24-set session) and had no
        // atomicity: a failure partway through left the already-written rows
        // committed while the caller queued the *whole* workout for retry, so
        // the server held a half-saved session until — and unless — that retry
        // ran. Batching collapses this to three requests and makes each table's
        // write all-or-nothing.
        let exercisePayloads = workout.exercises.enumerated().map { sortIndex, workoutExercise in
            WorkoutExerciseInsertPayload(
                id: workoutExercise.id,
                workout_id: workout.id,
                exercise_id: workoutExercise.exercise.id,
                exercise_name: workoutExercise.exercise.name,
                sort_order: sortIndex,
                selected_grip: workoutExercise.selectedGrip?.rawValue,
                selected_attachment: workoutExercise.selectedAttachment?.rawValue,
                selected_position: workoutExercise.selectedPosition?.rawValue,
                selected_laterality: workoutExercise.selectedLaterality.rawValue,
                superset_group_id: workoutExercise.supersetGroupId?.uuidString,
                rest_seconds: workoutExercise.restSeconds,
                notes: workoutExercise.notes
            )
        }

        if !exercisePayloads.isEmpty {
            try await supabase
                .from("workout_exercises")
                .upsert(exercisePayloads)
                .execute()
        }

        let setPayloads = workout.exercises.flatMap { workoutExercise in
            workoutExercise.sets.enumerated().map { setIndex, workoutSet in
                WorkoutSetInsertPayload(
                    id: workoutSet.id,
                    workout_exercise_id: workoutExercise.id,
                    set_number: setIndex,
                    weight: workoutSet.weight,
                    reps: workoutSet.reps,
                    rpe: workoutSet.rpe,
                    is_completed: true,
                    is_pr: workoutSet.isPersonalRecord,
                    completed_at: iso8601.string(from: workoutSet.completedAt),
                    weight_mode: workoutSet.weightMode.rawValue,
                    is_drop_set: workoutSet.isDropSet,
                    // Prefer the uploaded URL; a local-only file URL is
                    // meaningless on another device, so it is not persisted.
                    video_url: workoutSet.videoRemoteURL?.absoluteString
                )
            }
        }

        if !setPayloads.isEmpty {
            try await supabase
                .from("workout_sets")
                .upsert(setPayloads)
                .execute()
        }

        // Insert captured Now Playing tracks (#345).
        // Skipped when the list is empty (user denied access or no Apple Music playback).
        if !workout.tracks.isEmpty {
            let trackPayloads = workout.tracks.map { track in
                WorkoutTrackInsertPayload(
                    id: track.id.uuidString,
                    workout_id: workout.id,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    captured_at: iso8601.string(from: track.capturedAt),
                    source_app: track.sourceApp
                )
            }
            try await supabase
                .from("workout_tracks")
                .upsert(trackPayloads)
                .execute()
        }
    }

    private func fetchFromSupabase(userId: String) async throws -> [Workout] {
        let rows: [WorkoutWithRelations] = try await supabase
            .from("workouts")
            .select("*, workout_exercises(*, workout_sets(*)), workout_tracks(*)")
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
                let exercise = ExerciseDatabase.byId[exRow.exerciseId]
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
                            completedAt: setRow.completedAt.flatMap { iso8601.date(from: $0) } ?? Date(),
                            // Missing on rows written before the 20260811
                            // migration; `.total` matches how they were logged.
                            weightMode: setRow.weightMode.flatMap { WeightMode(rawValue: $0) } ?? .total,
                            isDropSet: setRow.isDropSet ?? false,
                            videoRemoteURL: setRow.videoURL.flatMap { URL(string: $0) }
                        )
                    }

                return WorkoutExercise(
                    id: exRow.id,
                    exercise: exercise,
                    sets: sets,
                    notes: exRow.notes,
                    selectedGrip: exRow.selectedGrip.flatMap { GripType(rawValue: $0) },
                    selectedAttachment: exRow.selectedAttachment.flatMap { CableAttachment(rawValue: $0) },
                    selectedPosition: exRow.selectedPosition.flatMap { ExercisePosition(rawValue: $0) },
                    selectedLaterality: exRow.selectedLaterality.flatMap { Laterality(rawValue: $0) } ?? .bilateral,
                    supersetGroupId: exRow.supersetGroupId.flatMap { UUID(uuidString: $0) },
                    restSeconds: exRow.restSeconds
                )
            }

        let tracks = row.workoutTracks.map { trackRow in
            WorkoutTrack(
                id: UUID(uuidString: trackRow.id) ?? UUID(),
                title: trackRow.title,
                artist: trackRow.artist,
                album: trackRow.album,
                capturedAt: iso8601.date(from: trackRow.capturedAt) ?? Date(),
                sourceApp: trackRow.sourceApp
            )
        }

        return Workout(
            id: row.id,
            userId: row.userId,
            name: row.name,
            exercises: exercises,
            startTime: iso8601.date(from: row.startTime) ?? Date(),
            endTime: row.endTime.flatMap { iso8601.date(from: $0) },
            notes: row.notes,
            location: row.location,
            rating: row.rating,
            tracks: tracks,
            detailedRatings: row.detailedRatings
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

    // MARK: - Debug Fixtures (#353)

    #if DEBUG
    /// Hydrates the local cache with `Workout.mockFixtures(userId:)` for the
    /// bypassed agent user. Only invoked when `XOMFIT_AUTH_BYPASS=1` from
    /// `AuthService` so future agents can screenshot history / detail views
    /// without real Supabase data. Safe to call repeatedly — overwrites this
    /// user's cached workouts.
    func seedDebugFixtures(userId: String) {
        let fixtures = Workout.mockFixtures(userId: userId)
        overwriteCache(fixtures, userId: userId)
    }
    #endif
}
