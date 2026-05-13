import Foundation
import SwiftUI
import PhotosUI
import Supabase

/// Errors surfaced by PhotoService. Avatar upload failures keep the underlying
/// Supabase error in `underlying` so they can be logged without losing detail.
enum PhotoServiceError: LocalizedError {
    case avatarEncodingFailed
    case avatarBucketMissing(underlying: Error)
    case avatarUploadFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .avatarEncodingFailed:
            return "Couldn't encode the selected image."
        case .avatarBucketMissing:
            return "Profile photos aren't set up yet on the server. Please try again later."
        case .avatarUploadFailed(let underlying):
            return "Couldn't upload your photo: \(underlying.localizedDescription)"
        }
    }
}

@MainActor
final class PhotoService {
    static let shared = PhotoService()

    private let bucketName = "workout-photos"
    private let avatarBucketName = "avatars"
    private let maxPhotos = 4
    private let maxDimension: CGFloat = 1200
    private let compressionQuality: CGFloat = 0.7

    // Avatar tuning: 512px square is plenty for retina display, JPEG @ 0.75
    // typically lands well under 500KB.
    private let avatarDimension: CGFloat = 512
    private let avatarCompressionQuality: CGFloat = 0.75
    private let avatarTargetByteSize: Int = 500_000

    private init() {}

    // MARK: - Load from PhotosPicker

    func loadImages(from selections: [PhotosPickerItem]) async -> [UIImage] {
        await loadPaired(from: selections).map { $0.1 }
    }

    /// Paired loader that returns successfully-decoded items together with their
    /// source `PhotosPickerItem`. Callers that store the picker selection
    /// separately (e.g. a `PhotosPicker` binding) should use this so the two
    /// arrays stay in lockstep — `loadImages` silently drops failures, which
    /// caused per-index removals to target the wrong photo (#359 bug 7).
    func loadPaired(from selections: [PhotosPickerItem]) async -> [(PhotosPickerItem, UIImage)] {
        var pairs: [(PhotosPickerItem, UIImage)] = []
        for item in selections.prefix(maxPhotos) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                pairs.append((item, image))
            }
        }
        return pairs
    }

    // MARK: - Upload

    func uploadWorkoutPhotos(_ images: [UIImage], workoutId: String, userId: String) async throws -> [String] {
        var urls: [String] = []

        for (index, image) in images.prefix(maxPhotos).enumerated() {
            let resized = resize(image, maxDimension: maxDimension)
            guard let data = resized.jpegData(compressionQuality: compressionQuality) else { continue }

            let path = "\(userId)/\(workoutId)/\(index).jpg"

            try await supabase.storage
                .from(bucketName)
                .upload(path, data: data, options: .init(contentType: "image/jpeg", upsert: true))

            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: path)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    // MARK: - Avatar Upload (#368)

    /// Loads a single image from a `PhotosPickerItem`. Returns nil if decode fails.
    func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Uploads an avatar JPEG to the `avatars` bucket at
    /// `avatars/{userId}/{uuid}.jpg`. Resizes to ~512px square then encodes to
    /// JPEG, walking compression quality down if the result exceeds the target
    /// byte budget (~500KB). Returns the public URL of the uploaded file.
    ///
    /// Logs every step with the `[ProfileAvatar]` prefix so users can grab a
    /// console transcript when reporting issues.
    func uploadAvatar(_ image: UIImage, userId: String) async throws -> String {
        print("[ProfileAvatar] uploadAvatar starting — userId=\(userId), bucket=\(avatarBucketName)")

        // 1. Resize down to the avatar dimension (square-ish, aspect preserved).
        let resized = resize(image, maxDimension: avatarDimension)
        print("[ProfileAvatar] resized from \(image.size) -> \(resized.size)")

        // 2. Encode to JPEG, stepping quality down if needed to hit target size.
        guard var data = resized.jpegData(compressionQuality: avatarCompressionQuality) else {
            print("[ProfileAvatar] ERROR encoding JPEG @ q=\(avatarCompressionQuality)")
            throw PhotoServiceError.avatarEncodingFailed
        }
        var currentQuality = avatarCompressionQuality
        while data.count > avatarTargetByteSize && currentQuality > 0.3 {
            currentQuality -= 0.1
            if let smaller = resized.jpegData(compressionQuality: currentQuality) {
                data = smaller
            } else {
                break
            }
        }
        print("[ProfileAvatar] final JPEG size=\(data.count) bytes @ q=\(String(format: "%.2f", currentQuality))")

        // 3. Build a unique path. UUID per upload busts CDN caches automatically.
        let path = "\(userId)/\(UUID().uuidString).jpg"
        print("[ProfileAvatar] uploading to \(avatarBucketName)/\(path)")

        // 4. Upload. Translate bucket-not-found errors into a clearer case so
        // the UI can surface a server-config hint instead of a raw 404.
        do {
            try await supabase.storage
                .from(avatarBucketName)
                .upload(path, data: data, options: .init(contentType: "image/jpeg", upsert: true))
        } catch {
            let message = String(describing: error).lowercased()
            if message.contains("bucket not found") || message.contains("not_found") {
                print("[ProfileAvatar] ERROR bucket '\(avatarBucketName)' missing — run supabase/migrations/20260513_avatars_storage.sql")
                throw PhotoServiceError.avatarBucketMissing(underlying: error)
            }
            print("[ProfileAvatar] ERROR upload failed: \(error)")
            throw PhotoServiceError.avatarUploadFailed(underlying: error)
        }

        // 5. Resolve public URL (bucket is configured `public = true`).
        let publicURL = try supabase.storage
            .from(avatarBucketName)
            .getPublicURL(path: path)
        let urlString = publicURL.absoluteString
        print("[ProfileAvatar] uploadAvatar complete — url=\(urlString)")
        return urlString
    }

    // MARK: - Resize

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
