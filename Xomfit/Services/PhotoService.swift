import Foundation
import SwiftUI
import PhotosUI
import Supabase

@MainActor
final class PhotoService {
    static let shared = PhotoService()

    private let bucketName = "workout-photos"
    private let maxPhotos = 4
    private let maxDimension: CGFloat = 1200
    private let compressionQuality: CGFloat = 0.7

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
