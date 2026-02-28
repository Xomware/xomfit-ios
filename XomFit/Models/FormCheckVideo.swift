import Foundation

// MARK: - FormCheckVideo Model

struct FormCheckVideo: Codable, Identifiable {
    let id: String
    var setId: String
    var exerciseId: String
    var exerciseName: String
    var userId: String
    var user: User?
    var videoLocalURL: URL?
    var videoRemoteURL: URL?
    var thumbnailURL: URL?
    var durationSeconds: Double
    var weight: Double
    var reps: Int
    var isPublic: Bool          // private by default, can share to friends
    var visibility: VideoVisibility
    var likes: Int
    var isLiked: Bool
    var comments: [VideoComment]
    var createdAt: Date

    enum VideoVisibility: String, Codable {
        case `private` = "private"
        case friends = "friends"
        case `public` = "public"
    }

    struct VideoComment: Codable, Identifiable {
        let id: String
        var user: User
        var text: String
        var createdAt: Date
    }

    var displaySet: String {
        "\(weight.formattedWeight) × \(reps) reps"
    }
}

// MARK: - WorkoutSet extension: form check convenience

extension WorkoutSet {
    /// True when this set has an attached form-check clip (local or remote).
    var hasFormCheckVideo: Bool {
        videoLocalURL != nil || videoRemoteURL != nil
    }
}

// MARK: - Mock Data

extension FormCheckVideo {
    static let mock = FormCheckVideo(
        id: "fcv-1",
        setId: "set-1",
        exerciseId: "ex-1",
        exerciseName: "Back Squat",
        userId: "user-1",
        user: .mock,
        videoLocalURL: nil,
        videoRemoteURL: URL(string: "https://example.com/videos/fcv-1.mp4"),
        thumbnailURL: nil,
        durationSeconds: 8.5,
        weight: 225,
        reps: 5,
        isPublic: false,
        visibility: .friends,
        likes: 7,
        isLiked: false,
        comments: [
            VideoComment(id: "vc-1", user: .mockFriend, text: "Great depth! Keep that chest up 💪", createdAt: Date().addingTimeInterval(-1800))
        ],
        createdAt: Date().addingTimeInterval(-3600)
    )

    static let mockFeed: [FormCheckVideo] = [
        mock,
        FormCheckVideo(
            id: "fcv-2",
            setId: "set-4",
            exerciseId: "ex-2",
            exerciseName: "Bench Press",
            userId: "user-2",
            user: .mockFriend,
            videoLocalURL: nil,
            videoRemoteURL: URL(string: "https://example.com/videos/fcv-2.mp4"),
            thumbnailURL: nil,
            durationSeconds: 12.0,
            weight: 185,
            reps: 3,
            isPublic: false,
            visibility: .friends,
            likes: 4,
            isLiked: true,
            comments: [],
            createdAt: Date().addingTimeInterval(-7200)
        )
    ]
}
