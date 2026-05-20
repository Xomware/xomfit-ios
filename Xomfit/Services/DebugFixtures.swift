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
                    trackCount: nil,
                    firstTrackTitle: nil
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
