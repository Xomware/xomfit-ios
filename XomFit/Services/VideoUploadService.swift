import Foundation
import AVFoundation
import Combine

// MARK: - Upload Progress

enum UploadState: Equatable {
    case idle
    case uploading(progress: Double)
    case success(remoteURL: URL)
    case failed(String)
}

// MARK: - VideoUploadService

/// Uploads recorded form-check clips to Supabase Storage.
@MainActor
final class VideoUploadService: ObservableObject {

    static let shared = VideoUploadService()

    @Published var uploadState: UploadState = .idle

    // Supabase Storage bucket name
    private let bucket = "form-check-videos"
    private let supabaseURL: String = {
        // Pull from Config if available; otherwise read env
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String { return url }
        return ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    }()
    private let supabaseAnonKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String { return key }
        return ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    }()

    private init() {}

    // MARK: - Upload

    /// Upload a local video file to Supabase Storage.
    /// - Parameters:
    ///   - localURL:   The local .mov or .mp4 file.
    ///   - userId:     Current user's ID (used for path isolation).
    ///   - setId:      The workout set this clip is attached to.
    /// - Returns: The public remote URL for the stored video.
    func upload(localURL: URL, userId: String, setId: String) async throws -> URL {
        uploadState = .uploading(progress: 0)

        // Transcode to mp4 for broad compatibility
        let mp4URL = try await transcodeToMP4(localURL)
        defer { try? FileManager.default.removeItem(at: mp4URL) }

        let remotePath = "\(userId)/\(setId)/\(UUID().uuidString).mp4"
        let storageEndpoint = "\(supabaseURL)/storage/v1/object/\(bucket)/\(remotePath)"

        guard let uploadURL = URL(string: storageEndpoint) else {
            throw UploadError.invalidURL
        }

        let data = try Data(contentsOf: mp4URL)
        uploadState = .uploading(progress: 0.3)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("public-read", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        uploadState = .uploading(progress: 0.6)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UploadError.httpError(code)
        }

        uploadState = .uploading(progress: 1.0)

        // Construct public URL
        let publicURLString = "\(supabaseURL)/storage/v1/object/public/\(bucket)/\(remotePath)"
        guard let publicURL = URL(string: publicURLString) else {
            throw UploadError.invalidURL
        }

        uploadState = .success(remoteURL: publicURL)
        return publicURL
    }

    // MARK: - Transcode

    private func transcodeToMP4(_ inputURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload_\(UUID().uuidString).mp4")

        let asset = AVURLAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset,
                                                       presetName: AVAssetExportPresetMediumQuality) else {
            throw UploadError.transcodeFailure("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        if let error = exportSession.error {
            throw UploadError.transcodeFailure(error.localizedDescription)
        }

        return outputURL
    }

    // MARK: - Reset

    func reset() {
        uploadState = .idle
    }
}

// MARK: - FormCheckVideo Supabase Record

extension VideoUploadService {

    /// Persist a FormCheckVideo record in Supabase database.
    func saveRecord(_ video: FormCheckVideo) async throws {
        let endpoint = "\(supabaseURL)/rest/v1/form_check_videos"
        guard let url = URL(string: endpoint) else { return }

        let payload: [String: Any] = [
            "id": video.id,
            "set_id": video.setId,
            "exercise_id": video.exerciseId,
            "exercise_name": video.exerciseName,
            "user_id": video.userId,
            "video_remote_url": video.videoRemoteURL?.absoluteString ?? NSNull(),
            "duration_seconds": video.durationSeconds,
            "weight": video.weight,
            "reps": video.reps,
            "visibility": video.visibility.rawValue,
            "is_public": video.isPublic,
            "likes": 0,
            "created_at": ISO8601DateFormatter().string(from: video.createdAt)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UploadError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    /// Fetch friend's public/friends-visibility form check videos.
    func fetchFriendVideos() async throws -> [FormCheckVideo] {
        // In production this calls Supabase with a join on friendships.
        // For now return mock data so the UI builds and previews work.
        return FormCheckVideo.mockFeed
    }

    /// Fetch current user's own form check videos.
    func fetchMyVideos(userId: String) async throws -> [FormCheckVideo] {
        return [FormCheckVideo.mock]
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case transcodeFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid upload URL."
        case .httpError(let code): return "Upload failed with HTTP \(code)."
        case .transcodeFailure(let msg): return "Transcode failed: \(msg)"
        }
    }
}
