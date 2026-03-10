import Foundation

/// Represents different types of activity that appear in the social feed
enum ActivityType: String, Codable, CaseIterable {
    case workout = "workout"
    case personalRecord = "personal_record"
    case milestone = "milestone"
    case streak = "streak"
}

/// A unified feed item that wraps different activity types
struct SocialFeedItem: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: ActivityType
    let createdAt: Date
    var user: AppUser
    var likes: Int
    var isLiked: Bool
    var comments: [FeedComment]

    // Activity-specific payloads (only one will be non-nil)
    var workoutActivity: WorkoutActivity?
    var prActivity: PRActivity?
    var milestoneActivity: MilestoneActivity?
    var streakActivity: StreakActivity?

    /// Caption or note the user attached when sharing
    var caption: String?

    /// Privacy level for the post
    var visibility: FeedVisibility

    enum FeedVisibility: String, Codable {
        case friends
        case followers
        case everyone
    }
}

// MARK: - Activity Payloads

struct WorkoutActivity: Codable {
    let workoutId: String
    let workoutName: String
    let duration: TimeInterval
    let totalVolume: Double
    let totalSets: Int
    let exerciseCount: Int
    let prCount: Int
    let exercises: [ExerciseSummary]

    struct ExerciseSummary: Codable, Identifiable {
        let id: String
        let name: String
        let bestWeight: Double
        let bestReps: Int
        let isPR: Bool
    }
}

struct PRActivity: Codable {
    let exerciseName: String
    let weight: Double
    let reps: Int
    let previousBest: Double?
    let improvement: Double?
}

struct MilestoneActivity: Codable {
    let title: String
    let subtitle: String
    let icon: String
    let badge: String
    let details: [String]
    let milestoneType: MilestoneType

    enum MilestoneType: String, Codable {
        case workoutCount
        case volumeTotal
        case prCount
        case streakRecord
        case custom
    }
}

struct StreakActivity: Codable {
    let currentStreak: Int
    let previousBest: Int
    let isNewRecord: Bool
}

// MARK: - Feed Comment (enhanced from FeedPost.Comment)

struct FeedComment: Codable, Identifiable {
    let id: String
    var userId: String
    var user: AppUser?
    var text: String
    var createdAt: Date
}

// MARK: - Mock Data

extension SocialFeedItem {
    static let mockWorkoutPost = SocialFeedItem(
        id: "sfi-1",
        userId: "user-2",
        activityType: .workout,
        createdAt: Date().addingTimeInterval(-3600),
        user: .mockFriend,
        likes: 12,
        isLiked: false,
        comments: [
            FeedComment(
                id: "fc-1",
                userId: "user-1",
                user: .mock,
                text: "Nice volume! 💪",
                createdAt: Date().addingTimeInterval(-1800)
            )
        ],
        workoutActivity: WorkoutActivity(
            workoutId: "w-2",
            workoutName: "Leg Day",
            duration: 3600,
            totalVolume: 24_500,
            totalSets: 16,
            exerciseCount: 5,
            prCount: 1,
            exercises: [
                .init(id: "es-1", name: "Squat", bestWeight: 315, bestReps: 5, isPR: true),
                .init(id: "es-2", name: "Leg Press", bestWeight: 450, bestReps: 10, isPR: false)
            ]
        ),
        caption: "Great leg session today!",
        visibility: .friends
    )

    static let mockPRPost = SocialFeedItem(
        id: "sfi-2",
        userId: "user-2",
        activityType: .personalRecord,
        createdAt: Date().addingTimeInterval(-7200),
        user: .mockFriend,
        likes: 24,
        isLiked: true,
        comments: [],
        prActivity: PRActivity(
            exerciseName: "Bench Press",
            weight: 275,
            reps: 1,
            previousBest: 265,
            improvement: 10
        ),
        caption: nil,
        visibility: .everyone
    )

    static let mockMilestonePost = SocialFeedItem(
        id: "sfi-3",
        userId: "user-2",
        activityType: .milestone,
        createdAt: Date().addingTimeInterval(-10800),
        user: .mockFriend,
        likes: 18,
        isLiked: false,
        comments: [],
        milestoneActivity: MilestoneActivity(
            title: "200 Workouts",
            subtitle: "Completed 200 total workouts",
            icon: "star.fill",
            badge: "🏆 Legend",
            details: ["Consistent training pays off", "Next target: 250"],
            milestoneType: .workoutCount
        ),
        caption: nil,
        visibility: .friends
    )

    static let mockStreakPost = SocialFeedItem(
        id: "sfi-4",
        userId: "user-2",
        activityType: .streak,
        createdAt: Date().addingTimeInterval(-14400),
        user: .mockFriend,
        likes: 8,
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

    static let mockFeed: [SocialFeedItem] = [
        mockWorkoutPost,
        mockPRPost,
        mockMilestonePost,
        mockStreakPost
    ]
}
