#if DEBUG
import Foundation

/// In-process mock data used by the `XOMFIT_AUTH_BYPASS=1` flow so agents can
/// screenshot end-to-end UI without real Supabase data. Compiled out of
/// Release builds.
///
/// Anything that needs to look like "real" backend data for bypass screenshots
/// should land here so callers in `ProfileService` / `FeedService` / etc. stay
/// tiny — they just early-return a fixture when the env var is set.
enum DebugFixtures {
    /// Returns the mocked `ProfileRow` for a known bypass user id, or nil if we
    /// don't have a fixture (caller falls back to the real network path).
    /// Both the signed-in bypass user (#353) and the mock friend (#403) are
    /// covered so pushed-profile flows render.
    static func profileRow(for userId: String) -> ProfileRow? {
        let normalized = userId.lowercased()
        switch normalized {
        case AppUser.mockDebug.id.lowercased():
            return profileRow(from: AppUser.mockDebug)
        case AppUser.mockDebugFriend.id.lowercased():
            return profileRow(from: AppUser.mockDebugFriend)
        default:
            return nil
        }
    }

    /// Bypass feed used by `FeedService.fetchFeed` + `fetchUserFeed`. A small
    /// mix of activity types so the feed isn't a single card, and one of the
    /// items belongs to a user with an anthem so the anthem row + play button
    /// is visible from the cold-launch screenshot.
    static func bypassFeed() -> [SocialFeedItem] {
        let now = Date()
        return [
            SocialFeedItem(
                id: "bypass-sfi-1",
                userId: AppUser.mockDebugFriend.id,
                activityType: .workout,
                createdAt: now.addingTimeInterval(-1800),
                user: AppUser.mockDebugFriend,
                likes: 7,
                isLiked: false,
                comments: [],
                workoutActivity: WorkoutActivity(
                    workoutId: "bypass-w-1",
                    workoutName: "Push Day",
                    duration: 3300,
                    totalVolume: 18_750,
                    totalSets: 14,
                    exerciseCount: 4,
                    prCount: 1,
                    exercises: [
                        .init(id: "bex-1", name: "Bench Press", bestWeight: 225, bestReps: 5, isPR: true, setCount: 4, sets: nil),
                        .init(id: "bex-2", name: "Overhead Press", bestWeight: 135, bestReps: 8, isPR: false, setCount: 3, sets: nil)
                    ],
                    location: "Home Gym",
                    rating: 4,
                    photoURLs: nil,
                    trackCount: 3,
                    firstTrackTitle: "Power",
                    // #410 — seed a featured track + URL so the feed card +
                    // expanded detail render the anthem-style row and the
                    // deep-link buttons under bypass.
                    featuredTrackTitle: "Power",
                    featuredTrackArtist: "Kanye West",
                    featuredTrackSource: "Spotify",
                    featuredTrackURL: "https://open.spotify.com/track/2gZUPNdnz5Y45eiGxpHGSc"
                ),
                caption: "Felt strong on bench today.",
                visibility: .friends
            ),
            SocialFeedItem(
                id: "bypass-sfi-2",
                userId: AppUser.mockDebug.id,
                activityType: .personalRecord,
                createdAt: now.addingTimeInterval(-7200),
                user: AppUser.mockDebug,
                likes: 12,
                isLiked: true,
                comments: [],
                prActivity: PRActivity(
                    exerciseName: "Deadlift",
                    weight: 405,
                    reps: 1,
                    previousBest: 385,
                    improvement: 20
                ),
                caption: nil,
                visibility: .everyone
            ),
            SocialFeedItem(
                id: "bypass-sfi-3",
                userId: AppUser.mockDebugFriend.id,
                activityType: .streak,
                createdAt: now.addingTimeInterval(-86400),
                user: AppUser.mockDebugFriend,
                likes: 3,
                isLiked: false,
                comments: [],
                streakActivity: StreakActivity(
                    currentStreak: 14,
                    previousBest: 10,
                    isNewRecord: true
                ),
                caption: nil,
                visibility: .friends
            )
        ]
    }

    /// Mock workout used by `WorkoutService.fetchWorkout` under bypass (#410).
    /// Includes a captured soundtrack with one featured track + per-track URLs
    /// so the expanded feed view can render deep-link buttons end-to-end.
    static func bypassWorkout(id: String) -> Workout? {
        guard id == "bypass-w-1" else { return nil }
        let now = Date()
        let track1ID = UUID()
        let track2ID = UUID()
        let track3ID = UUID()
        let tracks: [WorkoutTrack] = [
            WorkoutTrack(
                id: track1ID,
                title: "Power",
                artist: "Kanye West",
                album: "My Beautiful Dark Twisted Fantasy",
                capturedAt: now.addingTimeInterval(-3300),
                sourceApp: "Spotify",
                url: "https://open.spotify.com/track/2gZUPNdnz5Y45eiGxpHGSc"
            ),
            WorkoutTrack(
                id: track2ID,
                title: "Till I Collapse",
                artist: "Eminem",
                album: "The Eminem Show",
                capturedAt: now.addingTimeInterval(-2700),
                sourceApp: "Apple Music",
                url: nil
            ),
            WorkoutTrack(
                id: track3ID,
                title: "Stronger",
                artist: "Kanye West",
                album: "Graduation",
                capturedAt: now.addingTimeInterval(-1800),
                sourceApp: "Apple Music",
                url: nil
            )
        ]

        return Workout(
            id: id,
            userId: AppUser.mockDebugFriend.id,
            name: "Push Day",
            exercises: [
                WorkoutExercise(
                    id: "bypass-we-1",
                    exercise: .benchPress,
                    sets: [
                        WorkoutSet(id: "bypass-s-1", exerciseId: "ex-1", weight: 185, reps: 8, rpe: 7, isPersonalRecord: false, completedAt: now),
                        WorkoutSet(id: "bypass-s-2", exerciseId: "ex-1", weight: 205, reps: 6, rpe: 8, isPersonalRecord: false, completedAt: now),
                        WorkoutSet(id: "bypass-s-3", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 9, isPersonalRecord: true, completedAt: now)
                    ],
                    notes: nil
                )
            ],
            startTime: now.addingTimeInterval(-3300),
            endTime: now.addingTimeInterval(-300),
            notes: "Felt strong on bench today.",
            location: "Home Gym",
            rating: 4,
            tracks: tracks,
            featuredTrackId: track1ID.uuidString,
            shareFullSoundtrack: true
        )
    }

    // MARK: - Private

    /// Inverse of `FeedService.buildAppUser` — copies the fields we care about
    /// off an `AppUser` mock into a `ProfileRow`.
    private static func profileRow(from user: AppUser) -> ProfileRow {
        ProfileRow(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            bio: user.bio,
            avatarURL: user.avatarURL,
            isPrivate: user.isPrivate,
            trainingGoals: nil,
            anthem: user.anthem
        )
    }
}
#endif
